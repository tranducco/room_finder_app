/**
 * Cấu hình MoMo Payment Gateway dùng chung (Hỗ trợ Sandbox và Production)
 */

export interface MoMoConfig {
  partnerCode: string;
  accessKey: string;
  secretKey: string;
  endpoint: string;
  queryEndpoint: string;
  ipnUrl: string;
  redirectUrl: string;
  environment: "sandbox" | "production";
}

export interface MoMoConfigOptions {
  defaultServerBaseUrl?: string;
  defaultAppBaseUrl?: string;
  defaultIpnUrl?: string;
  defaultSandboxRedirectUrl?: string;
  defaultProdRedirectUrl?: string;
  allowSandboxEnvOverrides?: boolean;
}

export function getMoMoConfig(options: MoMoConfigOptions = {}): MoMoConfig {
  const serverBase = (
    process.env.SERVER_BASE_URL ||
    process.env.RENDER_EXTERNAL_URL ||
    options.defaultServerBaseUrl ||
    "https://room-finder-app-o3aq.onrender.com"
  ).replace(/\/+$/, "");
  const appBase = (
    process.env.APP_BASE_URL ||
    options.defaultAppBaseUrl ||
    "https://phongtro-ai.web.app"
  ).replace(/\/+$/, "");
  const isProduction = process.env.MOMO_ENVIRONMENT === "production";
  const allowSandboxOverrides = options.allowSandboxEnvOverrides !== false;

  const defaultIpnUrl = options.defaultIpnUrl || `${serverBase}/momoIpnWebhook`;
  const defaultProdRedirectUrl =
    options.defaultProdRedirectUrl || `${appBase}/#/payment-result`;
  const defaultSandboxRedirectUrl =
    options.defaultSandboxRedirectUrl || `${appBase}/#/payment-result`;

  if (isProduction) {
    return {
      partnerCode: process.env.MOMO_PARTNER_CODE || "",
      accessKey: process.env.MOMO_ACCESS_KEY || "",
      secretKey: process.env.MOMO_SECRET_KEY || "",
      endpoint:
        process.env.MOMO_ENDPOINT ||
        "https://payment.momo.vn/v2/gateway/api/create",
      queryEndpoint:
        process.env.MOMO_QUERY_ENDPOINT ||
        "https://payment.momo.vn/v2/gateway/api/query",
      ipnUrl: process.env.MOMO_IPN_URL || defaultIpnUrl,
      redirectUrl: process.env.MOMO_REDIRECT_URL || defaultProdRedirectUrl,
      environment: "production",
    };
  }

  return {
    partnerCode:
      (allowSandboxOverrides ? process.env.MOMO_PARTNER_CODE : undefined) ||
      "MOMO",
    accessKey:
      (allowSandboxOverrides ? process.env.MOMO_ACCESS_KEY : undefined) ||
      "F8BBA842ECF85",
    secretKey:
      (allowSandboxOverrides ? process.env.MOMO_SECRET_KEY : undefined) ||
      "K951B6PE1waDMi640xX08PD3vg6EkVlz",
    endpoint: "https://test-payment.momo.vn/v2/gateway/api/create",
    queryEndpoint: "https://test-payment.momo.vn/v2/gateway/api/query",
    ipnUrl:
      (allowSandboxOverrides ? process.env.MOMO_IPN_URL : undefined) ||
      defaultIpnUrl,
    redirectUrl:
      (allowSandboxOverrides ? process.env.MOMO_REDIRECT_URL : undefined) ||
      defaultSandboxRedirectUrl,
    environment: "sandbox",
  };
}

export interface PackageDefinition {
  id: "bronze" | "silver" | "gold";
  name: string;
  price: number;
  durationDays: number;
  priority: number;
}

export const PACKAGE_DEFINITIONS: Record<string, PackageDefinition> = {
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
