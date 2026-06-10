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
    return { uid: payload.sub };
  } catch {
    throw new HttpError(401, "unauthorized", "Invalid token");
  }
}

async function readSmallJson(request: Request): Promise<any> {
  const clone = request.clone();
  return await clone.json();
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
Target calories: ${context.targetCalories} kcal/day.
Body goal: ${context.bodyGoal}.
Diet type: ${context.foodType}.
Style: ${context.eatingMode} ${context.foodStyleCustomText ? `(${context.foodStyleCustomText})` : ""}.
Meals per day: ${context.mealsPerDay}.

Return ONLY a JSON object containing a "candidates" array of meal blocks. Each block MUST have:
- "title": e.g. "Breakfast"
- "startMinute": integer (minutes from midnight)
- "endMinute": integer (minutes from midnight)
- "repeatDays": array of integers 1-7 (1=Monday)
- "mealCategory": "breakfast", "lunch", "snack", or "dinner"
- "steps": array of strings (the dishes)
- "blockType": "soft_block"
- "candidateType": "block"
- "confidenceScore": 0.95

Schedule meals around these times:
Breakfast: ${context.breakfastMinute}
Lunch: ${context.lunchMinute}
Dinner: ${context.dinnerMinute}
${context.snackMinute ? `Snack: ${context.snackMinute}` : ""}
${context.extraSnackMinute ? `Extra Snack: ${context.extraSnackMinute}` : ""}

For each day (1 to 7), generate the required meals. Vary the dishes slightly by day to match the specified Diet Type and Style.
Output format exactly: { "candidates": [ { "title": "Breakfast", "startMinute": 480, "endMinute": 510, "repeatDays": [1,2,3,4,5,6,7], "mealCategory": "breakfast", "steps": ["Oatmeal", "Apple"], "blockType": "soft_block", "candidateType": "block" } ] }`;
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
  };

  const prompt = buildEatingGeneratePrompt(context);
  const provider = env.AI_PROVIDER || "gemini";
  let text = "";

  if (provider === "gemini") {
    const model = env.AI_MODEL?.trim() || "gemini-2.5-flash";
    const apiKey = requiredEnv(env.GEMINI_API_KEY, "GEMINI_API_KEY");
    const url = `https://generativelanguage.googleapis.com/v1beta/models/${model.replace(/^models\//, "")}:generateContent?key=${apiKey}`;
    
    const res = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [{ role: "user", parts: [{ text: prompt }] }],
        generationConfig: { responseMimeType: "application/json" }
      })
    });
    
    if (!res.ok) throw new HttpError(500, "provider_request_failed", "AI provider request failed.");
    const json = await res.json() as any;
    text = json.candidates?.[0]?.content?.parts?.[0]?.text ?? "[]";
  } else {
    throw new HttpError(400, "ai_disabled", "AI provider is disabled or unsupported.");
  }

  const parsed = parseAiJsonText(text);
  const blocks = Array.isArray(parsed) ? parsed : (parsed as any)?.candidates ?? [];

  return jsonResponse(request, env, { 
    id: `eat-gen-${Date.now()}`,
    uid: user.uid,
    candidates: blocks 
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
