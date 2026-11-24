"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.createMoMoSignature = createMoMoSignature;
exports.verifyMoMoSignature = verifyMoMoSignature;
const crypto = require("crypto");
/**
 * Sinh chữ ký HMAC-SHA256 chuẩn MoMo
 * @param rawSignature Chuỗi tham số được ghép theo đúng quy định MoMo
 * @param secretKey Khóa bí mật do MoMo cấp
 */
function createMoMoSignature(rawSignature, secretKey) {
    return crypto
        .createHmac("sha256", secretKey)
        .update(rawSignature)
        .digest("hex");
}
/**
 * Xác minh chữ ký IPN / Callback từ MoMo
 * Sử dụng timingSafeEqual để chống tấn công Timing Attack
 */
function verifyMoMoSignature(rawSignature, receivedSignature, secretKey) {
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
    }
    catch {
        return false;
    }
}
//# sourceMappingURL=momo_crypto.js.map