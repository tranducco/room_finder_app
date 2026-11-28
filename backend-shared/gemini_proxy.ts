/**
 * Shared Gemini AI proxy helpers used by both Firebase Cloud Functions
 * and the standalone Express payment/AI server.
 */

export interface GeminiContentPart {
  role: "user" | "model";
  parts: Array<{ text: string }>;
}

export function normalizeGeminiModel(rawModel?: string): string {
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

export async function getServerGeminiApiKey(
  db: any,
  onWarn?: (err: unknown) => void
): Promise<{
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
    if (onWarn) {
      onWarn(err);
    }
  }
  return { apiKey: "", source: "none" };
}

export async function invokeSingleGeminiModel(params: {
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

export async function callGeminiRestWithFallback(params: {
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
  const candidates = Array.from(
    new Set([
      primary,
      "gemini-flash-lite-latest",
      "gemini-flash-latest",
      "gemini-3.5-flash-lite",
      "gemini-3.8-flash",
      "gemini-2.5-flash-lite",
      "gemini-2.5-flash",
    ])
  );

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
