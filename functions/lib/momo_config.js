"use strict";
/**
 * Cấu hình MoMo Payment Gateway (Hỗ trợ Sandbox và Production)
 *
 * Tài liệu chính thức:
 * https://developers.momo.vn/v3/vi/docs/payment/api/payment-api/init/
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.PACKAGE_DEFINITIONS = void 0;
exports.getMoMoConfig = getMoMoConfig;
/**
 * Thông tin cấu hình môi trường Sandbox chính thức từ MoMo Developer Documentation
 */
const SANDBOX_CONFIG = {
    partnerCode: "MOMO",
    accessKey: "klm05TvNBzhg7hY8",
    secretKey: "at67qH6mk8w5Y1nAyMoYKMWACiEi2Aca",
    endpoint: "https://test-payment.momo.vn/v2/gateway/api/create",
    queryEndpoint: "https://test-payment.momo.vn/v2/gateway/api/query",
    ipnUrl: "https://asia-southeast1-phongtro-ai.cloudfunctions.net/momoIpnWebhook",
    redirectUrl: "https://asia-southeast1-phongtro-ai.cloudfunctions.net/momoRedirect",
    environment: "sandbox",
};
/**
 * Lấy cấu hình MoMo hiện tại dựa trên biến môi trường.
 * Nếu đã cấu hình MOMO_ENVIRONMENT=production thì dùng Production credentials.
 * Mặc định chuyển sang Sandbox để an toàn tuyệt đối khi kiểm thử.
 */
function getMoMoConfig() {
    const isProduction = process.env.MOMO_ENVIRONMENT === "production";
    if (isProduction) {
        return {
            partnerCode: process.env.MOMO_PARTNER_CODE || "",
            accessKey: process.env.MOMO_ACCESS_KEY || "",
            secretKey: process.env.MOMO_SECRET_KEY || "",
            endpoint: process.env.MOMO_ENDPOINT || "https://payment.momo.vn/v2/gateway/api/create",
            queryEndpoint: process.env.MOMO_QUERY_ENDPOINT || "https://payment.momo.vn/v2/gateway/api/query",
            ipnUrl: process.env.MOMO_IPN_URL || "https://asia-southeast1-phongtro-ai.cloudfunctions.net/momoIpnWebhook",
            redirectUrl: process.env.MOMO_REDIRECT_URL || "https://trotot.web.app/#/payment-result",
            environment: "production",
        };
    }
    return SANDBOX_CONFIG;
}
exports.PACKAGE_DEFINITIONS = {
    bronze: {
        id: "bronze",
        name: "Gói Đồng",
        price: 15000,
        durationDays: 7,
        priority: 1,
    },
    silver: {
        id: "silver",
        name: "Gói Bạc",
        price: 39000,
        durationDays: 15,
        priority: 2,
    },
    gold: {
        id: "gold",
        name: "Gói Vàng",
        price: 69000,
        durationDays: 30,
        priority: 3,
    },
};
//# sourceMappingURL=momo_config.js.map