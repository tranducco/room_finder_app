import * as crypto from "crypto";

/**
 * Sinh chữ ký HMAC-SHA256 chuẩn MoMo
 */
export function createMoMoSignature(rawSignature: string, secretKey: string): string {
  return crypto
    .createHmac("sha256", secretKey)
    .update(rawSignature)
    .digest("hex");
}

/**
 * Xác minh chữ ký IPN / Callback từ MoMo (chống Timing Attack)
 */
export function verifyMoMoSignature(
  rawSignature: string,
  receivedSignature: string,
  secretKey: string
): boolean {
  if (!rawSignature || !receivedSignature || !secretKey) {
    return false;
  }

  const expectedSignature = createMoMoSignature(rawSignature, secretKey);

  try {
    const expectedBuf = Buffer.from(expectedSignature, "utf8");
    const receivedBuf = Buffer.from(receivedSignature, "utf8");

    if (expectedBuf.length !== receivedBuf.length) {
      return false;
    }

    return crypto.timingSafeEqual(expectedBuf, receivedBuf);
  } catch {
    return false;
  }
}
