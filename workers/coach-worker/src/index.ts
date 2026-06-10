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

function parseAiJsonText(text: string): any {
  try {
    const jsonStr = text.replace(/```(?:json)?\n?/g, "").replace(/```/g, "").trim();
    return JSON.parse(jsonStr);
  } catch {
    return null;
  }
}

function buildCoachPrompt(context: any): string {
  return `You are an AI life coach. Be supportive but direct. Do not provide medical, legal, or financial diagnosis. 
Coach Style: ${context.coachStyle || "friendly and encouraging"}.
User Topic: ${context.selectedTopic || "general advice"}.
Message from User: "${context.message}"
User Context: ${context.userContext || "None"}
Recent Session Context: ${context.recentSessionContext || "None"}

Return a strict JSON object with:
- "reply": "your text response"
- "cards": [] (optional array of structured actionable cards, if any)
- "warnings": [] (any warnings if the user asks for inappropriate advice)`;
}

async function handleCoachReply(request: Request, env: Env): Promise<Response> {
  const user = await requireVerifiedFirebaseUser(request, env);
  const body = await readSmallJson(request);

  if (!body.message) {
    throw new HttpError(400, "invalid_coach_request", "Missing message.");
  }

  const prompt = buildCoachPrompt(body);
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
      if (!res.ok) throw new Error(`Provider failed with status ${res.status}`);
      const json = await res.json() as any;
      return json.candidates?.[0]?.content?.parts?.[0]?.text ?? "{}";
    };

    try {
      text = await fetchGemini(primaryModel);
    } catch (err) {
      if (fallbackModel && fallbackModel !== primaryModel) {
        console.warn(`[CoachWorker] Primary model ${primaryModel} failed. Attempting fallback ${fallbackModel}.`);
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

  const parsed = parseAiJsonText(text) || {};
  
  return jsonResponse(request, env, { 
    reply: parsed.reply || "I'm here to help, but I'm having trouble understanding right now.",
    cards: parsed.cards || [],
    warnings: parsed.warnings || []
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
          service: "coach-worker",
          projectId: env.FIREBASE_PROJECT_ID,
          aiProvider: env.AI_PROVIDER,
        });
      }

      if (request.method === "POST" && url.pathname === "/v1/coach/reply") {
        return handleCoachReply(request, env);
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
