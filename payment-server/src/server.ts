import "dotenv/config";
import express, { Request, Response } from "express";
import cors from "cors";
import * as admin from "firebase-admin";
import * as crypto from "crypto";

import { getMoMoConfig, PACKAGE_DEFINITIONS } from "./momo_config";
import { createMoMoSignature, verifyMoMoSignature } from "./momo_crypto";

// ============================================================================
// 1. KHỞI TẠO FIREBASE ADMIN SDK
// ============================================================================
function initFirebaseAdmin() {
  if (admin.apps.length) return;

  const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  if (serviceAccountJson && serviceAccountJson.trim().startsWith("{")) {
    const parsed = JSON.parse(serviceAccountJson);
    admin.initializeApp({
      credential: admin.credential.cert(parsed),
    });
    console.log("[Firebase] Initialized with FIREBASE_SERVICE_ACCOUNT_JSON");
  } else {
    admin.initializeApp();
    console.log("[Firebase] Initialized with default application credentials");
  }
}

initFirebaseAdmin();
const db = admin.firestore();

const app = express();
app.use(cors({ origin: true }));
app.use(express.json());

// ============================================================================
// HEALTH CHECK
// ============================================================================
app.get("/", (_req: Request, res: Response) => {
  res.status(200).json({
    status: "ok",
    service: "TroTot MoMo Payment Server",
    environment: getMoMoConfig().environment,
  });
});

app.get("/health", (_req: Request, res: Response) => {
  res.status(200).json({ status: "ok" });
});

// ============================================================================
// 2. TẠO ĐƠN HÀNG VÀ YÊU CẦU THANH TOÁN MOMO (POST /createMoMoPayment)
// ============================================================================
app.post("/createMoMoPayment", async (req: Request, res: Response) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      res.status(401).json({ success: false, message: "Yêu cầu đăng nhập (Missing Bearer Token)" });
      return;
    }

    const idToken = authHeader.split("Bearer ")[1];
    const decodedToken = await admin.auth().verifyIdToken(idToken);
    const userId = decodedToken.uid;
    const userEmail = decodedToken.email || "";

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

    // Kiểm tra quyền sở hữu phòng trọ
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

    const now = Date.now();
    const randomSuffix = crypto.randomBytes(3).toString("hex");
    const orderId = `TROTOT_${now}_${randomSuffix}`;
    const requestId = `REQ_${now}_${randomSuffix}`;
    const amount = packageDef.price;
    const orderInfo = `Thanh toan ${packageDef.name} - ${roomTitle.substring(0, 40)}`;

    const extraDataObj = { roomId, userId, packageId, amount };
    const extraData = Buffer.from(JSON.stringify(extraDataObj)).toString("base64");

    const ipnUrl = config.ipnUrl;
    const redirectUrl = returnUrl || config.redirectUrl;
    const requestType = "captureWallet";

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

    const orderData = {
      orderId,
      userId,
      userEmail,
      roomId,
      roomTitle,
      packageId: packageDef.id,
      packageName: packageDef.name,
      amount,
      durationDays: packageDef.durationDays,
      priority: packageDef.priority,
      status: "pending",
      paymentMethod: "momo",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    await db.collection("package_orders").doc(orderId).set(orderData);

    const momoRequestBody = {
      partnerCode: config.partnerCode,
      partnerName: "TroTot",
      storeId: "TroTotHanoi",
      requestId,
      amount,
      orderId,
      orderInfo,
      redirectUrl,
      ipnUrl,
      lang: "vi",
      extraData,
      requestType,
      signature,
    };

    console.log(`[MoMo] Creating payment for order ${orderId} (${amount} VND)`);

    const momoResponse = await fetch(config.endpoint, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "User-Agent": "TroTot-PaymentServer/1.0",
      },
      body: JSON.stringify(momoRequestBody),
    });

    const momoRawText = await momoResponse.text();
    let momoResJson: any;
    try {
      momoResJson = JSON.parse(momoRawText);
    } catch {
      console.error(`[MoMo] Non-JSON response (${momoResponse.status}):`, momoRawText.slice(0, 300));
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
    console.log(`[MoMo] Response (${orderId}):`, {
      resultCode: momoResJson?.resultCode,
      message: momoResJson?.message,
    });

    if (momoResJson?.resultCode === 0 && momoResJson?.payUrl) {
      await db.collection("package_orders").doc(orderId).update({
        payUrl: momoResJson.payUrl,
        qrCodeUrl: momoResJson.qrCodeUrl || "",
        deeplink: momoResJson.deeplink || "",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      res.status(200).json({
        success: true,
        orderId,
        payUrl: momoResJson.payUrl,
        qrCodeUrl: momoResJson.qrCodeUrl || "",
        deeplink: momoResJson.deeplink || "",
        amount,
        packageName: packageDef.name,
        durationDays: packageDef.durationDays,
      });
    } else {
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
    console.error("[MoMo] Error in createMoMoPayment:", error);
    res.status(500).json({ success: false, message: error?.message || "Lỗi máy chủ nội bộ" });
  }
});

// ============================================================================
// 3. TIẾP NHẬN VÀ XÁC MINH WEBHOOK IPN TỪ MOMO (POST /momoIpnWebhook)
// ============================================================================
app.post("/momoIpnWebhook", async (req: Request, res: Response) => {
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

    console.log(`[MoMo IPN] Order ${orderId}:`, { transId, resultCode, amount, message });

    const config = getMoMoConfig();

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
      console.warn(`[MoMo IPN] Invalid signature for order ${orderId}`);
      res.status(400).json({ resultCode: 99, message: "Invalid Signature" });
      return;
    }

    const orderRef = db.collection("package_orders").doc(orderId);
    const orderSnap = await orderRef.get();

    if (!orderSnap.exists) {
      res.status(404).json({ resultCode: 1, message: "Order Not Found" });
      return;
    }

    const orderData = orderSnap.data()!;

    // Idempotency
    if (orderData.status === "completed") {
      res.status(204).send();
      return;
    }

    // Đối chiếu số tiền
    if (Number(orderData.amount) !== Number(amount)) {
      await orderRef.update({
        status: "failed",
        note: `Số tiền IPN (${amount}) không khớp với đơn hàng (${orderData.amount})`,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      res.status(400).json({ resultCode: 2, message: "Amount mismatch" });
      return;
    }

    const transDocId = transId ? `MOMO_${transId}` : `MOMO_${orderId}`;
    await db.collection("payment_transactions").doc(transDocId).set({
      orderId,
      userId: orderData.userId,
      roomId: orderData.roomId,
      amount: Number(amount),
      gateway: "momo",
      transId: String(transId || ""),
      resultCode: Number(resultCode),
      message,
      payType: payType || "momo_wallet",
      rawResponse: body,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    if (Number(resultCode) === 0) {
      await activatePromotionForOrder(orderData, String(transId || ""));
      console.log(`[MoMo IPN] Activated package ${orderData.packageId} for room ${orderData.roomId}`);
    } else {
      await orderRef.update({
        status: "failed",
        transactionId: String(transId || ""),
        note: `MoMo resultCode ${resultCode}: ${message}`,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    res.status(200).json({ resultCode: 0, message: "Success" });
  } catch (error: any) {
    console.error("[MoMo IPN] Exception:", error);
    res.status(500).json({ resultCode: 99, message: error?.message || "Internal Server Error" });
  }
});

// ============================================================================
// 4. ĐỐI SOÁT TRẠNG THÁI GIAO DỊCH (POST /checkPaymentStatus)
// ============================================================================
app.post("/checkPaymentStatus", async (req: Request, res: Response) => {
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
    if (orderData.userId !== decodedToken.uid && decodedToken.role !== "admin") {
      res.status(403).json({ success: false, message: "Bạn không có quyền xem đơn hàng này" });
      return;
    }

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

    const config = getMoMoConfig();
    const requestId = `QUERY_${Date.now()}`;
    const rawSignature =
      `accessKey=${config.accessKey}` +
      `&orderId=${orderId}` +
      `&partnerCode=${config.partnerCode}` +
      `&requestId=${requestId}`;

    const signature = createMoMoSignature(rawSignature, config.secretKey);

    const momoQueryRes = await fetch(config.queryEndpoint, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        partnerCode: config.partnerCode,
        requestId,
        orderId,
        signature,
        lang: "vi",
      }),
    });

    const momoQueryJson = (await momoQueryRes.json()) as any;
    console.log(`[MoMo Query] (${orderId}):`, momoQueryJson);

    if (momoQueryJson?.resultCode === 0) {
      await activatePromotionForOrder(orderData, String(momoQueryJson.transId || ""));
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
    console.error("[MoMo Query] Error:", error);
    res.status(500).json({ success: false, message: error?.message || "Lỗi máy chủ nội bộ" });
  }
});

// ============================================================================
// 5. KÍCH HOẠT GÓI ĐĂNG TIN VÀ TÍNH THỜI HẠN CHÍNH XÁC
// ============================================================================
async function activatePromotionForOrder(orderData: FirebaseFirestore.DocumentData, transId: string) {
  const roomId = orderData.roomId;
  const packageId = orderData.packageId as "bronze" | "silver" | "gold";
  const packageDef = PACKAGE_DEFINITIONS[packageId] || PACKAGE_DEFINITIONS.bronze;
  const durationDays = packageDef.durationDays;
  const priority = packageDef.priority;

  const roomRef = db.collection("rooms").doc(roomId);
  const roomSnap = await roomRef.get();
  if (!roomSnap.exists) return;

  const roomData = roomSnap.data()!;
  const now = new Date();
  let startAt = now;
  let expiresAt = new Date(now.getTime() + durationDays * 24 * 60 * 60 * 1000);

  const currentExpiresAt = roomData.packageExpiresAt?.toDate?.() || null;
  const currentPriority = (roomData.priority || 0) as number;

  if (currentExpiresAt && currentExpiresAt > now && currentPriority > 0) {
    if (currentPriority === priority) {
      expiresAt = new Date(currentExpiresAt.getTime() + durationDays * 24 * 60 * 60 * 1000);
    } else if (priority > currentPriority) {
      const remainingMs = currentExpiresAt.getTime() - now.getTime();
      expiresAt = new Date(now.getTime() + durationDays * 24 * 60 * 60 * 1000 + remainingMs);
    } else {
      expiresAt = new Date(currentExpiresAt.getTime() + durationDays * 24 * 60 * 60 * 1000);
    }
  }

  const batch = db.batch();

  batch.update(roomRef, {
    packageType: packageId,
    priority,
    packageStartAt: admin.firestore.Timestamp.fromDate(startAt),
    packageExpiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
    vipType: packageId,
  });

  batch.set(db.collection("room_promotions").doc(roomId), {
    roomId,
    ownerId: orderData.userId,
    packageId,
    packageName: packageDef.name,
    priority,
    status: "active",
    startAt: admin.firestore.Timestamp.fromDate(startAt),
    expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
    lastOrderId: orderData.orderId,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  batch.update(db.collection("package_orders").doc(orderData.orderId), {
    status: "completed",
    transactionId: transId,
    paidAt: admin.firestore.FieldValue.serverTimestamp(),
    startAt: admin.firestore.Timestamp.fromDate(startAt),
    expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  const dateFormatted = `${expiresAt.getDate()}/${expiresAt.getMonth() + 1}/${expiresAt.getFullYear()}`;
  batch.set(db.collection("notifications").doc(), {
    recipientId: orderData.userId,
    type: "package_activated",
    title: `Kích hoạt ${packageDef.name} thành công! 🎉`,
    body: `Phòng trọ "${orderData.roomTitle}" đã được nâng cấp lên ${packageDef.name} (Hạng ưu tiên ${priority}). Thời hạn sử dụng đến hết ngày ${dateFormatted}.`,
    roomId,
    orderId: orderData.orderId,
    isRead: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await batch.commit();
}

const PORT = Number(process.env.PORT || 3000);
app.listen(PORT, () => {
  console.log(`TroTot Payment Server listening on port ${PORT} (${getMoMoConfig().environment})`);
});
