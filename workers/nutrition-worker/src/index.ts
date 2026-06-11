import { createRemoteJWKSet, jwtVerify } from "jose";

type Env = {
  FIREBASE_PROJECT_ID: string;
  AI_PROVIDER?: string;
  AI_MODEL?: string;
  AI_FALLBACK_MODEL?: string;
  GEMINI_API_KEY?: string;
  ALLOWED_ORIGINS?: string;
};

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
    throw new HttpError(413, "payload_too_large", `Payload too large. Max ${maxBytes} bytes.`);
  }
  const clone = request.clone();
  try {
    return await clone.json();
  } catch {
    throw new HttpError(400, "invalid_json", "Invalid JSON body.");
  }
}

function readOptionalString(obj: any, key: string): string | undefined {
  return typeof obj[key] === "string" && obj[key].trim() ? obj[key].trim() : undefined;
}

function parseAiJsonText(text: string): any {
  try {
    const jsonStr = text.replace(/```(?:json)?\n?/g, "").replace(/```/g, "").trim();
    return JSON.parse(jsonStr);
  } catch {
    return null;
  }
}

function buildEatingGeneratePrompt(context: any): string {
  return `You are a nutrition expert generating a weekly meal routine JSON.
User Context:
- Height: ${context.heightCm ? context.heightCm + " cm" : "Unknown"}
- Weight: ${context.weightKg ? context.weightKg + " kg" : "Unknown"}
- Age: ${context.age ?? "Unknown"}
- Gender: ${context.gender ?? "Unknown"}
- BMI: ${context.bmi ?? "Unknown"}
- Estimated BMR: ${context.estimatedBmr ? context.estimatedBmr + " kcal" : "Unknown"}
- Maintenance Calories: ${context.estimatedMaintenanceCalories ? context.estimatedMaintenanceCalories + " kcal" : "Unknown"}
- Target Mode: ${context.targetMode ?? "Unknown"}
- Target Calories: ${context.targetCalories} kcal/day
- Protein Target: ${context.proteinTarget ? context.proteinTarget + " g" : "Unknown"}
- Body goal: ${context.bodyGoal}.
- Diet type: ${context.foodType}.
- Style: ${context.eatingMode} ${context.foodStyleCustomText ? `(${context.foodStyleCustomText})` : ""}.
- Meals per day: ${context.mealsPerDay}.
- Lifestyle: ${context.lifestyle ?? "Unknown"}
- Country: ${context.country ?? "Unknown"}

Return ONLY a JSON object containing a "candidates" array of meal blocks. Each block MUST have:
- "title": e.g. "Breakfast"
- "startMinute": integer (minutes from midnight)
- "endMinute": integer (minutes from midnight)
- "repeatDays": array of integers 1-7 (1=Monday)
- "mealCategory": "breakfast", "lunch", "snack", or "dinner"
- "steps": array of strings containing actual, specific dish names. Do NOT output generic meal names like "Breakfast", "Lunch", "Snack", or "Food" in the steps array. Each steps array MUST contain at least 2 distinct specific dishes (e.g. ["Oatmeal with Almonds", "Fresh Apple Slice"]).
- "blockType": "soft_block"
- "candidateType": "block"
- "confidenceScore": 0.95

You MUST schedule the generated meals EXACTLY at these requested start times (minutes from midnight):
- Breakfast start: ${context.breakfastMinute}
- Lunch start: ${context.lunchMinute}
- Dinner start: ${context.dinnerMinute}
${context.snackMinute ? `- Snack start: ${context.snackMinute}` : ""}
${context.extraSnackMinute ? `- Extra Snack start: ${context.extraSnackMinute}` : ""}

For each day (1 to 7), generate the required meals. Vary the dishes slightly by day to match the specified Diet Type and Style.
Output format exactly: { "candidates": [ { "title": "Breakfast", "startMinute": 480, "endMinute": 510, "repeatDays": [1,2,3,4,5,6,7], "mealCategory": "breakfast", "steps": ["Oatmeal with Almonds", "Fresh Apple Slice"], "blockType": "soft_block", "candidateType": "block" } ] }`;
}

async function handleEatingGenerateRoutine(request: Request, env: Env): Promise<Response> {
  const user = await requireVerifiedFirebaseUser(request, env);
  const body = await readSmallJson(request);

  const context = {
    bodyGoal: readOptionalString(body, "bodyGoal") ?? "maintain",
    eatingMode: readOptionalString(body, "eatingMode") ?? "india",
    foodType: readOptionalString(body, "foodType") ?? "mixed",
    foodStyleCustomText: readOptionalString(body, "foodStyleCustomText"),
    mealsPerDay: typeof body.mealsPerDay === "number" ? body.mealsPerDay : 3,
    targetCalories: typeof body.targetCalories === "number" ? body.targetCalories : 2000,
    estimatedBmr: typeof body.estimatedBmr === "number" ? body.estimatedBmr : undefined,
    breakfastMinute: typeof body.breakfastMinute === "number" ? body.breakfastMinute : 480,
    lunchMinute: typeof body.lunchMinute === "number" ? body.lunchMinute : 780,
    dinnerMinute: typeof body.dinnerMinute === "number" ? body.dinnerMinute : 1230,
    snackMinute: typeof body.snackMinute === "number" ? body.snackMinute : undefined,
    extraSnackMinute: typeof body.extraSnackMinute === "number" ? body.extraSnackMinute : undefined,
    heightCm: typeof body.heightCm === "number" ? body.heightCm : undefined,
    weightKg: typeof body.weightKg === "number" ? body.weightKg : undefined,
    age: typeof body.age === "number" ? body.age : undefined,
    gender: readOptionalString(body, "gender"),
    bmi: typeof body.bmi === "number" ? body.bmi : undefined,
    estimatedMaintenanceCalories: typeof body.estimatedMaintenanceCalories === "number" ? body.estimatedMaintenanceCalories : undefined,
    proteinTarget: typeof body.proteinTarget === "number" ? body.proteinTarget : undefined,
    targetMode: readOptionalString(body, "targetMode"),
    lifestyle: readOptionalString(body, "lifestyle"),
    country: readOptionalString(body, "country"),
  };

  const prompt = buildEatingGeneratePrompt(context);
  const provider = env.AI_PROVIDER || "gemini";
  let text = "";

  if (provider === "gemini") {
    const apiKey = requiredEnv(env.GEMINI_API_KEY, "GEMINI_API_KEY");
    const primaryModel = env.AI_MODEL?.trim() || "gemini-3.5-flash";
    const fallbackModel = env.AI_FALLBACK_MODEL?.trim() || "gemini-2.5-flash";

    const fetchGemini = async (model: string) => {
      const url = `https://generativelanguage.googleapis.com/v1beta/models/${model.replace(/^models\//, "")}:generateContent?key=${apiKey}`;
      const res = await fetch(url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [{ role: "user", parts: [{ text: prompt }] }],
          generationConfig: { responseMimeType: "application/json" }
        })
      });
      if (!res.ok) {
        let errJson: any = {};
        try { errJson = await res.json(); } catch {}
        if (res.status === 401 || res.status === 403) {
          throw new HttpError(res.status, "provider_unauthorized", "Provider unauthorized.");
        }
        if (res.status === 404) {
          throw new HttpError(res.status, "provider_model_not_found", "Provider model not found.");
        }
        if (res.status === 429) {
          throw new HttpError(429, "provider_quota_exceeded", "Provider quota exceeded.");
        }
        if (res.status === 503 || res.status === 502 || res.status === 504) {
          throw new HttpError(503, "provider_high_demand", "Provider is busy or in high demand.");
        }
        if (res.status >= 400 && res.status < 500) {
          throw new HttpError(res.status, "provider_request_failed", "Invalid request sent to provider.");
        }
        throw new Error(`Provider failed with status ${res.status}`);
      }
      let json: any;
      try {
        json = await res.json() as any;
      } catch {
        throw new HttpError(500, "provider_invalid_json", "Provider returned invalid JSON.");
      }
      return json.candidates?.[0]?.content?.parts?.[0]?.text ?? "[]";
    };

    try {
      text = await fetchGemini(primaryModel);
    } catch (err) {
      if (err instanceof HttpError && err.status === 429) {
        throw err; // DO NOT fallback on quota exceeded
      }
      if (fallbackModel && fallbackModel !== primaryModel) {
        console.warn(`[NutritionWorker] Primary model ${primaryModel} failed. Attempting fallback ${fallbackModel}.`);
        try {
          text = await fetchGemini(fallbackModel);
        } catch (fallbackErr) {
          if (fallbackErr instanceof HttpError) throw fallbackErr;
          throw new HttpError(500, "provider_request_failed", "AI provider request failed.");
        }
      } else {
        if (err instanceof HttpError) throw err;
        throw new HttpError(500, "provider_request_failed", "AI provider request failed.");
      }
    }
  } else {
    throw new HttpError(400, "ai_disabled", "AI provider is disabled or unsupported.");
  }

  const parsed = parseAiJsonText(text);
  const blocks = Array.isArray(parsed) ? parsed : (parsed as any)?.candidates ?? [];

  const genericTerms = new Set(["breakfast", "lunch", "snack", "dinner", "food", "meal", "eat", "dish"]);

  const validBlocks = blocks.map((b: any) => {
    if (!Array.isArray(b.steps)) return null;
    const cleanSteps = b.steps
      .map((s: any) => typeof s === "string" ? s.trim() : "")
      .filter((s: string) => {
        if (!s) return false;
        const lower = s.toLowerCase();
        return !genericTerms.has(lower);
      });
    
    if (cleanSteps.length >= 2) {
      return { ...b, steps: cleanSteps };
    } else {
      console.warn(`[NutritionWorker] Dropping invalid candidate ${b.title || "unknown"}. Steps: ${JSON.stringify(b.steps)}`);
      return null;
    }
  }).filter(Boolean);

  if (validBlocks.length === 0) {
    throw new HttpError(500, "provider_empty_candidates", "AI returned no valid meals.");
  }

  return jsonResponse(request, env, { 
    id: `eat-gen-${Date.now()}`,
    uid: user.uid,
    candidates: validBlocks 
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
          service: "nutrition-worker",
          projectId: env.FIREBASE_PROJECT_ID,
          aiProvider: env.AI_PROVIDER,
        });
      }

      if (request.method === "POST" && url.pathname === "/v1/eating/generate-routine") {
        return handleEatingGenerateRoutine(request, env);
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
