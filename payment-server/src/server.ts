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
app.use(express.urlencoded({ extended: false }));

function escapeHtml(raw: unknown): string {
  return String(raw ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

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
      redirectUrl,
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

    let momoStatus = 0;
    let momoRawText = "";
    let momoResJson: any = null;
    let momoFetchError = "";

    try {
      const momoResponse = await fetch(config.endpoint, {
        method: "POST",
        headers: {
          "Content-Type": "application/json; charset=UTF-8",
          Accept: "application/json",
          "User-Agent": "TroTot-PaymentServer/1.0",
        },
        body: JSON.stringify(momoRequestBody),
      });
      momoStatus = momoResponse.status;
      momoRawText = await momoResponse.text();
      momoResJson = JSON.parse(momoRawText);
    } catch (err: any) {
      momoFetchError = err?.message || "Invalid JSON or network error";
      console.error(
        `[MoMo] Non-JSON or network error (${momoStatus}):`,
        momoRawText ? momoRawText.slice(0, 300) : momoFetchError
      );
    }

    // Nếu MoMo Sandbox WAF chặn IP Render (HTTP 403 HTML / 5xx / lỗi mạng) -> chuyển qua MoMo Sandbox Simulator nội bộ
    if (!momoResJson || (config.environment === "sandbox" && (momoStatus === 403 || momoStatus >= 500))) {
      if (config.environment === "sandbox") {
        const checkoutToken = createMoMoSignature(
          `orderId=${orderId}&amount=${amount}`,
          config.secretKey
        );
        const serverBase = config.ipnUrl.replace(/\/momoIpnWebhook$/, "");
        const sandboxPayUrl = `${serverBase}/momoSandboxCheckout?orderId=${encodeURIComponent(
          orderId
        )}&token=${checkoutToken}`;

        await db.collection("package_orders").doc(orderId).update({
          payUrl: sandboxPayUrl,
          sandboxFallback: true,
          note: `MoMo Sandbox WAF fallback (HTTP ${momoStatus || "network"})`,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        res.status(200).json({
          success: true,
          orderId,
          payUrl: sandboxPayUrl,
          qrCodeUrl: "",
          deeplink: "",
          amount,
          packageName: packageDef.name,
          durationDays: packageDef.durationDays,
          sandboxFallback: true,
        });
        return;
      }

      await db.collection("package_orders").doc(orderId).update({
        status: "failed",
        note: `MoMo HTTP ${momoStatus} (non-JSON)`,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      res.status(502).json({
        success: false,
        message: `Cổng MoMo phản hồi không hợp lệ (HTTP ${momoStatus || "network"}).`,
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
    if (orderData.userId !== decodedToken.uid && !(await isUserAdmin(decodedToken.uid, decodedToken))) {
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

    if (orderData.status === "failed" || orderData.sandboxFallback === true) {
      res.status(200).json({
        success: true,
        status: orderData.status,
        isCompleted: false,
        momoMessage: orderData.note || "Giao dịch đang chờ xác nhận trên trang thanh toán Sandbox.",
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
      headers: {
        "Content-Type": "application/json; charset=UTF-8",
        Accept: "application/json",
        "User-Agent": "TroTot-PaymentServer/1.0",
      },
      body: JSON.stringify({
        partnerCode: config.partnerCode,
        requestId,
        orderId,
        signature,
        lang: "vi",
      }),
    });

    const queryRawText = await momoQueryRes.text();
    let momoQueryJson: any = null;
    try {
      momoQueryJson = JSON.parse(queryRawText);
    } catch {
      console.warn(`[MoMo Query] Non-JSON (${momoQueryRes.status}):`, queryRawText.slice(0, 200));
      res.status(200).json({
        success: true,
        status: orderData.status,
        isCompleted: false,
        momoMessage: `Cổng MoMo tạm thời chưa phản hồi (HTTP ${momoQueryRes.status}).`,
      });
      return;
    }
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
// 4B. MOMO SANDBOX CHECKOUT SIMULATOR (KHI CỔNG SANDBOX CHẶN IP CLOUD)
// ============================================================================
app.get("/momoSandboxCheckout", async (req: Request, res: Response) => {
  try {
    const config = getMoMoConfig();
    if (config.environment !== "sandbox") {
      res.status(403).send("Sandbox checkout is disabled in production");
      return;
    }

    const orderId = String(req.query.orderId || "").trim();
    const token = String(req.query.token || "").trim();
    if (!orderId || !token) {
      res.status(400).send("Thiếu tham số orderId hoặc token");
      return;
    }

    const orderSnap = await db.collection("package_orders").doc(orderId).get();
    if (!orderSnap.exists) {
      res.status(404).send("Không tìm thấy đơn hàng");
      return;
    }

    const orderData = orderSnap.data()!;
    const isValidToken = verifyMoMoSignature(
      `orderId=${orderId}&amount=${orderData.amount}`,
      token,
      config.secretKey
    );
    if (!isValidToken) {
      res.status(403).send("Chữ ký giao dịch không hợp lệ");
      return;
    }

    const redirectUrl = String(orderData.redirectUrl || config.redirectUrl);
    const formattedAmount = Number(orderData.amount || 0).toLocaleString("vi-VN");

    if (orderData.status === "completed") {
      res.status(200).type("html").send(`<!DOCTYPE html>
<html lang="vi">
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>MoMo Sandbox</title></head>
<body style="font-family:Arial,sans-serif;background:#fdf2f8;display:flex;align-items:center;justify-content:center;min-height:100vh;margin:0;padding:16px">
  <div style="background:#fff;max-width:440px;width:100%;border-radius:18px;padding:28px;box-shadow:0 12px 32px rgba(165,0,100,.14);text-align:center">
    <div style="font-size:44px;margin-bottom:8px">✅</div>
    <h2 style="color:#00897B;margin:0 0 8px">Đơn hàng đã thanh toán</h2>
    <p style="color:#475569;font-size:14px;line-height:1.5">Mã đơn <b>${escapeHtml(orderId)}</b> đã được kích hoạt gói VIP thành công.</p>
    <a href="${escapeHtml(redirectUrl)}" style="display:inline-block;margin-top:16px;background:#A50064;color:#fff;text-decoration:none;padding:12px 22px;border-radius:12px;font-weight:bold">Quay lại TroTot</a>
  </div>
</body>
</html>`);
      return;
    }

    res.status(200).type("html").send(`<!DOCTYPE html>
<html lang="vi">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>Cổng thanh toán MoMo (Sandbox Test)</title>
</head>
<body style="font-family:Arial,sans-serif;background:linear-gradient(135deg,#fff0f6,#f8fafc);min-height:100vh;margin:0;display:flex;align-items:center;justify-content:center;padding:16px">
  <div style="background:#fff;max-width:460px;width:100%;border-radius:20px;overflow:hidden;box-shadow:0 16px 40px rgba(165,0,100,.16);border:1px solid #fbcfe8">
    <div style="background:linear-gradient(90deg,#A50064,#D82D8B);color:#fff;padding:20px 24px;display:flex;justify-content:space-between;align-items:center">
      <div>
        <div style="font-size:20px;font-weight:900;letter-spacing:.3px">MoMo Wallet</div>
        <div style="font-size:12px;opacity:.9">Cổng thanh toán thử nghiệm TroTot</div>
      </div>
      <span style="background:rgba(255,255,255,.22);padding:5px 10px;border-radius:999px;font-size:11px;font-weight:bold">Sandbox Test</span>
    </div>
    <div style="padding:24px">
      <div style="background:#fdf2f8;border:1px solid #f9a8d4;border-radius:14px;padding:16px;text-align:center;margin-bottom:18px">
        <div style="color:#831843;font-size:12px;font-weight:bold;text-transform:uppercase">Số tiền thanh toán</div>
        <div style="color:#A50064;font-size:30px;font-weight:900;margin-top:4px">${escapeHtml(formattedAmount)} đ</div>
      </div>
      <table style="width:100%;border-collapse:collapse;font-size:14px;color:#334155;margin-bottom:20px">
        <tr><td style="padding:7px 0;color:#64748b">Mã đơn hàng</td><td style="padding:7px 0;text-align:right;font-weight:bold">${escapeHtml(orderId)}</td></tr>
        <tr><td style="padding:7px 0;color:#64748b">Gói dịch vụ</td><td style="padding:7px 0;text-align:right;font-weight:bold;color:#00897B">${escapeHtml(orderData.packageName)}</td></tr>
        <tr><td style="padding:7px 0;color:#64748b">Phòng áp dụng</td><td style="padding:7px 0;text-align:right;font-weight:600">${escapeHtml(orderData.roomTitle)}</td></tr>
      </table>
      <form method="POST" action="/momoSandboxConfirm" style="display:flex;flex-direction:column;gap:10px">
        <input type="hidden" name="orderId" value="${escapeHtml(orderId)}">
        <input type="hidden" name="token" value="${escapeHtml(token)}">
        <button type="submit" name="action" value="success" style="background:#A50064;color:#fff;border:none;border-radius:12px;padding:14px 18px;font-size:15px;font-weight:bold;cursor:pointer">✅ Xác nhận thanh toán thành công</button>
        <button type="submit" name="action" value="cancel" style="background:#fff;color:#64748b;border:1px solid #cbd5e1;border-radius:12px;padding:12px 18px;font-size:14px;font-weight:600;cursor:pointer">Hủy giao dịch</button>
      </form>
      <p style="font-size:11.5px;color:#94a3b8;text-align:center;margin:16px 0 0;line-height:1.4">Sau khi bấm xác nhận, hệ thống sẽ ký HMAC-SHA256, kích hoạt gói VIP realtime và đưa bạn về TroTot.</p>
    </div>
  </div>
</body>
</html>`);
  } catch (error: any) {
    console.error("[MoMo Sandbox Checkout] Error:", error);
    res.status(500).send("Lỗi máy chủ nội bộ");
  }
});

app.post("/momoSandboxConfirm", async (req: Request, res: Response) => {
  try {
    const config = getMoMoConfig();
    if (config.environment !== "sandbox") {
      res.status(403).send("Sandbox confirm is disabled in production");
      return;
    }

    const orderId = String(req.body?.orderId || "").trim();
    const token = String(req.body?.token || "").trim();
    const action = String(req.body?.action || "cancel").trim();

    if (!orderId || !token) {
      res.status(400).send("Thiếu tham số");
      return;
    }

    const orderRef = db.collection("package_orders").doc(orderId);
    const orderSnap = await orderRef.get();
    if (!orderSnap.exists) {
      res.status(404).send("Đơn hàng không tồn tại");
      return;
    }

    const orderData = orderSnap.data()!;
    const isValidToken = verifyMoMoSignature(
      `orderId=${orderId}&amount=${orderData.amount}`,
      token,
      config.secretKey
    );
    if (!isValidToken) {
      res.status(403).send("Chữ ký không hợp lệ");
      return;
    }

    const redirectUrl = String(orderData.redirectUrl || config.redirectUrl);

    if (orderData.status === "completed") {
      res.status(200).type("html").send(`<!DOCTYPE html>
<html lang="vi"><head><meta charset="utf-8"><meta http-equiv="refresh" content="1;url=${escapeHtml(redirectUrl)}"><title>Thành công</title></head>
<body style="font-family:Arial,sans-serif;text-align:center;padding:40px"><h3>✅ Thanh toán đã được ghi nhận! Bạn có thể đóng tab này hoặc quay lại TroTot.</h3><p><a href="${escapeHtml(redirectUrl)}">Quay lại TroTot</a></p></body></html>`);
      return;
    }

    const isSuccess = action === "success";
    const transId = `SANDBOX_${Date.now()}`;
    const resultCode = isSuccess ? 0 : 1006;
    const message = isSuccess
      ? "Giao dịch thành công (MoMo Sandbox)."
      : "Người dùng đã hủy giao dịch.";
    const responseTime = Date.now();
    const requestId = `SBX_${responseTime}`;

    const rawIpnSig =
      `accessKey=${config.accessKey}` +
      `&amount=${orderData.amount}` +
      `&extraData=` +
      `&message=${message}` +
      `&orderId=${orderId}` +
      `&orderInfo=${orderData.packageName}` +
      `&orderType=momo_wallet` +
      `&partnerCode=${config.partnerCode}` +
      `&payType=momo_wallet` +
      `&requestId=${requestId}` +
      `&responseTime=${responseTime}` +
      `&resultCode=${resultCode}` +
      `&transId=${transId}`;
    const signature = createMoMoSignature(rawIpnSig, config.secretKey);
    const sigOk = verifyMoMoSignature(rawIpnSig, signature, config.secretKey);

    await db.collection("payment_transactions").doc(`MOMO_${transId}`).set({
      orderId,
      userId: orderData.userId,
      roomId: orderData.roomId,
      amount: Number(orderData.amount),
      gateway: "momo_sandbox",
      transId,
      resultCode,
      message,
      payType: "momo_wallet",
      signatureVerified: sigOk,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    if (isSuccess && sigOk) {
      await activatePromotionForOrder(orderData, transId);
      res.status(200).type("html").send(`<!DOCTYPE html>
<html lang="vi">
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Thanh toán thành công</title></head>
<body style="font-family:Arial,sans-serif;background:#f0fdf4;display:flex;align-items:center;justify-content:center;min-height:100vh;margin:0;padding:16px">
  <div style="background:#fff;max-width:440px;width:100%;border-radius:18px;padding:28px;text-align:center;box-shadow:0 12px 30px rgba(0,137,123,.14)">
    <div style="font-size:48px">🎉</div>
    <h2 style="color:#00897B;margin:10px 0 8px">Thanh toán thành công!</h2>
    <p style="color:#475569;font-size:14px;line-height:1.5">Đã kích hoạt <b>${escapeHtml(orderData.packageName)}</b> cho phòng trọ.<br>Mã giao dịch: <code>${escapeHtml(transId)}</code></p>
    <p style="color:#64748b;font-size:12.5px">Tab ứng dụng TroTot đã tự động cập nhật kết quả. Bạn có thể đóng tab này.</p>
    <a href="${escapeHtml(redirectUrl)}" style="display:inline-block;margin-top:10px;background:#00897B;color:#fff;text-decoration:none;padding:12px 22px;border-radius:12px;font-weight:bold">Về TroTot</a>
  </div>
</body>
</html>`);
    } else {
      await orderRef.update({
        status: "failed",
        transactionId: transId,
        note: message,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      res.status(200).type("html").send(`<!DOCTYPE html>
<html lang="vi">
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Đã hủy thanh toán</title></head>
<body style="font-family:Arial,sans-serif;background:#fef2f2;display:flex;align-items:center;justify-content:center;min-height:100vh;margin:0;padding:16px">
  <div style="background:#fff;max-width:440px;width:100%;border-radius:18px;padding:28px;text-align:center;box-shadow:0 12px 30px rgba(220,38,38,.12)">
    <div style="font-size:48px">❌</div>
    <h2 style="color:#dc2626;margin:10px 0 8px">Đã hủy giao dịch</h2>
    <p style="color:#475569;font-size:14px">Bạn có thể đóng tab này và chọn lại gói trên TroTot.</p>
    <a href="${escapeHtml(redirectUrl)}" style="display:inline-block;margin-top:10px;background:#334155;color:#fff;text-decoration:none;padding:12px 22px;border-radius:12px;font-weight:bold">Quay lại TroTot</a>
  </div>
</body>
</html>`);
    }
  } catch (error: any) {
    console.error("[MoMo Sandbox Confirm] Error:", error);
    res.status(500).send("Lỗi máy chủ nội bộ");
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

// ============================================================================
// 6. HELPERS DÙNG CHUNG: PHÂN QUYỀN ADMIN, GEMINI PROXY & TÍNH RATING
// ============================================================================
async function isUserAdmin(
  uid: string,
  decodedToken?: admin.auth.DecodedIdToken
): Promise<boolean> {
  if (decodedToken?.role === "admin") return true;
  try {
    const userDoc = await db.collection("users").doc(uid).get();
    return userDoc.exists && userDoc.data()?.role === "admin";
  } catch {
    return false;
  }
}

function normalizeGeminiModel(rawModel?: string): string {
  if (!rawModel || !rawModel.trim()) {
    return "gemini-flash-latest";
  }
  const s = rawModel.trim().toLowerCase();
  if (
    s.includes("flash-lite-latest") ||
    (s.includes("latest") && s.includes("lite")) ||
    s.includes("3.1")
  ) {
    return "gemini-flash-lite-latest";
  }
  if (
    s === "gemini-flash-latest" ||
    s === "latest" ||
    s === "flash" ||
    s === "gemini-flash"
  ) {
    return "gemini-flash-latest";
  }
  if (s.includes("3.8")) {
    return "gemini-3.8-flash";
  }
  if (s.includes("3.6")) {
    return "gemini-3.6-flash";
  }
  if (s.includes("3.5")) {
    return s.includes("lite") ? "gemini-3.5-flash-lite" : "gemini-3.5-flash";
  }
  if (s.includes("2.5")) {
    return s.includes("lite") ? "gemini-2.5-flash-lite" : "gemini-2.5-flash";
  }
  if (s.startsWith("gemini-")) {
    if (s.includes("1.5") || s.includes("2.0")) {
      return "gemini-flash-latest";
    }
    return s;
  }
  return "gemini-flash-latest";
}

async function getServerGeminiApiKey(): Promise<{
  apiKey: string;
  source: "env" | "firestore_secret" | "none";
}> {
  const envKey = process.env.GEMINI_API_KEY?.trim();
  if (envKey) {
    return { apiKey: envKey, source: "env" };
  }
  try {
    const secretDoc = await db.collection("system_secrets").doc("ai_config").get();
    const fsKey = (secretDoc.data()?.apiKey as string | undefined)?.trim();
    if (fsKey) {
      return { apiKey: fsKey, source: "firestore_secret" };
    }
  } catch (err) {
    console.warn("[AI] Unable to read system_secrets/ai_config:", err);
  }
  return { apiKey: "", source: "none" };
}

interface GeminiContentPart {
  role: "user" | "model";
  parts: Array<{ text: string }>;
}

async function invokeSingleGeminiModel(params: {
  apiKey: string;
  model: string;
  contents: GeminiContentPart[];
  systemInstruction?: string;
  temperature?: number;
  responseMimeType?: string;
  timeoutMs: number;
}): Promise<{ ok: boolean; status: number; text?: string; error?: string }> {
  const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(
    params.model
  )}:generateContent?key=${encodeURIComponent(params.apiKey)}`;

  const payload: Record<string, any> = {
    contents: params.contents,
    generationConfig: {
      temperature: typeof params.temperature === "number" ? params.temperature : 0.5,
      ...(params.responseMimeType ? { responseMimeType: params.responseMimeType } : {}),
    },
  };

  if (params.systemInstruction && params.systemInstruction.trim()) {
    payload.systemInstruction = {
      parts: [{ text: params.systemInstruction.trim() }],
    };
  }

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), params.timeoutMs);

  try {
    const response = await fetch(endpoint, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
      signal: controller.signal,
    });
    const rawText = await response.text();
    let json: any = null;
    try {
      json = JSON.parse(rawText);
    } catch {
      return {
        ok: false,
        status: response.status,
        error: `Non-JSON response (HTTP ${response.status})`,
      };
    }

    if (!response.ok) {
      const msg = json?.error?.message || `HTTP ${response.status}`;
      return { ok: false, status: response.status, error: msg };
    }

    const parts = json?.candidates?.[0]?.content?.parts;
    const text = Array.isArray(parts)
      ? parts
          .map((p: any) => (typeof p?.text === "string" ? p.text : ""))
          .join("")
          .trim()
      : "";

    if (!text) {
      return { ok: false, status: response.status, error: "Empty candidate response" };
    }
    return { ok: true, status: response.status, text };
  } catch (err: any) {
    return {
      ok: false,
      status: 0,
      error: err?.name === "AbortError" ? "Request timeout" : err?.message || "Fetch error",
    };
  } finally {
    clearTimeout(timer);
  }
}

async function callGeminiRestWithFallback(params: {
  apiKey: string;
  modelName?: string;
  contents: GeminiContentPart[];
  systemInstruction?: string;
  temperature?: number;
  responseMimeType?: string;
  timeoutMs?: number;
}): Promise<{ text: string; modelUsed: string }> {
  const timeoutMs = params.timeoutMs ?? 8000;
  const primary = normalizeGeminiModel(params.modelName);
  const baseCandidates = [
    primary,
    "gemini-flash-lite-latest",
    "gemini-flash-latest",
    "gemini-3.5-flash-lite",
    "gemini-3.8-flash",
    "gemini-2.5-flash-lite",
    "gemini-2.5-flash",
  ];
  const candidates = Array.from(new Set(baseCandidates));

  let lastError = "Không thể kết nối đến Google Gemini API";
  let hadNotFound = false;

  for (const model of candidates) {
    const result = await invokeSingleGeminiModel({
      apiKey: params.apiKey,
      model,
      contents: params.contents,
      systemInstruction: params.systemInstruction,
      temperature: params.temperature,
      responseMimeType: params.responseMimeType,
      timeoutMs,
    });
    if (result.ok && result.text) {
      return { text: result.text, modelUsed: model };
    }
    if (result.status === 404 || (result.error && result.error.toLowerCase().includes("not found"))) {
      hadNotFound = true;
    }
    lastError = `[${model}] ${result.error || "Unknown error"}`;
  }

  // Fallback động: hỏi danh sách model đang mở cho key nếu toàn bộ model tĩnh báo 404
  if (hadNotFound) {
    try {
      const listRes = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models?key=${encodeURIComponent(
          params.apiKey
        )}`
      );
      if (listRes.ok) {
        const listJson = (await listRes.json()) as any;
        const models: any[] = Array.isArray(listJson?.models) ? listJson.models : [];
        const matched = models.find((m) => {
          const name = String(m?.name || "").toLowerCase();
          const methods: string[] = Array.isArray(m?.supportedGenerationMethods)
            ? m.supportedGenerationMethods
            : [];
          return name.includes("flash") && methods.includes("generateContent");
        });
        if (matched?.name) {
          const discoveredModel = String(matched.name).replace(/^models\//, "");
          const retry = await invokeSingleGeminiModel({
            apiKey: params.apiKey,
            model: discoveredModel,
            contents: params.contents,
            systemInstruction: params.systemInstruction,
            temperature: params.temperature,
            responseMimeType: params.responseMimeType,
            timeoutMs,
          });
          if (retry.ok && retry.text) {
            return { text: retry.text, modelUsed: discoveredModel };
          }
          lastError = `[${discoveredModel}] ${retry.error || "Unknown error"}`;
        }
      }
    } catch {
      // ignore discovery error
    }
  }

  throw new Error(lastError);
}

async function recalculateRoomRatingInternal(
  roomId: string
): Promise<{ averageRating: number; totalReviews: number }> {
  const snap = await db.collection("reviews").where("roomId", "==", roomId).get();
  const totalReviews = snap.size;
  let sum = 0;
  for (const doc of snap.docs) {
    sum += Number(doc.data()?.rating || 0);
  }
  const averageRating = totalReviews > 0 ? Number((sum / totalReviews).toFixed(1)) : 0;
  await db.collection("rooms").doc(roomId).update({
    averageRating,
    totalReviews,
  });
  return { averageRating, totalReviews };
}

// ============================================================================
// 7. GEMINI AI PROXY ENDPOINTS (POST /aiChatProxy, POST /testGeminiConnection, GET /admin/aiKeyStatus)
// ============================================================================
app.post("/aiChatProxy", async (req: Request, res: Response) => {
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

    const { apiKey, source } = await getServerGeminiApiKey();
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
    console.error("[AI Proxy] Error:", error);
    res.status(502).json({
      success: false,
      message: error?.message || "Lỗi khi gọi Gemini AI Proxy",
    });
  }
});

app.post("/testGeminiConnection", async (req: Request, res: Response) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      res.status(401).json({ success: false, message: "Unauthorized" });
      return;
    }

    const idToken = authHeader.split("Bearer ")[1];
    const decodedToken = await admin.auth().verifyIdToken(idToken);
    if (!(await isUserAdmin(decodedToken.uid, decodedToken))) {
      res.status(403).json({ success: false, message: "Chỉ Admin mới có quyền kiểm tra kết nối AI" });
      return;
    }

    const { modelName, apiKey: candidateKey } = req.body || {};
    let effectiveKey = typeof candidateKey === "string" ? candidateKey.trim() : "";
    let keySource: "request" | "env" | "firestore_secret" | "none" = effectiveKey ? "request" : "none";

    if (!effectiveKey) {
      const serverKey = await getServerGeminiApiKey();
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
    console.error("[AI Test] Error:", error);
    res.status(502).json({
      success: false,
      message: error?.message || "Không thể kết nối đến máy chủ Google Gemini.",
    });
  }
});

app.get("/admin/aiKeyStatus", async (req: Request, res: Response) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      res.status(401).json({ success: false, message: "Unauthorized" });
      return;
    }

    const idToken = authHeader.split("Bearer ")[1];
    const decodedToken = await admin.auth().verifyIdToken(idToken);
    if (!(await isUserAdmin(decodedToken.uid, decodedToken))) {
      res.status(403).json({ success: false, message: "Forbidden" });
      return;
    }

    const { source } = await getServerGeminiApiKey();
    res.status(200).json({
      success: true,
      configured: source !== "none",
      source,
    });
  } catch (error: any) {
    res.status(500).json({ success: false, message: error?.message || "Internal Server Error" });
  }
});

// ============================================================================
// 8. TÍNH LẠI ĐIỂM ĐÁNH GIÁ PHÒNG PHÍA SERVER (POST /recalculateRoomRating)
// ============================================================================
app.post("/recalculateRoomRating", async (req: Request, res: Response) => {
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

    const stats = await recalculateRoomRatingInternal(roomId.trim());
    res.status(200).json({
      success: true,
      averageRating: stats.averageRating,
      totalReviews: stats.totalReviews,
    });
  } catch (error: any) {
    console.error("[RecalculateRating] Error:", error);
    res.status(500).json({ success: false, message: error?.message || "Internal Server Error" });
  }
});

const PORT = Number(process.env.PORT || 3000);

// ============================================================================
// 9. QUÉT TỰ ĐỘNG GÓI ĐĂNG TIN ĐÃ HẾT HẠN (ĐỒNG BỘ VỚI CLOUD FUNCTIONS)
// ============================================================================
async function sweepExpiredPromotions(): Promise<{ expiredCount: number }> {
  const now = admin.firestore.Timestamp.now();
  const expiredPromosSnap = await db
    .collection("room_promotions")
    .where("status", "==", "active")
    .where("expiresAt", "<=", now)
    .get();

  if (expiredPromosSnap.empty) {
    return { expiredCount: 0 };
  }

  const batch = db.batch();
  let expiredCount = 0;

  for (const doc of expiredPromosSnap.docs) {
    const promo = doc.data();
    const roomId = promo.roomId as string | undefined;
    expiredCount += 1;

    batch.update(doc.ref, {
      status: "expired",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    if (roomId) {
      batch.update(db.collection("rooms").doc(roomId), {
        priority: 0,
        packageType: "normal",
        vipType: "normal",
      });

      if (promo.ownerId) {
        batch.set(db.collection("notifications").doc(), {
          recipientId: promo.ownerId,
          type: "package_expired",
          title: "Gói đăng tin đã hết hạn ⏰",
          body: `Gói ${promo.packageName} của phòng trọ đã hết hạn sử dụng. Tin đăng đã tự động chuyển về trạng thái tin thường. Bạn có thể gia hạn bất kỳ lúc nào để tiếp tục nhận ưu tiên.`,
          roomId,
          isRead: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    }
  }

  await batch.commit();
  return { expiredCount };
}

app.post("/checkExpiredPromotions", async (req: Request, res: Response) => {
  try {
    const cronSecret = process.env.CRON_SECRET?.trim();
    const reqSecret = String(req.headers["x-cron-secret"] || "").trim();
    let authorized = Boolean(cronSecret && reqSecret && reqSecret === cronSecret);

    if (!authorized) {
      const authHeader = req.headers.authorization;
      if (!authHeader || !authHeader.startsWith("Bearer ")) {
        res.status(401).json({ success: false, message: "Unauthorized" });
        return;
      }
      const idToken = authHeader.split("Bearer ")[1];
      const decodedToken = await admin.auth().verifyIdToken(idToken);
      authorized = await isUserAdmin(decodedToken.uid, decodedToken);
      if (!authorized) {
        res.status(403).json({ success: false, message: "Forbidden" });
        return;
      }
    }

    const result = await sweepExpiredPromotions();
    res.status(200).json({ success: true, expiredCount: result.expiredCount });
  } catch (error: any) {
    console.error("[Promotions] Error in checkExpiredPromotions:", error);
    res.status(500).json({ success: false, message: error?.message || "Internal Server Error" });
  }
});

app.listen(PORT, () => {
  console.log(`TroTot Payment Server listening on port ${PORT} (${getMoMoConfig().environment})`);

  const runSweepSafely = async () => {
    try {
      const { expiredCount } = await sweepExpiredPromotions();
      if (expiredCount > 0) {
        console.log(`[Promotions] Expired ${expiredCount} promotion(s)`);
      }
    } catch (err) {
      console.error("[Promotions] Periodic sweep error:", err);
    }
  };

  setTimeout(runSweepSafely, 15 * 1000);
  setInterval(runSweepSafely, 6 * 60 * 60 * 1000);
});
