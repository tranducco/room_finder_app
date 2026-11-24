"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.checkExpiredPromotions = exports.checkPaymentStatus = exports.momoIpnWebhook = exports.createMoMoPayment = exports.onReportCreatedAutoModerate = void 0;
const firestore_1 = require("firebase-functions/v2/firestore");
const https_1 = require("firebase-functions/v2/https");
const scheduler_1 = require("firebase-functions/v2/scheduler");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const crypto = require("crypto");
const momo_config_1 = require("./momo_config");
const momo_crypto_1 = require("./momo_crypto");
// Khởi tạo Firebase Admin SDK
if (!admin.apps.length) {
    admin.initializeApp();
}
const db = admin.firestore();
// ============================================================================
// 1. MODULE TỰ ĐỘNG KIỂM DUYỆT BÁO CÁO (AUTO-MODERATION PIPELINE) - GIỮ NGUYÊN
// ============================================================================
const AUTO_MODERATION_REPORT_THRESHOLD = 5;
exports.onReportCreatedAutoModerate = (0, firestore_1.onDocumentCreated)({
    document: "reports/{reportId}",
    region: "asia-southeast1",
    memory: "256MiB",
    timeoutSeconds: 60,
}, async (event) => {
    const snap = event.data;
    if (!snap)
        return;
    const reportData = snap.data();
    const roomId = reportData?.roomId;
    const roomTitle = reportData?.roomTitle || "Phòng trọ";
    if (!roomId || typeof roomId !== "string" || roomId.trim().length === 0) {
        return;
    }
    try {
        const roomRef = db.collection("rooms").doc(roomId);
        const roomSnap = await roomRef.get();
        if (!roomSnap.exists)
            return;
        const roomData = roomSnap.data();
        if (roomData?.status === "hidden")
            return;
        const reportsCountSnap = await db
            .collection("reports")
            .where("roomId", "==", roomId)
            .count()
            .get();
        const totalReports = reportsCountSnap.data().count;
        if (totalReports >= AUTO_MODERATION_REPORT_THRESHOLD) {
            const batch = db.batch();
            batch.update(roomRef, {
                status: "hidden",
                autoModerated: true,
                autoModeratedAt: admin.firestore.FieldValue.serverTimestamp(),
                autoModeratedReason: `Tự động ẩn do vượt quá ${totalReports} lượt báo cáo vi phạm`,
            });
            const adminNotificationRef = db.collection("notifications").doc();
            batch.set(adminNotificationRef, {
                recipientId: "admin",
                type: "system_alert",
                title: "🚨 Cảnh báo khẩn: Tin đăng bị báo cáo nhiều lần",
                body: `Phòng "${roomData?.title || roomTitle}" (Mã: ${roomId}) đã bị ẩn tự động do nhận ${totalReports} lượt báo cáo vi phạm.`,
                roomId: roomId,
                totalReports: totalReports,
                isRead: false,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            if (roomData?.ownerId) {
                const ownerNotificationRef = db.collection("notifications").doc();
                batch.set(ownerNotificationRef, {
                    recipientId: roomData.ownerId,
                    type: "room_rejected",
                    title: "Tin đăng tạm thời bị ẩn để kiểm duyệt ⚠️",
                    body: `Tin đăng "${roomData?.title || roomTitle}" của bạn nhận được nhiều phản ánh vi phạm và đã được tạm ẩn để Quản trị viên kiểm duyệt lại.`,
                    roomId: roomId,
                    isRead: false,
                    createdAt: admin.firestore.FieldValue.serverTimestamp(),
                });
            }
            await batch.commit();
        }
    }
    catch (error) {
        logger.error("Lỗi onReportCreatedAutoModerate:", error);
    }
});
// ============================================================================
// 2. TẠO ĐƠN HÀNG VÀ YÊU CẦU THANH TOÁN MOMO PHÍA SERVER (createMoMoPayment)
// ============================================================================
exports.createMoMoPayment = (0, https_1.onRequest)({
    region: "asia-southeast1",
    cors: true,
    memory: "256MiB",
    timeoutSeconds: 60,
}, async (req, res) => {
    if (req.method !== "POST") {
        res.status(405).json({ success: false, message: "Method Not Allowed" });
        return;
    }
    try {
        // 1. Xác thực ID Token của người dùng từ Authorization Header
        const authHeader = req.headers.authorization;
        if (!authHeader || !authHeader.startsWith("Bearer ")) {
            res.status(401).json({ success: false, message: "Yêu cầu đăng nhập (Missing Bearer Token)" });
            return;
        }
        const idToken = authHeader.split("Bearer ")[1];
        const decodedToken = await admin.auth().verifyIdToken(idToken);
        const userId = decodedToken.uid;
        const userEmail = decodedToken.email || "";
        // 2. Validate input parameters
        const { roomId, packageId, returnUrl } = req.body || {};
        if (!roomId || !packageId) {
            res.status(400).json({ success: false, message: "Thiếu tham số roomId hoặc packageId" });
            return;
        }
        const packageDef = momo_config_1.PACKAGE_DEFINITIONS[packageId];
        if (!packageDef) {
            res.status(400).json({ success: false, message: "Gói đăng tin không hợp lệ. Chỉ chấp nhận bronze, silver, gold" });
            return;
        }
        // 3. Kiểm tra quyền sở hữu phòng trọ (Chỉ chủ phòng mới được mua gói)
        const roomRef = db.collection("rooms").doc(roomId);
        const roomSnap = await roomRef.get();
        if (!roomSnap.exists) {
            res.status(404).json({ success: false, message: "Phòng trọ không tồn tại trong hệ thống" });
            return;
        }
        const roomData = roomSnap.data();
        if (roomData?.ownerId !== userId) {
            res.status(403).json({ success: false, message: "Bạn chỉ có thể mua gói đẩy tin cho phòng trọ của chính mình" });
            return;
        }
        if (roomData?.status === "rejected") {
            res.status(400).json({ success: false, message: "Tin đăng đang bị từ chối, không thể mua gói VIP" });
            return;
        }
        const roomTitle = roomData?.title || "Phòng trọ TroTot";
        const config = (0, momo_config_1.getMoMoConfig)();
        // 4. Sinh mã đơn hàng và requestId duy nhất
        const now = Date.now();
        const randomSuffix = crypto.randomBytes(3).toString("hex");
        const orderId = `TROTOT_${now}_${randomSuffix}`;
        const requestId = `REQ_${now}_${randomSuffix}`;
        const amount = packageDef.price;
        const orderInfo = `Thanh toan ${packageDef.name} - ${roomTitle.substring(0, 40)}`;
        // Encode extraData dạng base64 chứa metadata để MoMo IPN gửi lại
        const extraDataObj = { roomId, userId, packageId, amount };
        const extraData = Buffer.from(JSON.stringify(extraDataObj)).toString("base64");
        const ipnUrl = config.ipnUrl;
        const redirectUrl = returnUrl || config.redirectUrl;
        const requestType = "captureWallet";
        // 5. Tạo chữ ký HMAC-SHA256 chuẩn MoMo
        const rawSignature = `accessKey=${config.accessKey}` +
            `&amount=${amount}` +
            `&extraData=${extraData}` +
            `&ipnUrl=${ipnUrl}` +
            `&orderId=${orderId}` +
            `&orderInfo=${orderInfo}` +
            `&partnerCode=${config.partnerCode}` +
            `&redirectUrl=${redirectUrl}` +
            `&requestId=${requestId}` +
            `&requestType=${requestType}`;
        const signature = (0, momo_crypto_1.createMoMoSignature)(rawSignature, config.secretKey);
        // 6. Lưu trước đơn hàng vào Firestore ở trạng thái 'pending'
        const orderData = {
            orderId: orderId,
            userId: userId,
            userEmail: userEmail,
            roomId: roomId,
            roomTitle: roomTitle,
            packageId: packageDef.id,
            packageName: packageDef.name,
            amount: amount,
            durationDays: packageDef.durationDays,
            priority: packageDef.priority,
            status: "pending",
            paymentMethod: "momo",
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        };
        await db.collection("package_orders").doc(orderId).set(orderData);
        // 7. Gọi MoMo Payment API v2 để tạo giao dịch
        const momoRequestBody = {
            partnerCode: config.partnerCode,
            partnerName: "TroTot",
            storeId: "TroTotHanoi",
            requestId: requestId,
            amount: amount,
            orderId: orderId,
            orderInfo: orderInfo,
            redirectUrl: redirectUrl,
            ipnUrl: ipnUrl,
            lang: "vi",
            extraData: extraData,
            requestType: requestType,
            signature: signature,
        };
        logger.info(`Gửi yêu cầu thanh toán MoMo cho đơn hàng ${orderId}:`, { amount, packageId });
        const momoResponse = await fetch(config.endpoint, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify(momoRequestBody),
        });
        const momoResJson = (await momoResponse.json());
        logger.info(`Phản hồi từ MoMo API (${orderId}):`, {
            resultCode: momoResJson?.resultCode,
            message: momoResJson?.message,
        });
        if (momoResJson?.resultCode === 0 && momoResJson?.payUrl) {
            // Cập nhật URL thanh toán vào đơn hàng
            await db.collection("package_orders").doc(orderId).update({
                payUrl: momoResJson.payUrl,
                qrCodeUrl: momoResJson.qrCodeUrl || "",
                deeplink: momoResJson.deeplink || "",
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            res.status(200).json({
                success: true,
                orderId: orderId,
                payUrl: momoResJson.payUrl,
                qrCodeUrl: momoResJson.qrCodeUrl || "",
                deeplink: momoResJson.deeplink || "",
                amount: amount,
                packageName: packageDef.name,
                durationDays: packageDef.durationDays,
            });
        }
        else {
            // MoMo từ chối tạo giao dịch
            await db.collection("package_orders").doc(orderId).update({
                status: "failed",
                note: momoResJson?.message || "MoMo API error",
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            res.status(400).json({
                success: false,
                message: momoResJson?.message || "Không thể tạo liên kết thanh toán MoMo",
                resultCode: momoResJson?.resultCode,
            });
        }
    }
    catch (error) {
        logger.error("Lỗi xử lý createMoMoPayment:", error);
        res.status(500).json({ success: false, message: error?.message || "Lỗi máy chủ nội bộ" });
    }
});
// ============================================================================
// 3. TIẾP NHẬN VÀ XÁC MINH WEBHOOK IPN TỪ MOMO (momoIpnWebhook)
// ============================================================================
exports.momoIpnWebhook = (0, https_1.onRequest)({
    region: "asia-southeast1",
    cors: false, // IPN từ MoMo server-to-server
    memory: "256MiB",
    timeoutSeconds: 60,
}, async (req, res) => {
    if (req.method !== "POST") {
        res.status(405).send("Method Not Allowed");
        return;
    }
    try {
        const body = req.body || {};
        const { partnerCode, orderId, requestId, amount, orderInfo, orderType, transId, resultCode, message, payType, responseTime, extraData, signature, } = body;
        logger.info(`Nhận IPN Webhook từ MoMo cho đơn hàng ${orderId}:`, {
            transId,
            resultCode,
            amount,
            message,
        });
        const config = (0, momo_config_1.getMoMoConfig)();
        // 1. Xác thực chữ ký HMAC-SHA256 của MoMo
        const rawSignature = `accessKey=${config.accessKey}` +
            `&amount=${amount}` +
            `&extraData=${extraData || ""}` +
            `&message=${message}` +
            `&orderId=${orderId}` +
            `&orderInfo=${orderInfo}` +
            `&orderType=${orderType || "momo_wallet"}` +
            `&partnerCode=${partnerCode}` +
            `&payType=${payType || ""}` +
            `&requestId=${requestId}` +
            `&responseTime=${responseTime}` +
            `&resultCode=${resultCode}` +
            `&transId=${transId}`;
        const isValidSignature = (0, momo_crypto_1.verifyMoMoSignature)(rawSignature, signature, config.secretKey);
        if (!isValidSignature) {
            logger.warn(`Chữ ký IPN không hợp lệ cho đơn hàng ${orderId}!`, { receivedSignature: signature });
            res.status(400).json({ resultCode: 99, message: "Invalid Signature" });
            return;
        }
        // 2. Tra cứu đơn hàng trong Firestore
        const orderRef = db.collection("package_orders").doc(orderId);
        const orderSnap = await orderRef.get();
        if (!orderSnap.exists) {
            logger.warn(`Đơn hàng ${orderId} không tồn tại trong hệ thống.`);
            res.status(404).json({ resultCode: 1, message: "Order Not Found" });
            return;
        }
        const orderData = orderSnap.data();
        // 3. Chống xử lý trùng lặp (Idempotency)
        if (orderData.status === "completed") {
            logger.info(`Đơn hàng ${orderId} đã được xử lý thành công trước đó (Idempotent).`);
            res.status(204).send(); // HTTP 204 No Content thông báo MoMo dừng gửi lại
            return;
        }
        // 4. Đối chiếu số tiền thanh toán
        if (Number(orderData.amount) !== Number(amount)) {
            logger.error(`Số tiền không khớp cho đơn hàng ${orderId}: DB=${orderData.amount}, IPN=${amount}`);
            await orderRef.update({
                status: "failed",
                note: `Số tiền IPN (${amount}) không khớp với đơn hàng (${orderData.amount})`,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            res.status(400).json({ resultCode: 2, message: "Amount mismatch" });
            return;
        }
        // 5. Lưu lại chi tiết giao dịch vào payment_transactions
        const transDocId = transId ? `MOMO_${transId}` : `MOMO_${orderId}`;
        await db.collection("payment_transactions").doc(transDocId).set({
            orderId: orderId,
            userId: orderData.userId,
            roomId: orderData.roomId,
            amount: Number(amount),
            gateway: "momo",
            transId: String(transId || ""),
            resultCode: Number(resultCode),
            message: message,
            payType: payType || "momo_wallet",
            rawResponse: body,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        // 6. Xử lý kết quả giao dịch
        if (Number(resultCode) === 0) {
            // ─── THANH TOÁN THÀNH CÔNG: TỰ ĐỘNG KÍCH HOẠT GÓI ───
            await activatePromotionForOrder(orderData, String(transId || ""));
            logger.info(`Kích hoạt thành công gói ${orderData.packageId} cho phòng ${orderData.roomId}!`);
        }
        else {
            // ─── THANH TOÁN THẤT BẠI HOẶC BỊ HỦY ───
            await orderRef.update({
                status: "failed",
                transactionId: String(transId || ""),
                note: `MoMo resultCode ${resultCode}: ${message}`,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
        }
        // 7. Trả kết quả chuẩn xác cho MoMo
        res.status(200).json({ resultCode: 0, message: "Success" });
    }
    catch (error) {
        logger.error("Lỗi ngoại lệ trong momoIpnWebhook:", error);
        res.status(500).json({ resultCode: 99, message: error?.message || "Internal Server Error" });
    }
});
// ============================================================================
// 4. HÀM NỘI BỘ: KÍCH HOẠT GÓI ĐĂNG TIN VÀ TÍNH TOÁN THỜI HẠN CHÍNH XÁC
// ============================================================================
async function activatePromotionForOrder(orderData, transId) {
    const roomId = orderData.roomId;
    const packageId = orderData.packageId;
    const packageDef = momo_config_1.PACKAGE_DEFINITIONS[packageId] || momo_config_1.PACKAGE_DEFINITIONS.bronze;
    const durationDays = packageDef.durationDays;
    const priority = packageDef.priority;
    const roomRef = db.collection("rooms").doc(roomId);
    const roomSnap = await roomRef.get();
    if (!roomSnap.exists)
        return;
    const roomData = roomSnap.data();
    const now = new Date();
    let startAt = now;
    let expiresAt = new Date(now.getTime() + durationDays * 24 * 60 * 60 * 1000);
    // Xử lý chính sách gia hạn / nâng cấp nếu phòng đang có gói còn thời hạn
    const currentExpiresAt = roomData.packageExpiresAt?.toDate?.() || null;
    const currentPriority = (roomData.priority || 0);
    if (currentExpiresAt && currentExpiresAt > now && currentPriority > 0) {
        if (currentPriority === priority) {
            // Cùng hạng gói: Cộng dồn thời hạn tiếp theo
            startAt = now;
            expiresAt = new Date(currentExpiresAt.getTime() + durationDays * 24 * 60 * 60 * 1000);
            logger.info(`Gia hạn gói cùng hạng ${packageId}: Hạn mới = ${expiresAt.toISOString()}`);
        }
        else if (priority > currentPriority) {
            // Nâng cấp lên gói cao hơn (VD: Đồng -> Vàng): Ưu tiên hạng mới ngay lập tức
            // Hạn mới = Bây giờ + thời hạn gói mới + số ngày dư của gói cũ
            const remainingMs = currentExpiresAt.getTime() - now.getTime();
            expiresAt = new Date(now.getTime() + durationDays * 24 * 60 * 60 * 1000 + remainingMs);
            logger.info(`Nâng cấp gói lên hạng cao hơn ${packageId}: Hạn mới = ${expiresAt.toISOString()}`);
        }
        else {
            // Gói mới có priority thấp hơn gói đang còn hạn: Nối tiếp sau khi gói hiện tại hết hạn
            expiresAt = new Date(currentExpiresAt.getTime() + durationDays * 24 * 60 * 60 * 1000);
        }
    }
    const batch = db.batch();
    // 1. Cập nhật phòng trọ
    batch.update(roomRef, {
        packageType: packageId,
        priority: priority,
        packageStartAt: admin.firestore.Timestamp.fromDate(startAt),
        packageExpiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
        vipType: packageId,
    });
    // 2. Cập nhật / tạo bản ghi room_promotions
    const promotionRef = db.collection("room_promotions").doc(roomId);
    batch.set(promotionRef, {
        roomId: roomId,
        ownerId: orderData.userId,
        packageId: packageId,
        packageName: packageDef.name,
        priority: priority,
        status: "active",
        startAt: admin.firestore.Timestamp.fromDate(startAt),
        expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
        lastOrderId: orderData.orderId,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    // 3. Cập nhật đơn hàng thành 'completed'
    const orderRef = db.collection("package_orders").doc(orderData.orderId);
    batch.update(orderRef, {
        status: "completed",
        transactionId: transId,
        paidAt: admin.firestore.FieldValue.serverTimestamp(),
        startAt: admin.firestore.Timestamp.fromDate(startAt),
        expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    // 4. Gửi thông báo chúc mừng tới người dùng
    const notifRef = db.collection("notifications").doc();
    const dateFormatted = `${expiresAt.getDate()}/${expiresAt.getMonth() + 1}/${expiresAt.getFullYear()}`;
    batch.set(notifRef, {
        recipientId: orderData.userId,
        type: "package_activated",
        title: `Kích hoạt ${packageDef.name} thành công! 🎉`,
        body: `Phòng trọ "${orderData.roomTitle}" đã được nâng cấp lên ${packageDef.name} (Hạng ưu tiên ${priority}). Thời hạn sử dụng đến hết ngày ${dateFormatted}.`,
        roomId: roomId,
        orderId: orderData.orderId,
        isRead: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    await batch.commit();
}
// ============================================================================
// 5. TRUY VẤN VÀ ĐỐI SOÁT TRẠNG THÁI GIAO DỊCH (checkPaymentStatus)
// ============================================================================
exports.checkPaymentStatus = (0, https_1.onRequest)({
    region: "asia-southeast1",
    cors: true,
    memory: "256MiB",
    timeoutSeconds: 60,
}, async (req, res) => {
    if (req.method !== "POST") {
        res.status(405).json({ success: false, message: "Method Not Allowed" });
        return;
    }
    try {
        const authHeader = req.headers.authorization;
        if (!authHeader || !authHeader.startsWith("Bearer ")) {
            res.status(401).json({ success: false, message: "Unauthorized" });
            return;
        }
        const idToken = authHeader.split("Bearer ")[1];
        const decodedToken = await admin.auth().verifyIdToken(idToken);
        const { orderId } = req.body || {};
        if (!orderId) {
            res.status(400).json({ success: false, message: "Thiếu orderId" });
            return;
        }
        const orderRef = db.collection("package_orders").doc(orderId);
        const orderSnap = await orderRef.get();
        if (!orderSnap.exists) {
            res.status(404).json({ success: false, message: "Đơn hàng không tồn tại" });
            return;
        }
        const orderData = orderSnap.data();
        // Kiểm tra quyền: chỉ người tạo đơn hàng hoặc admin mới được truy vấn
        if (orderData.userId !== decodedToken.uid && decodedToken.role !== "admin") {
            res.status(403).json({ success: false, message: "Bạn không có quyền xem đơn hàng này" });
            return;
        }
        // Nếu đã completed thì phản hồi ngay
        if (orderData.status === "completed") {
            res.status(200).json({
                success: true,
                status: "completed",
                isCompleted: true,
                packageId: orderData.packageId,
                packageName: orderData.packageName,
            });
            return;
        }
        // Nếu đơn hàng đang pending, chủ động gọi MoMo Query API để đối soát
        const config = (0, momo_config_1.getMoMoConfig)();
        const requestId = `QUERY_${Date.now()}`;
        const rawSignature = `accessKey=${config.accessKey}` +
            `&orderId=${orderId}` +
            `&partnerCode=${config.partnerCode}` +
            `&requestId=${requestId}`;
        const signature = (0, momo_crypto_1.createMoMoSignature)(rawSignature, config.secretKey);
        const queryBody = {
            partnerCode: config.partnerCode,
            requestId: requestId,
            orderId: orderId,
            signature: signature,
            lang: "vi",
        };
        const momoQueryRes = await fetch(config.queryEndpoint, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify(queryBody),
        });
        const momoQueryJson = (await momoQueryRes.json());
        logger.info(`Kết quả đối soát MoMo query (${orderId}):`, momoQueryJson);
        if (momoQueryJson?.resultCode === 0) {
            // MoMo xác nhận đã thanh toán thành công nhưng có thể IPN bị trễ -> Kích hoạt ngay
            await activatePromotionForOrder(orderData, String(momoQueryJson.transId || ""));
            res.status(200).json({
                success: true,
                status: "completed",
                isCompleted: true,
                packageId: orderData.packageId,
                packageName: orderData.packageName,
            });
        }
        else {
            res.status(200).json({
                success: true,
                status: orderData.status,
                isCompleted: false,
                momoMessage: momoQueryJson?.message || "Giao dịch đang chờ thanh toán",
            });
        }
    }
    catch (error) {
        logger.error("Lỗi checkPaymentStatus:", error);
        res.status(500).json({ success: false, message: error?.message || "Lỗi máy chủ nội bộ" });
    }
});
// ============================================================================
// 6. QUÉT TỰ ĐỘNG HẾT HẠN GÓI ĐĂNG TIN (CRON JOB: checkExpiredPromotions)
// ============================================================================
exports.checkExpiredPromotions = (0, scheduler_1.onSchedule)({
    schedule: "every 6 hours",
    region: "asia-southeast1",
    memory: "256MiB",
}, async () => {
    logger.info("Bắt đầu quét tự động các gói đăng tin đã hết hạn...");
    const now = admin.firestore.Timestamp.now();
    try {
        const expiredPromosSnap = await db
            .collection("room_promotions")
            .where("status", "==", "active")
            .where("expiresAt", "<=", now)
            .get();
        if (expiredPromosSnap.empty) {
            logger.info("Không có gói nào cần thu hồi hạn.");
            return;
        }
        logger.info(`Phát hiện ${expiredPromosSnap.docs.length} gói đã hết hạn. Đang hoàn về tin thường...`);
        const batch = db.batch();
        for (const doc of expiredPromosSnap.docs) {
            const promo = doc.data();
            const roomId = promo.roomId;
            // 1. Cập nhật trạng thái promotion thành expired
            batch.update(doc.ref, {
                status: "expired",
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            // 2. Chuyển phòng về tin thường (priority = 0, packageType = 'normal')
            if (roomId) {
                const roomRef = db.collection("rooms").doc(roomId);
                batch.update(roomRef, {
                    priority: 0,
                    packageType: "normal",
                    vipType: "normal",
                });
                // 3. Thông báo cho chủ phòng
                if (promo.ownerId) {
                    const notifRef = db.collection("notifications").doc();
                    batch.set(notifRef, {
                        recipientId: promo.ownerId,
                        type: "package_expired",
                        title: "Gói đăng tin đã hết hạn ⏰",
                        body: `Gói ${promo.packageName} của phòng trọ đã hết hạn sử dụng. Tin đăng đã tự động chuyển về trạng thái tin thường. Bạn có thể gia hạn bất kỳ lúc nào để tiếp tục nhận ưu tiên.`,
                        roomId: roomId,
                        isRead: false,
                        createdAt: admin.firestore.FieldValue.serverTimestamp(),
                    });
                }
            }
        }
        await batch.commit();
        logger.info("Đã hoàn tất thu hồi các gói hết hạn thành công.");
    }
    catch (error) {
        logger.error("Lỗi khi quét gói hết hạn:", error);
    }
});
//# sourceMappingURL=index.js.map