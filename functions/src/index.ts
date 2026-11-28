import { onDocumentCreated, onDocumentDeleted } from "firebase-functions/v2/firestore";
import { onRequest } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";
import * as crypto from "crypto";

import {
  getMoMoConfig as getSharedMoMoConfig,
  PACKAGE_DEFINITIONS,
} from "../../backend-shared/momo_config";
import { createMoMoSignature, verifyMoMoSignature } from "../../backend-shared/momo_crypto";
import {
  callGeminiRestWithFallback,
  GeminiContentPart,
  getServerGeminiApiKey,
  normalizeGeminiModel,
} from "../../backend-shared/gemini_proxy";
import {
  activatePromotionForOrder,
  isUserAdmin,
  recalculateRoomRatingInternal,
  sweepExpiredPromotions,
} from "../../backend-shared/firestore_ops";

const getMoMoConfig = () =>
  getSharedMoMoConfig({
    defaultIpnUrl: "https://asia-southeast1-phongtro-ai.cloudfunctions.net/momoIpnWebhook",
    defaultSandboxRedirectUrl: "https://asia-southeast1-phongtro-ai.cloudfunctions.net/momoRedirect",
    defaultProdRedirectUrl: "https://trotot.web.app/#/payment-result",
    allowSandboxEnvOverrides: false,
  });

// Khởi tạo Firebase Admin SDK
if (!admin.apps.length) {
  admin.initializeApp();
}
const db = admin.firestore();

// ============================================================================
// 1. MODULE TỰ ĐỘNG KIỂM DUYỆT BÁO CÁO (AUTO-MODERATION PIPELINE) - GIỮ NGUYÊN
// ============================================================================
const AUTO_MODERATION_REPORT_THRESHOLD = 5;

export const onReportCreatedAutoModerate = onDocumentCreated(
  {
    document: "reports/{reportId}",
    region: "asia-southeast1",
    memory: "256MiB",
    timeoutSeconds: 60,
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const reportData = snap.data();
    const roomId = reportData?.roomId;
    const roomTitle = reportData?.roomTitle || "Phòng trọ";

    if (!roomId || typeof roomId !== "string" || roomId.trim().length === 0) {
      return;
    }

    try {
      const roomRef = db.collection("rooms").doc(roomId);
      const roomSnap = await roomRef.get();
      if (!roomSnap.exists) return;

      const roomData = roomSnap.data();
      if (roomData?.status === "hidden") return;

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
    } catch (error) {
      logger.error("Lỗi onReportCreatedAutoModerate:", error);
    }
  }
);

// ============================================================================
// 2. TẠO ĐƠN HÀNG VÀ YÊU CẦU THANH TOÁN MOMO PHÍA SERVER (createMoMoPayment)
// ============================================================================
export const createMoMoPayment = onRequest(
  {
    region: "asia-southeast1",
    cors: true,
    memory: "256MiB",
    timeoutSeconds: 60,
  },
  async (req, res) => {
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

      const packageDef = PACKAGE_DEFINITIONS[packageId];
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
      const config = getMoMoConfig();

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
      const rawSignature =
        `accessKey=${config.accessKey}` +
        `&amount=${amount}` +
        `&extraData=${extraData}` +
        `&ipnUrl=${ipnUrl}` +
        `&orderId=${orderId}` +
        `&orderInfo=${orderInfo}` +
        `&partnerCode=${config.partnerCode}` +
        `&redirectUrl=${redirectUrl}` +
        `&requestId=${requestId}` +
        `&requestType=${requestType}`;

      const signature = createMoMoSignature(rawSignature, config.secretKey);

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
        headers: {
          "Content-Type": "application/json; charset=UTF-8",
          Accept: "application/json",
          "User-Agent": "TroTot-PaymentServer/1.0",
        },
        body: JSON.stringify(momoRequestBody),
      });

      const momoRawText = await momoResponse.text();
      let momoResJson: any;
      try {
        momoResJson = JSON.parse(momoRawText);
      } catch {
        logger.warn(`MoMo create trả non-JSON (HTTP ${momoResponse.status}):`, momoRawText.slice(0, 200));
        await db.collection("package_orders").doc(orderId).update({
          status: "failed",
          note: `MoMo HTTP ${momoResponse.status} (non-JSON)`,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        res.status(502).json({
          success: false,
          message: `Cổng MoMo phản hồi không hợp lệ (HTTP ${momoResponse.status}).`,
        });
        return;
      }
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
      } else {
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
    } catch (error: any) {
      logger.error("Lỗi xử lý createMoMoPayment:", error);
      res.status(500).json({ success: false, message: error?.message || "Lỗi máy chủ nội bộ" });
    }
  }
);

// ============================================================================
// 3. TIẾP NHẬN VÀ XÁC MINH WEBHOOK IPN TỪ MOMO (momoIpnWebhook)
// ============================================================================
export const momoIpnWebhook = onRequest(
  {
    region: "asia-southeast1",
    cors: false, // IPN từ MoMo server-to-server
    memory: "256MiB",
    timeoutSeconds: 60,
  },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).send("Method Not Allowed");
      return;
    }

    try {
      const body = req.body || {};
      const {
        partnerCode,
        orderId,
        requestId,
        amount,
        orderInfo,
        orderType,
        transId,
        resultCode,
        message,
        payType,
        responseTime,
        extraData,
        signature,
      } = body;

      logger.info(`Nhận IPN Webhook từ MoMo cho đơn hàng ${orderId}:`, {
        transId,
        resultCode,
        amount,
        message,
      });

      const config = getMoMoConfig();

      // 1. Xác thực chữ ký HMAC-SHA256 của MoMo
      const rawSignature =
        `accessKey=${config.accessKey}` +
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

      const isValidSignature = verifyMoMoSignature(rawSignature, signature, config.secretKey);
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

      const orderData = orderSnap.data()!;

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
        await activatePromotionForOrder({ db, firestoreAdmin: admin.firestore, orderData, transId: String(transId || ""), onInfo: (m) => logger.info(m) });
        logger.info(`Kích hoạt thành công gói ${orderData.packageId} cho phòng ${orderData.roomId}!`);
      } else {
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
    } catch (error: any) {
      logger.error("Lỗi ngoại lệ trong momoIpnWebhook:", error);
      res.status(500).json({ resultCode: 99, message: error?.message || "Internal Server Error" });
    }
  }
);

// ============================================================================
// 4. HÀM NỘI BỘ: KÍCH HOẠT GÓI ĐĂNG TIN VÀ TÍNH TOÁN THỜI HẠN CHÍNH XÁC
// ============================================================================
// ============================================================================
// 5. TRUY VẤN VÀ ĐỐI SOÁT TRẠNG THÁI GIAO DỊCH (checkPaymentStatus)
// ============================================================================
export const checkPaymentStatus = onRequest(
  {
    region: "asia-southeast1",
    cors: true,
    memory: "256MiB",
    timeoutSeconds: 60,
  },
  async (req, res) => {
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

      const orderData = orderSnap.data()!;

      // Kiểm tra quyền: chỉ người tạo đơn hàng hoặc admin mới được truy vấn
      if (orderData.userId !== decodedToken.uid && !(await isUserAdmin(db, decodedToken.uid, decodedToken))) {
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
      const config = getMoMoConfig();
      const requestId = `QUERY_${Date.now()}`;
      const rawSignature =
        `accessKey=${config.accessKey}` +
        `&orderId=${orderId}` +
        `&partnerCode=${config.partnerCode}` +
        `&requestId=${requestId}`;

      const signature = createMoMoSignature(rawSignature, config.secretKey);

      const queryBody = {
        partnerCode: config.partnerCode,
        requestId: requestId,
        orderId: orderId,
        signature: signature,
        lang: "vi",
      };

      const momoQueryRes = await fetch(config.queryEndpoint, {
        method: "POST",
        headers: {
          "Content-Type": "application/json; charset=UTF-8",
          Accept: "application/json",
          "User-Agent": "TroTot-PaymentServer/1.0",
        },
        body: JSON.stringify(queryBody),
      });

      const queryRawText = await momoQueryRes.text();
      let momoQueryJson: any;
      try {
        momoQueryJson = JSON.parse(queryRawText);
      } catch {
        logger.warn(`MoMo query trả non-JSON (HTTP ${momoQueryRes.status}):`, queryRawText.slice(0, 200));
        res.status(200).json({
          success: true,
          status: orderData.status,
          isCompleted: false,
          momoMessage: `Cổng MoMo tạm thời chưa phản hồi (HTTP ${momoQueryRes.status}).`,
        });
        return;
      }
      logger.info(`Kết quả đối soát MoMo query (${orderId}):`, momoQueryJson);

      if (momoQueryJson?.resultCode === 0) {
        // MoMo xác nhận đã thanh toán thành công nhưng có thể IPN bị trễ -> Kích hoạt ngay
        await activatePromotionForOrder({ db, firestoreAdmin: admin.firestore, orderData, transId: String(momoQueryJson.transId || ""), onInfo: (m) => logger.info(m) });
        res.status(200).json({
          success: true,
          status: "completed",
          isCompleted: true,
          packageId: orderData.packageId,
          packageName: orderData.packageName,
        });
      } else {
        res.status(200).json({
          success: true,
          status: orderData.status,
          isCompleted: false,
          momoMessage: momoQueryJson?.message || "Giao dịch đang chờ thanh toán",
        });
      }
    } catch (error: any) {
      logger.error("Lỗi checkPaymentStatus:", error);
      res.status(500).json({ success: false, message: error?.message || "Lỗi máy chủ nội bộ" });
    }
  }
);

// ============================================================================
// 6. QUÉT TỰ ĐỘNG HẾT HẠN GÓI ĐĂNG TIN (CRON JOB: checkExpiredPromotions)
// ============================================================================
export const checkExpiredPromotions = onSchedule(
  {
    schedule: "every 6 hours",
    region: "asia-southeast1",
    memory: "256MiB",
  },
  async () => {
    logger.info("Bắt đầu quét tự động các gói đăng tin đã hết hạn...");
    try {
      const { expiredCount } = await sweepExpiredPromotions({
        db,
        firestoreAdmin: admin.firestore,
        onInfo: (m) => logger.info(m),
      });
      if (expiredCount === 0) {
        logger.info("Không có gói nào cần thu hồi hạn.");
      } else {
        logger.info("Đã hoàn tất thu hồi các gói hết hạn thành công.");
      }
    } catch (error) {
      logger.error("Lỗi khi quét gói hết hạn:", error);
    }
  }
);

// ============================================================================
// 7. HELPERS DÙNG CHUNG & TỰ ĐỘNG CẬP NHẬT RATING PHÍA SERVER
// ============================================================================
export const onReviewCreatedRecalculateRating = onDocumentCreated(
  {
    document: "reviews/{reviewId}",
    region: "asia-southeast1",
    memory: "256MiB",
    timeoutSeconds: 60,
  },
  async (event) => {
    const roomId = event.data?.data()?.roomId;
    if (roomId && typeof roomId === "string" && roomId.trim()) {
      await recalculateRoomRatingInternal(db, roomId.trim());
    }
  }
);

export const onReviewDeletedRecalculateRating = onDocumentDeleted(
  {
    document: "reviews/{reviewId}",
    region: "asia-southeast1",
    memory: "256MiB",
    timeoutSeconds: 60,
  },
  async (event) => {
    const roomId = event.data?.data()?.roomId;
    if (roomId && typeof roomId === "string" && roomId.trim()) {
      await recalculateRoomRatingInternal(db, roomId.trim());
    }
  }
);

// ============================================================================
// 8. GEMINI AI PROXY & RECALCULATE RATING ENDPOINTS
// ============================================================================
export const aiChatProxy = onRequest(
  {
    region: "asia-southeast1",
    cors: true,
    memory: "256MiB",
    timeoutSeconds: 60,
  },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).json({ success: false, message: "Method Not Allowed" });
      return;
    }

    try {
      const authHeader = req.headers.authorization;
      if (!authHeader || !authHeader.startsWith("Bearer ")) {
        res.status(401).json({ success: false, message: "Yêu cầu đăng nhập" });
        return;
      }

      const idToken = authHeader.split("Bearer ")[1];
      await admin.auth().verifyIdToken(idToken);

      const { userMessage, systemInstruction, history, modelName, temperature, mode } = req.body || {};
      if (!userMessage || typeof userMessage !== "string" || !userMessage.trim()) {
        res.status(400).json({ success: false, message: "Thiếu nội dung userMessage" });
        return;
      }

      const { apiKey, source } = await getServerGeminiApiKey(db, (err) => logger.warn("Unable to read system_secrets/ai_config:", err));
      if (source === "none" || !apiKey) {
        res.status(503).json({
          success: false,
          code: "NO_API_KEY",
          message: "Server chưa cấu hình GEMINI_API_KEY",
        });
        return;
      }

      const contents: GeminiContentPart[] = [];
      if (Array.isArray(history)) {
        for (const item of history) {
          const txt = typeof item?.text === "string" ? item.text.trim() : "";
          if (!txt) continue;
          const role: "user" | "model" = item?.role === "model" ? "model" : "user";
          contents.push({ role, parts: [{ text: txt }] });
        }
      }
      contents.push({ role: "user", parts: [{ text: userMessage.trim() }] });

      const isIntentMode = mode === "intent";
      const result = await callGeminiRestWithFallback({
        apiKey,
        modelName,
        contents,
        systemInstruction: typeof systemInstruction === "string" ? systemInstruction : undefined,
        temperature: isIntentMode ? 0.1 : typeof temperature === "number" ? temperature : 0.5,
        responseMimeType: isIntentMode ? "application/json" : undefined,
        timeoutMs: isIntentMode ? 4500 : 10000,
      });

      res.status(200).json({
        success: true,
        text: result.text,
        modelUsed: result.modelUsed,
      });
    } catch (error: any) {
      logger.error("Lỗi aiChatProxy:", error);
      res.status(502).json({
        success: false,
        message: error?.message || "Lỗi khi gọi Gemini AI Proxy",
      });
    }
  }
);

export const testGeminiConnection = onRequest(
  {
    region: "asia-southeast1",
    cors: true,
    memory: "256MiB",
    timeoutSeconds: 60,
  },
  async (req, res) => {
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
      if (!(await isUserAdmin(db, decodedToken.uid, decodedToken))) {
        res.status(403).json({ success: false, message: "Chỉ Admin mới có quyền kiểm tra kết nối AI" });
        return;
      }

      const { modelName, apiKey: candidateKey } = req.body || {};
      let effectiveKey = typeof candidateKey === "string" ? candidateKey.trim() : "";
      let keySource: "request" | "env" | "firestore_secret" | "none" = effectiveKey ? "request" : "none";

      if (!effectiveKey) {
        const serverKey = await getServerGeminiApiKey(db, (err) => logger.warn("Unable to read system_secrets/ai_config:", err));
        effectiveKey = serverKey.apiKey;
        keySource = serverKey.source;
      }

      if (!effectiveKey || keySource === "none") {
        res.status(400).json({
          success: false,
          message: "Chưa cấu hình GEMINI_API_KEY trên server hoặc trong system_secrets/ai_config.",
        });
        return;
      }

      const normalized = normalizeGeminiModel(typeof modelName === "string" ? modelName : undefined);
      const result = await callGeminiRestWithFallback({
        apiKey: effectiveKey,
        modelName: normalized,
        contents: [
          {
            role: "user",
            parts: [{ text: 'Phản hồi lại đúng 1 từ "OK" để kiểm tra kết nối.' }],
          },
        ],
        temperature: 0.2,
        timeoutMs: 8000,
      });

      const message =
        result.modelUsed !== normalized
          ? `Kết nối thành công! Tự động tối ưu sang ${result.modelUsed}: ${result.text}`
          : `Kết nối thành công (${result.modelUsed}): ${result.text}`;

      res.status(200).json({
        success: true,
        modelUsed: result.modelUsed,
        reply: result.text,
        keySource,
        message,
      });
    } catch (error: any) {
      logger.error("Lỗi testGeminiConnection:", error);
      res.status(502).json({
        success: false,
        message: error?.message || "Không thể kết nối đến máy chủ Google Gemini.",
      });
    }
  }
);

export const recalculateRoomRating = onRequest(
  {
    region: "asia-southeast1",
    cors: true,
    memory: "256MiB",
    timeoutSeconds: 60,
  },
  async (req, res) => {
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
      await admin.auth().verifyIdToken(idToken);

      const { roomId } = req.body || {};
      if (!roomId || typeof roomId !== "string" || !roomId.trim()) {
        res.status(400).json({ success: false, message: "Thiếu roomId" });
        return;
      }

      const roomSnap = await db.collection("rooms").doc(roomId.trim()).get();
      if (!roomSnap.exists) {
        res.status(404).json({ success: false, message: "Phòng trọ không tồn tại" });
        return;
      }

      const stats = await recalculateRoomRatingInternal(db, roomId.trim());
      res.status(200).json({
        success: true,
        averageRating: stats.averageRating,
        totalReviews: stats.totalReviews,
      });
    } catch (error: any) {
      logger.error("Lỗi recalculateRoomRating:", error);
      res.status(500).json({ success: false, message: error?.message || "Internal Server Error" });
    }
  }
);
