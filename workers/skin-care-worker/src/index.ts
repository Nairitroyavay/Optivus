import { createRemoteJWKSet, jwtVerify } from "jose";

type Env = {
  FIREBASE_PROJECT_ID: string;
  AI_PROVIDER?: string;
  AI_MODEL?: string;
  AI_FALLBACK_MODEL?: string;
  GEMINI_API_KEY?: string;
  ALLOWED_ORIGINS?: string;
  UPLOAD_BUCKET: R2Bucket;
};

const ROUTINE_GENERATE_JSON_MAX_BYTES = 64 * 1024;
const IMAGE_MAX_BYTES = 15 * 1024 * 1024;

class HttpError extends Error {
  status: number;
  errorCode: string;
  constructor(status: number, errorCode: string, message: string) {
    super(message);
    this.status = status;
    this.errorCode = errorCode;
  }
}

const firebaseJwks = createRemoteJWKSet(
  new URL("https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com")
);

function corsHeaders(request: Request, env: Env): Headers {
  const headers = new Headers();
  headers.set("Access-Control-Allow-Origin", env.ALLOWED_ORIGINS || "*");
  headers.set("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  headers.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
  headers.set("Access-Control-Max-Age", "86400");
  return headers;
}

function jsonResponse(request: Request, env: Env, body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...Object.fromEntries(corsHeaders(request, env)), "Content-Type": "application/json" },
  });
}

function requiredEnv(value: string | undefined, name: string): string {
  if (!value) throw new HttpError(500, "internal_error", `Missing env var: ${name}`);
  return value;
}

async function requireVerifiedFirebaseUser(request: Request, env: Env): Promise<{ uid: string }> {
  const authHeader = request.headers.get("Authorization") || "";
  const token = authHeader.replace(/^Bearer\s+/i, "").trim();
  if (!token) throw new HttpError(401, "unauthorized", "Missing token");
  const projectId = requiredEnv(env.FIREBASE_PROJECT_ID, "FIREBASE_PROJECT_ID");
  try {
    const { payload } = await jwtVerify(token, firebaseJwks, { issuer: `https://securetoken.google.com/${projectId}`, audience: projectId });
    if (!payload.sub) throw new Error("No uid");
    if (payload.email_verified !== true) {
      throw new HttpError(403, "forbidden", "Email not verified.");
    }
    return { uid: payload.sub };
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError(401, "unauthorized", "Invalid token");
  }
}

async function readSmallJson(request: Request, maxBytes = 8192): Promise<any> {
  const contentLength = parseInt(request.headers.get("content-length") || "0", 10);
  if (contentLength > maxBytes) {
    throw new HttpError(413, "json_payload_too_large", `JSON request payload too large. Max ${maxBytes} bytes.`);
  }
  const text = await request.text();
  const actualBytes = new TextEncoder().encode(text).byteLength;
  if (actualBytes > maxBytes) {
    throw new HttpError(413, "json_payload_too_large", `JSON request payload too large. Max ${maxBytes} bytes.`);
  }
  try {
    return JSON.parse(text);
  } catch {
    throw new HttpError(400, "invalid_json", "Invalid JSON body.");
  }
}

function assertOwnedSkinCareObjectKey(uid: string, key: string): void {
  const normalized = key.replace(/\\/g, "/");
  if (normalized.includes("../") || normalized.includes("..\\")) {
    throw new HttpError(403, "forbidden", "Path traversal detected.");
  }
  const regex = new RegExp(`^users/${uid}/onboarding/skin_care/[a-zA-Z0-9_-]+\\.(jpg|jpeg|png|webp|heic|heif|gif|pdf)$`);
  if (!regex.test(normalized)) {
    throw new HttpError(403, "forbidden", "Unauthorized R2 key access.");
  }
}

function supportedGeminiImageContentType(contentType: string | undefined, objectKey?: string): string {
  const normalized = (contentType || "").split(";")[0].trim().toLowerCase();
  if (normalized === "image/jpeg" || normalized === "image/png" || normalized === "image/webp") {
    return normalized;
  }
  const key = (objectKey || "").split("?")[0].toLowerCase();
  if (!normalized) {
    if (key.endsWith(".jpg") || key.endsWith(".jpeg")) return "image/jpeg";
    if (key.endsWith(".png")) return "image/png";
    if (key.endsWith(".webp")) return "image/webp";
  }
  throw new HttpError(415, "unsupported_content_type", "This photo format is not supported. Please upload JPEG, PNG, or WEBP.");
}

function parseAiJsonText(text: string): any {
  try {
    const jsonStr = text.replace(/```(?:json)?\n?/g, "").replace(/```/g, "").trim();
    return JSON.parse(jsonStr);
  } catch {
    return null;
  }
}

function stringList(value: any): string[] {
  const raw = Array.isArray(value) ? value : typeof value === "string" ? value.split(/[\n,]+/) : [];
  const seen = new Set<string>();
  const result: string[] = [];
  for (const item of raw) {
    const text = typeof item === "string"
      ? item
      : item && typeof item === "object"
        ? String(item.instruction || item.step || item.text || item.name || item.productName || item.product || "")
        : String(item || "");
    const normalized = text.trim().replace(/\s+/g, " ");
    if (!normalized) continue;
    const key = normalized.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    result.push(normalized);
  }
  return result;
}

function repeatDays(value: any): number[] {
  const raw = Array.isArray(value) ? value : [];
  const days = Array.from(new Set(raw
    .map((item) => Number.parseInt(String(item), 10))
    .filter((day) => Number.isInteger(day) && day >= 1 && day <= 7)))
    .sort((a, b) => a - b);
  return days;
}

function normalizeRoutinePlan(plan: any): any | null {
  if (!plan || typeof plan !== "object") return null;
  const steps = stringList(plan.steps || plan.orderedSteps || plan.instructions);
  const productNames = stringList(plan.productNames || plan.products || plan.skincareProducts);
  if (steps.length === 0 && productNames.length === 0) return null;
  const slotLabel = String(plan.slotLabel || plan.slot || plan.timeOfDay || "custom").trim().toLowerCase();
  const title = String(plan.title || plan.name || `${slotLabel || "Custom"} Skin Care`).trim();
  const normalizedTitle = title || `${slotLabel || "Custom"} Skin Care`;
  return {
    slotLabel: slotLabel || "custom",
    title: normalizedTitle,
    steps,
    productNames,
    warnings: stringList(plan.warnings || plan.warningIfAny),
    repeatDays: repeatDays(plan.repeatDays || plan.days),
  };
}

function arrayBufferToBase64(buffer: ArrayBuffer): string {
  let binary = "";
  const bytes = new Uint8Array(buffer);
  const len = bytes.byteLength;
  for (let i = 0; i < len; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary);
}

async function handleProductAnalyze(request: Request, env: Env): Promise<Response> {
  const user = await requireVerifiedFirebaseUser(request, env);
  const body = await readSmallJson(request);

  if (!body.productPhotos || !Array.isArray(body.productPhotos) || body.productPhotos.length === 0) {
    throw new HttpError(400, "invalid_skin_care_request", "Missing product photos.");
  }
  if (body.productPhotos.length > 10) {
    throw new HttpError(400, "too_many_photos", "Upload your main 10 products first. You can add more later.");
  }

  const provider = env.AI_PROVIDER || "gemini";
  if (provider !== "gemini") {
    throw new HttpError(400, "ai_disabled", "AI provider is disabled or unsupported for vision.");
  }

  const apiKey = requiredEnv(env.GEMINI_API_KEY, "GEMINI_API_KEY");
  const primaryModel = env.AI_MODEL?.trim() || "gemini-2.5-flash-lite";
  const fallbackModel = env.AI_FALLBACK_MODEL?.trim() || "gemini-2.5-flash";

  const imageParts: any[] = [];
  
  for (const photoKey of body.productPhotos) {
    if (typeof photoKey !== "string") continue;
    assertOwnedSkinCareObjectKey(user.uid, photoKey);
    const object = await env.UPLOAD_BUCKET.get(photoKey);
    if (!object) {
      throw new HttpError(404, "r2_image_missing", `Could not find uploaded image: ${photoKey}`);
    }
    const contentType = supportedGeminiImageContentType(object.httpMetadata?.contentType, photoKey);
    const buffer = await object.arrayBuffer();
    if (buffer.byteLength > IMAGE_MAX_BYTES) {
      throw new HttpError(413, "image_payload_too_large", `Image ${photoKey} exceeds 15MB limit.`);
    }
    imageParts.push({
      inlineData: {
        mimeType: contentType,
        data: arrayBufferToBase64(buffer)
      }
    });
  }

  if (imageParts.length === 0) {
    throw new HttpError(400, "invalid_skin_care_request", "No valid images could be loaded.");
  }

  const prompt = `You are a dermatology and skin-care expert analyzing user-uploaded product photos. 
Identify the skin care products in the provided images.
Return a JSON object:
{
  "products": [
    {
      "name": "Product Name",
      "brand": "Brand",
      "category": "cleanser | moisturizer | sunscreen | serum | toner | exfoliant | lip balm | face mask | spot treatment | unknown",
      "keyIngredients": ["..."],
      "possibleActives": ["..."],
      "usageHint": "When and how to use it",
      "warningIfAny": "Any conflicts like 'Do not mix with Retinol'",
      "confidence": "high|medium|low"
    }
  ],
  "warnings": []
}`;

  const fetchGemini = async (model: string) => {
    const url = `https://generativelanguage.googleapis.com/v1beta/models/${model.replace(/^models\//, "")}:generateContent?key=${apiKey}`;
    const res = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [{ role: "user", parts: [{ text: prompt }, ...imageParts] }],
        generationConfig: { responseMimeType: "application/json" }
      })
    });
    if (!res.ok) throw new Error(`Provider failed with status ${res.status}`);
    const json = await res.json() as any;
    return json.candidates?.[0]?.content?.parts?.[0]?.text ?? "{}";
  };

  let text = "";
  try {
    text = await fetchGemini(primaryModel);
  } catch (err) {
    if (fallbackModel && fallbackModel !== primaryModel) {
      console.warn(`[SkinCareWorker] Primary model ${primaryModel} failed. Attempting fallback ${fallbackModel}.`);
      try {
        text = await fetchGemini(fallbackModel);
      } catch {
        throw new HttpError(500, "provider_request_failed", "AI provider request failed.");
      }
    } else {
      throw new HttpError(500, "provider_request_failed", "AI provider request failed.");
    }
  }
  
  const parsed = parseAiJsonText(text);
  if (!parsed) {
    throw new HttpError(502, "provider_invalid_json", "AI response could not be read safely. Please try again.");
  }
  
  if (!parsed.products || parsed.products.length === 0) {
    throw new HttpError(400, "no_products_detected", "We couldn't clearly identify any skin care products in the photos.");
  }

  return jsonResponse(request, env, { 
    products: parsed.products,
    warnings: parsed.warnings || []
  });
}

async function handleRoutineGenerate(request: Request, env: Env): Promise<Response> {
  const user = await requireVerifiedFirebaseUser(request, env);
  const body = await readSmallJson(request, ROUTINE_GENERATE_JSON_MAX_BYTES);
  const desiredApplicationsPerDay = Math.min(
    4,
    Math.max(2, Number.parseInt(String(body.desiredApplicationsPerDay || "2"), 10) || 2)
  );

  const imageParts: any[] = [];
  
  if (body.facePhotoR2Key && typeof body.facePhotoR2Key === "string") {
    try {
      assertOwnedSkinCareObjectKey(user.uid, body.facePhotoR2Key);
      const object = await env.UPLOAD_BUCKET.get(body.facePhotoR2Key);
      if (object) {
        const contentType = supportedGeminiImageContentType(object.httpMetadata?.contentType, body.facePhotoR2Key);
        const buffer = await object.arrayBuffer();
        if (buffer.byteLength > IMAGE_MAX_BYTES) {
          throw new HttpError(413, "image_payload_too_large", `Image ${body.facePhotoR2Key} exceeds 15MB limit.`);
        }
        imageParts.push({
          inlineData: {
            mimeType: contentType,
            data: arrayBufferToBase64(buffer)
          }
        });
      }
    } catch (err) {
      if (err instanceof HttpError) throw err;
      console.warn("[SkinCareWorker] Failed to load face photo:", err);
    }
  }

  const prompt = `You are an expert dermatologist. Generate skin-care routine plans. Flutter owns all schedule placement and duration. Do NOT choose final schedule times.
Skin Type: ${body.skinType || "unknown"}
Main Problem: ${body.mainProblem || "none"}
Budget: ${body.budget || "medium"}
Routine Preference: ${body.routinePreference || "balanced"}
Desired Applications Per Day: ${desiredApplicationsPerDay}
Products Owned (from photo): ${JSON.stringify(body.productsFromPhoto || [])}
Photo Product Names (fallback/display only): ${JSON.stringify(body.photoProductNames || [])}
Typed Products: ${JSON.stringify(body.typedProductNames || [])}
For owned products, use the structured photo metadata whenever available. Pay attention to category, keyIngredients, possibleActives, usageHint, warningIfAny, and confidence.
Use product categories and ingredient/active metadata to identify product roles, especially sunscreen. A product may be sunscreen if category is sunscreen, name mentions UV/sun/SPF, ingredients/actives mention UV filters, or warnings/usage imply sun protection.
Use warningIfAny and possibleActives to avoid unsafe conflicts. E.g. avoid Retinol + AHA/BHA in the same routine block, sunscreen in morning when appropriate.
If a face photo is provided, use it to personalize the routine and suggested products.
Return exactly ${desiredApplicationsPerDay} routinePlans unless there is a safety reason not to.
Use slot labels from: morning, midday, afternoon, night, custom.
For 2/day prefer morning + night.
For 3/day prefer morning + midday/afternoon + night.
For 4/day prefer morning + midday + afternoon + night.

Return ONLY a strict JSON object. routinePlans are authoritative. timelineBlocks may be included only for compatibility; Flutter will ignore all start/end times:
{
  "routinePlans": [
    {
      "slotLabel": "morning",
      "title": "Morning Skin Care",
      "steps": ["Face wash", "Vitamin C", "Sunscreen"],
      "productNames": ["Cleanser Name", "Vitamin C Serum Name", "Sunscreen Name"],
      "warnings": [],
      "repeatDays": [1,2,3,4,5,6,7]
    }
  ],
  "morningRoutine": [],
  "nightRoutine": [],
  "weeklyRoutine": [],
  "suggestedProducts": ["Product Name 1", "Product Name 2"],
  "timelineBlocks": [
    {
      "title": "Morning Skin Care",
      "section": "skin_care",
      "startMinute": 0,
      "endMinute": 15,
      "repeatDays": [1,2,3,4,5,6,7],
      "products": ["Cleanser", "Sunscreen"],
      "steps": ["Wash face", "Apply sunscreen"],
      "source": "ai_skin_care_setup"
    }
  ],
  "warnings": []
}`;

  const provider = env.AI_PROVIDER || "gemini";
  let text = "";

  if (provider === "gemini") {
    const apiKey = requiredEnv(env.GEMINI_API_KEY, "GEMINI_API_KEY");
    const primaryModel = env.AI_MODEL?.trim() || "gemini-2.5-flash-lite";
    const fallbackModel = env.AI_FALLBACK_MODEL?.trim() || "gemini-2.5-flash";

    const fetchGemini = async (model: string) => {
      const url = `https://generativelanguage.googleapis.com/v1beta/models/${model.replace(/^models\//, "")}:generateContent?key=${apiKey}`;
      const res = await fetch(url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [{ role: "user", parts: [{ text: prompt }, ...imageParts] }],
          generationConfig: { responseMimeType: "application/json" }
        })
      });
      if (!res.ok) throw new Error(`Provider failed with status ${res.status}`);
      const json = await res.json() as any;
      return json.candidates?.[0]?.content?.parts?.[0]?.text ?? "{}";
    };

    try {
      text = await fetchGemini(primaryModel);
    } catch (err) {
      if (fallbackModel && fallbackModel !== primaryModel) {
        console.warn(`[SkinCareWorker] Primary model ${primaryModel} failed. Attempting fallback ${fallbackModel}.`);
        try {
          text = await fetchGemini(fallbackModel);
        } catch {
          throw new HttpError(500, "provider_request_failed", "AI provider request failed.");
        }
      } else {
        throw new HttpError(500, "provider_request_failed", "AI provider request failed.");
      }
    }
  } else {
    throw new HttpError(400, "ai_disabled", "AI provider is disabled or unsupported.");
  }

  const parsed = parseAiJsonText(text);
  if (!parsed) {
    throw new HttpError(502, "provider_invalid_json", "AI response could not be read safely. Please try again.");
  }
  const rawRoutinePlans = Array.isArray(parsed.routinePlans)
    ? parsed.routinePlans
    : Array.isArray(parsed.plans)
      ? parsed.plans
      : [];
  const routinePlans = rawRoutinePlans
    .map(normalizeRoutinePlan)
    .filter((plan: any) => plan !== null);
  const warnings = stringList(parsed.warnings);
  if (routinePlans.length < desiredApplicationsPerDay) {
    warnings.push("routine_plan_count_mismatch");
  }
  const compatibilityStartForSlot = (slotLabel: string | undefined, index: number): number => {
    const slot = String(slotLabel || "").toLowerCase();
    if (slot === "morning") return 7 * 60;
    if (slot === "midday" || slot === "noon" || slot === "lunch") return 13 * 60;
    if (slot === "afternoon") return 16 * 60;
    if (slot === "night" || slot === "evening" || slot === "bedtime") return 21 * 60;
    return [7 * 60, 13 * 60, 16 * 60, 21 * 60][Math.min(index, 3)];
  };
  const compatibilityTimelineBlocks = routinePlans
    .map((plan: any, index: number) => {
        const startMinute = compatibilityStartForSlot(plan?.slotLabel, index);
        return {
          title: plan?.title || `${plan?.slotLabel || "Custom"} Skin Care`,
          section: "skin_care",
          startMinute,
          endMinute: startMinute + 15,
          repeatDays: Array.isArray(plan?.repeatDays) ? plan.repeatDays : [1, 2, 3, 4, 5, 6, 7],
          products: Array.isArray(plan?.productNames) ? plan.productNames : [],
          steps: Array.isArray(plan?.steps) ? plan.steps : [],
          source: "ai_skin_care_setup",
          id: `skin-care-plan-${index + 1}`
        };
      });
  
  return jsonResponse(request, env, { 
    routinePlans,
    morningRoutine: parsed.morningRoutine || [],
    nightRoutine: parsed.nightRoutine || [],
    weeklyRoutine: parsed.weeklyRoutine || [],
    timelineBlocks: compatibilityTimelineBlocks,
    suggestedProducts: parsed.suggestedProducts || [],
    warnings
  });
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: corsHeaders(request, env) });
    }

    try {
      const url = new URL(request.url);
      
      if (request.method === "GET" && url.pathname === "/health") {
        return jsonResponse(request, env, {
          ok: true,
          service: "skin-care-worker",
          projectId: env.FIREBASE_PROJECT_ID,
          aiProvider: env.AI_PROVIDER,
        });
      }

      if (request.method === "POST" && url.pathname === "/v1/skin-care/products/analyze") {
        return await handleProductAnalyze(request, env);
      }

      if (request.method === "POST" && url.pathname === "/v1/skin-care/routine/generate") {
        return await handleRoutineGenerate(request, env);
      }

      return jsonResponse(request, env, { error: "not_found" }, 404);
    } catch (error) {
      const httpError = error instanceof HttpError ? error : null;
      if (httpError) {
        return jsonResponse(request, env, { error: httpError.errorCode, message: httpError.message }, httpError.status);
      }
      return jsonResponse(request, env, { error: "internal_error", message: "An unexpected error occurred" }, 500);
    }
  }
};
