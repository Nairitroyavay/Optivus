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

const DEFAULT_AI_MODEL = "gemini-3.8-flash";
const DEFAULT_AI_FALLBACK_MODEL = "gemini-3.7-flash";
const WORKER_VERSION = "0.2.0";

function corsHeaders(request: Request, env: Env, requestId?: string): Headers {
  const headers = new Headers();
  const origin = request.headers.get("Origin");
  const allowedOrigins = (env.ALLOWED_ORIGINS ?? "")
    .split(",")
    .map((item) => item.trim())
    .filter((item) => item !== "");
  if (
    origin &&
    (allowedOrigins.includes(origin) || allowedOrigins.includes("*"))
  ) {
    headers.set("Access-Control-Allow-Origin", origin);
    headers.set("Vary", "Origin");
  }
  headers.set("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  headers.set("Access-Control-Allow-Headers", "Content-Type, Authorization, x-request-id");
  headers.set("Access-Control-Max-Age", "86400");
  if (requestId) {
    headers.set("x-request-id", requestId);
  }
  return headers;
}

function jsonResponse(request: Request, env: Env, body: unknown, status = 200, requestId?: string): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...Object.fromEntries(corsHeaders(request, env, requestId)), "Content-Type": "application/json" },
  });
}

function requiredEnv(value: string | undefined, name: string): string {
  if (!value) throw new HttpError(500, "internal_error", `Missing env var: ${name}`);
  return value;
}

async function requireVerifiedFirebaseUser(request: Request, env: Env): Promise<{ uid: string }> {
  const authHeader = request.headers.get("Authorization") || "";
  const token = authHeader.match(/^Bearer\s+(.+)$/i)?.[1]?.trim();
  if (!token) throw new HttpError(401, "unauthorized", "Missing or malformed token");
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
  const text = await request.text();
  if (new TextEncoder().encode(text).byteLength > maxBytes) {
    throw new HttpError(413, "payload_too_large", `Payload too large. Max ${maxBytes} bytes.`);
  }
  let parsed: unknown;
  try {
    parsed = JSON.parse(text);
  } catch {
    throw new HttpError(400, "invalid_json", "Invalid JSON body.");
  }
  if (parsed === null || typeof parsed !== "object" || Array.isArray(parsed)) {
    throw new HttpError(400, "invalid_json", "Expected a JSON object.");
  }
  return parsed;
}

function readOptionalString(obj: any, key: string): string | undefined {
  return typeof obj[key] === "string" && obj[key].trim() ? obj[key].trim() : undefined;
}

function readRequiredString(obj: any, key: string): string {
  const value = readOptionalString(obj, key);
  if (!value) {
    throw new HttpError(400, "invalid_eating_request", `Missing ${key}.`);
  }
  return value;
}

function readRequiredNumber(obj: any, key: string): number {
  const value = obj[key];
  if (typeof value !== "number" || !Number.isFinite(value)) {
    throw new HttpError(400, "invalid_eating_request", `Missing ${key}.`);
  }
  return value;
}

function parseAiJsonText(text: string): any {
  try {
    const jsonStr = text.replace(/```(?:json)?\n?/g, "").replace(/```/g, "").trim();
    return JSON.parse(jsonStr);
  } catch {
    return null;
  }
}

export type MealSlot = {
  slot: string;
  category: "breakfast" | "lunch" | "snack" | "dinner";
  title: string;
  startMinute: number;
  durationMinutes: number;
};

export function expectedMealSlots(context: any): MealSlot[] {
  const slots: MealSlot[] = [
    {
      slot: "breakfast",
      category: "breakfast",
      title: "Breakfast",
      startMinute: context.breakfastMinute,
      durationMinutes: 30,
    },
  ];
  if (context.mealsPerDay === 5) {
    slots.push({
      slot: "morning_snack",
      category: "snack",
      title: "Morning Snack",
      startMinute: context.extraSnackMinute ?? 11 * 60,
      durationMinutes: 20,
    });
  }
  slots.push({
    slot: "lunch",
    category: "lunch",
    title: "Lunch",
    startMinute: context.lunchMinute,
    durationMinutes: 45,
  });
  if (context.mealsPerDay >= 4) {
    slots.push({
      slot: "afternoon_snack",
      category: "snack",
      title: "Snack",
      startMinute: context.snackMinute ?? 17 * 60,
      durationMinutes: 20,
    });
  }
  slots.push({
    slot: "dinner",
    category: "dinner",
    title: "Dinner",
    startMinute: context.dinnerMinute,
    durationMinutes: 45,
  });
  return slots;
}

export function buildResponseSchema(slots: MealSlot[]): Record<string, unknown> {
  return {
    type: "OBJECT",
    properties: {
      candidates: {
        type: "ARRAY",
        items: {
          type: "OBJECT",
          properties: {
            day: { type: "INTEGER" },
            mealSlot: {
              type: "STRING",
              enum: slots.map((s) => s.slot),
            },
            items: {
              type: "ARRAY",
              items: {
                type: "OBJECT",
                properties: {
                  name: { type: "STRING" },
                  quantity: { type: "NUMBER" },
                  unit: {
                    type: "STRING",
                    enum: [
                      "g",
                      "ml",
                      "piece",
                      "pieces",
                      "slice",
                      "slices",
                      "cup",
                      "cups",
                      "bowl",
                      "bowls",
                      "tbsp",
                      "tsp",
                      "serving",
                      "servings",
                    ],
                  },
                  caloriesEstimate: { type: "INTEGER" },
                  proteinEstimate: { type: "INTEGER" },
                },
                required: [
                  "name",
                  "quantity",
                  "unit",
                  "caloriesEstimate",
                  "proteinEstimate",
                ],
              },
            },
          },
          required: ["day", "mealSlot", "items"],
        },
      },
    },
    required: ["candidates"],
  };
}

export function buildEatingGeneratePrompt(context: any): string {
  const slots = expectedMealSlots(context);
  const slotLines = slots
    .map((slot) => `- ${slot.slot}: title "${slot.title}", mealCategory "${slot.category}", startMinute ${slot.startMinute}, duration ${slot.durationMinutes} min`)
    .join("\n");
  const totalMeals = 7 * slots.length;

  return `You are an expert clinical dietitian generating a personalized, highly diverse, 7-day meal routine JSON.
User Context:
- Height: ${context.heightCm ? context.heightCm + " cm" : "Unknown"}
- Weight: ${context.weightKg ? context.weightKg + " kg" : "Unknown"}
- Age: ${context.age ?? "Unknown"}
- Gender: ${context.gender ?? "Unknown"}
- BMI: ${context.bmi ?? "Unknown"}
- Estimated BMR: ${context.estimatedBmr ? context.estimatedBmr + " kcal" : "Unknown"}
- Maintenance Calories: ${context.estimatedMaintenanceCalories ? context.estimatedMaintenanceCalories + " kcal" : "Unknown"}
- Target Mode: ${context.targetMode ?? "Unknown"}
- Daily Target Calories: ${context.targetCalories} kcal/day
- Daily Protein Target: ${context.proteinTarget ? context.proteinTarget + " g" : "Unknown"}
- Body Goal: ${context.bodyGoal}.
- Diet Type: ${context.foodType}.
- Style: ${context.eatingMode} ${context.foodStyleCustomText ? `(${context.foodStyleCustomText})` : ""}.
- Meals Per Day: ${context.mealsPerDay}.
- Exercise Level: ${context.exerciseLevel ?? "Unknown"}
- Life Role: ${context.lifeRole ?? context.lifestyle ?? "Unknown"}
- Country / Region: ${context.country ?? "Unknown"}
${context.foodsToAvoid ? `- Foods to Avoid: ${context.foodsToAvoid}\n` : ""}
Meal Slots Per Day (${slots.length} slots):
${slotLines}

Generation Requirements:
1. You MUST generate meals for ALL 7 DAYS of the week (day 1=Monday, day 2=Tuesday, day 3=Wednesday, day 4=Thursday, day 5=Friday, day 6=Saturday, day 7=Sunday).
2. For EACH day (1 to 7), you MUST provide every required meal slot listed above. Exactly ${totalMeals} meal objects total (${slots.length} meals × 7 days).
3. ALL 7 days must have distinct complete daily menus. For each meal slot, the dish combination must differ from that same meal slot on every other day.
4. Each meal block MUST contain:
   - "day": integer from 1 to 7 (1=Monday .. 7=Sunday)
   - "mealSlot": one of exactly ${slots.map((s) => `"${s.slot}"`).join(", ")}
   - "items": array of at least 2 distinct food items making up the meal. Each item must specify:
     - "name": specific food or dish name (e.g. "Steel Cut Oats", "Almond Butter", "Greek Yogurt", "Blueberries"). Do NOT use generic terms like "Food" or "Meal".
     - "quantity": positive numeric portion size (e.g. 80, 2, 1.5).
     - "unit": realistic unit ("g", "ml", "piece", "slice", "cup", "bowl", "tbsp", "tsp", "serving").
     - "caloriesEstimate": realistic estimated integer calories for this item portion.
     - "proteinEstimate": realistic estimated integer grams of protein for this item portion.
5. Dietary Rule Compliance:
   - Strictly adhere to Diet Type: ${context.foodType}.
   ${context.foodType === 'vegetarian' ? '   - Vegetarian: NO meat, poultry, fish, seafood, or eggs.' : ''}
   ${context.foodType === 'eggetarian' ? '   - Eggetarian: Eggs and dairy are allowed. NO meat, poultry, fish, or seafood.' : ''}
   ${context.foodType === 'vegan' ? '   - Vegan: 100% plant-based. NO meat, poultry, fish, seafood, eggs, dairy (milk, paneer, curd, cheese, butter, ghee), or honey.' : ''}
   ${context.foodsToAvoid ? `   - Strictly avoid: ${context.foodsToAvoid}.` : ''}
6. Daily Nutrition Target Invariant:
   - For every single day, the sum of all item calories across all meals of that day MUST be within ±15% of the Daily Target Calories (${context.targetCalories} kcal).
   ${context.proteinTarget ? `- For every single day, the sum of all item protein across all meals of that day MUST be within ±20% of the Daily Protein Target (${context.proteinTarget} g).` : ""}

Output ONLY valid JSON according to the schema.`;
}

export interface DietaryViolation {
  item: string;
  reason: string;
}

function escapeRegExp(string: string): string {
  return string.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

export function checkDietaryCompliance(
  itemName: string,
  foodType: string,
  foodsToAvoid?: string | string[],
): DietaryViolation | null {
  const norm = itemName.trim().toLowerCase();
  const cleanType = foodType.trim().toLowerCase();

  // 1. User-specified avoidance constraints
  if (foodsToAvoid) {
    const avoidList = Array.isArray(foodsToAvoid)
      ? foodsToAvoid
      : foodsToAvoid.split(/[,;\n]+/).map((s) => s.trim()).filter(Boolean);
    for (const avoid of avoidList) {
      const avoidNorm = avoid.toLowerCase();
      if (avoidNorm.length >= 2) {
        const singular = avoidNorm.endsWith('s') && !avoidNorm.endsWith('ss')
          ? avoidNorm.slice(0, -1)
          : avoidNorm;
        const pattern = singular !== avoidNorm
          ? `\\b(${escapeRegExp(avoidNorm)}|${escapeRegExp(singular)})\\b`
          : `\\b${escapeRegExp(avoidNorm)}\\b`;
        if (new RegExp(pattern, 'i').test(norm)) {
          return { item: itemName, reason: `Contains avoided ingredient "${avoid}"` };
        }
      }
    }
  }

  // 2. Mixed / Non-vegetarian has no restrictions
  if (cleanType === "mixed" || cleanType === "non_vegetarian" || cleanType === "non-vegetarian") {
    return null;
  }

  const meatSeafoodTokens = [
    "chicken", "mutton", "lamb", "beef", "pork", "turkey", "duck", "bacon", "ham",
    "sausage", "salami", "pepperoni", "veal", "venison", "meat", "steak", "prosciutto",
    "fish", "salmon", "tuna", "trout", "cod", "tilapia", "mackerel", "sardine",
    "anchovy", "bass", "halibut", "snapper", "catfish", "haddock",
    "shrimp", "prawn", "prawns", "crab", "lobster", "oyster", "oysters", "clam", "clams",
    "mussel", "mussels", "squid", "calamari", "octopus", "scallop", "scallops", "seafood",
    "gelatin", "lard"
  ];

  const eggTokens = [
    "egg", "eggs", "egg white", "egg whites", "egg yolk", "omelet", "omelette",
    "frittata", "scrambled egg", "boiled egg", "poached egg"
  ];

  const dairyTokens = [
    "milk", "cheese", "butter", "ghee", "yogurt", "curd", "paneer", "cream", "whey", "casein"
  ];

  const hasToken = (token: string): boolean => {
    // False-positive guards:
    if (token === "egg" || token === "eggs") {
      if (norm.includes("eggplant")) return false;
    }
    if (token === "chicken") {
      if (norm.includes("chickpea") || norm.includes("chick pea")) return false;
    }
    if (token === "meat") {
      if (norm.includes("sweetmeats") || norm.includes("plant meat") || norm.includes("vegan meat")) return false;
    }
    return new RegExp(`\\b${escapeRegExp(token)}\\b`, 'i').test(norm);
  };

  if (cleanType === "vegetarian" || cleanType === "eggetarian" || cleanType === "vegan") {
    for (const token of meatSeafoodTokens) {
      if (hasToken(token)) {
        return { item: itemName, reason: `Contains meat/seafood "${token}" which violates ${cleanType} diet rules` };
      }
    }
  }

  if (cleanType === "vegetarian") {
    for (const token of eggTokens) {
      if (hasToken(token)) {
        return { item: itemName, reason: `Contains egg ("${token}") which violates vegetarian diet rules (choose eggetarian to include eggs)` };
      }
    }
  }

  if (cleanType === "vegan") {
    for (const token of eggTokens) {
      if (hasToken(token)) {
        return { item: itemName, reason: `Contains egg ("${token}") which violates vegan diet rules` };
      }
    }
    for (const token of dairyTokens) {
      const isPlantBased = /\b(almond|soy|oat|coconut|cashew|plant|vegan|dairy-free)\b/i.test(norm);
      if (!isPlantBased && hasToken(token)) {
        if (token === "butter" && /\b(peanut|almond|cashew|apple|cocoa|shea|sunflower)\s+butter\b/i.test(norm)) {
          continue;
        }
        return { item: itemName, reason: `Contains dairy "${token}" which violates vegan diet rules` };
      }
    }
    if (hasToken("honey")) {
      return { item: itemName, reason: `Contains honey which violates vegan diet rules` };
    }
  }

  return null;
}

async function handleEatingGenerateRoutine(request: Request, env: Env, requestId: string): Promise<Response> {
  const user = await requireVerifiedFirebaseUser(request, env);
  const body = await readSmallJson(request);
  const mealTimes = (body.mealTimes && typeof body.mealTimes === "object") ? body.mealTimes as Record<string, unknown> : undefined;

  const context = {
    bodyGoal: readRequiredString(body, "bodyGoal"),
    eatingMode: readRequiredString(body, "eatingMode"),
    foodType: readRequiredString(body, "foodType"),
    foodStyleCustomText: readOptionalString(body, "foodStyleCustomText"),
    mealsPerDay: readRequiredNumber(body, "mealsPerDay"),
    targetCalories: readRequiredNumber(body, "targetCalories"),
    estimatedBmr: typeof body.estimatedBmr === "number" ? body.estimatedBmr : undefined,
    breakfastMinute: typeof body.breakfastMinute === "number"
      ? body.breakfastMinute
      : (typeof mealTimes?.breakfast === "number" ? mealTimes.breakfast : 480),
    lunchMinute: typeof body.lunchMinute === "number"
      ? body.lunchMinute
      : (typeof mealTimes?.lunch === "number" ? mealTimes.lunch : 780),
    dinnerMinute: typeof body.dinnerMinute === "number"
      ? body.dinnerMinute
      : (typeof mealTimes?.dinner === "number" ? mealTimes.dinner : 1230),
    snackMinute: typeof body.snackMinute === "number"
      ? body.snackMinute
      : (typeof mealTimes?.afternoon_snack === "number" ? mealTimes.afternoon_snack : undefined),
    extraSnackMinute: typeof body.extraSnackMinute === "number"
      ? body.extraSnackMinute
      : (typeof mealTimes?.morning_snack === "number" ? mealTimes.morning_snack : undefined),
    heightCm: typeof body.heightCm === "number" ? body.heightCm : undefined,
    weightKg: typeof body.weightKg === "number" ? body.weightKg : undefined,
    age: typeof body.age === "number" ? body.age : undefined,
    gender: readOptionalString(body, "gender"),
    bmi: typeof body.bmi === "number" ? body.bmi : undefined,
    estimatedMaintenanceCalories: typeof body.estimatedMaintenanceCalories === "number" ? body.estimatedMaintenanceCalories : undefined,
    proteinTarget: typeof body.proteinTarget === "number" ? body.proteinTarget : undefined,
    targetMode: readOptionalString(body, "targetMode"),
    exerciseLevel: readOptionalString(body, "exerciseLevel"),
    lifeRole: readOptionalString(body, "lifeRole"),
    lifestyle: readOptionalString(body, "lifestyle"),
    country: readOptionalString(body, "country"),
    foodsToAvoid: readOptionalString(body, "foodsToAvoid") ?? (Array.isArray(body.foodsToAvoid) ? body.foodsToAvoid.join(", ") : undefined),
  };

  if (!Number.isInteger(context.mealsPerDay) || context.mealsPerDay < 3 || context.mealsPerDay > 5) {
    throw new HttpError(400, "invalid_eating_request", "mealsPerDay must be 3, 4, or 5.");
  }
  if (context.targetCalories <= 0 || !Number.isFinite(context.targetCalories)) {
    throw new HttpError(400, "invalid_eating_request", "targetCalories must be positive and finite.");
  }
  if (context.proteinTarget !== undefined && (!Number.isFinite(context.proteinTarget) || context.proteinTarget <= 0)) {
    throw new HttpError(400, "invalid_eating_request", "proteinTarget must be positive and finite.");
  }

  const MAX_GENERATION_ATTEMPTS = 2;
  const genericTerms = new Set(["breakfast", "lunch", "snack", "dinner", "food", "meal", "eat", "dish"]);
  const slots = expectedMealSlots(context);
  const provider = env.AI_PROVIDER || "gemini";

  let attempt = 1;
  let currentPrompt = buildEatingGeneratePrompt(context);
  let lastValidation: ValidationResult | null = null;
  let candidateBlocks: Record<string, unknown>[] = [];

  while (attempt <= MAX_GENERATION_ATTEMPTS) {
    let text = "";
    const startTime = Date.now();
    let usedModel = "";
    let fallbackUsed = false;

    if (provider === "gemini") {
      const apiKey = requiredEnv(env.GEMINI_API_KEY, "GEMINI_API_KEY");
      const primaryModel = env.AI_MODEL?.trim() || DEFAULT_AI_MODEL;
      const fallbackModel = env.AI_FALLBACK_MODEL?.trim() || DEFAULT_AI_FALLBACK_MODEL;
      const thinkingLevel = attempt === 1 ? "medium" : "high";

      const fetchGemini = async (model: string) => {
        usedModel = model;
        const url = `https://generativelanguage.googleapis.com/v1beta/models/${model.replace(/^models\//, "")}:generateContent?key=${apiKey}`;
        const res = await fetch(url, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            contents: [{ role: "user", parts: [{ text: currentPrompt }] }],
            generationConfig: {
              responseMimeType: "application/json",
              responseSchema: buildResponseSchema(slots),
              thinkingConfig: { thinkingLevel },
            },
          }),
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
          console.warn(`[NutritionWorker] [${requestId}] Primary model ${primaryModel} failed. Attempting fallback ${fallbackModel}.`);
          fallbackUsed = true;
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

    const validBlocks = blocks
      .map((block: unknown) => sanitizeMealCandidate(block, genericTerms, slots))
      .filter((block: Record<string, unknown> | null): block is Record<string, unknown> => block !== null);

    const validation = validateWeeklyCandidates(validBlocks, slots, context);
    const latencyMs = Date.now() - startTime;

    if (validation.ok) {
      candidateBlocks = validation.blocks;
      console.log(JSON.stringify({
        service: "nutrition-worker",
        requestId,
        model: usedModel,
        fallbackUsed,
        semanticAttempt: attempt,
        candidateCount: candidateBlocks.length,
        latencyMs,
        success: true,
      }));
      break;
    }

    lastValidation = validation;
    console.warn(JSON.stringify({
      service: "nutrition-worker",
      requestId,
      model: usedModel,
      fallbackUsed,
      semanticAttempt: attempt,
      errorCode: validation.errorCode,
      message: validation.message,
      latencyMs,
      success: false,
    }));

    attempt++;
    if (attempt <= MAX_GENERATION_ATTEMPTS) {
      currentPrompt = buildEatingRepairPrompt(context, validation.repairFeedback);
    }
  }

  if (candidateBlocks.length === 0) {
    if (lastValidation && !lastValidation.ok) {
      throw new HttpError(500, lastValidation.errorCode, lastValidation.message);
    }
    throw new HttpError(500, "provider_empty_candidates", "AI returned no valid meals.");
  }

  return jsonResponse(request, env, { 
    id: `eat-gen-${Date.now()}`,
    requestId,
    uid: user.uid,
    candidates: candidateBlocks
  }, 200, requestId);
}

export type ValidationResult =
  | { ok: true; blocks: Record<string, unknown>[] }
  | { ok: false; errorCode: string; message: string; repairFeedback: string };

export function validateWeeklyCandidates(
  validBlocks: Record<string, unknown>[],
  slots: MealSlot[],
  context: any,
): ValidationResult {
  if (validBlocks.length === 0) {
    return {
      ok: false,
      errorCode: "provider_empty_candidates",
      message: "AI returned no valid meals.",
      repairFeedback: "Return a valid JSON array of meal candidates matching all requested days and meal slots.",
    };
  }

  const byDayAndSlot = new Map<string, Record<string, unknown>>();
  const expectedSlotIds = new Set(slots.map((slot) => slot.slot));
  for (const block of validBlocks) {
    const slot = String(block.mealSlot || "");
    const day = Number(block.day);
    if (!expectedSlotIds.has(slot)) {
      return {
        ok: false,
        errorCode: "provider_unexpected_meal_slot",
        message: `AI returned an unexpected meal slot "${slot}".`,
        repairFeedback: `Only output meals with "mealSlot" matching one of: ${slots.map((s) => `"${s.slot}"`).join(", ")}.`,
      };
    }
    const key = `${day}_${slot}`;
    if (byDayAndSlot.has(key)) {
      return {
        ok: false,
        errorCode: "provider_duplicate_meal_slot",
        message: `AI returned a duplicate meal slot for day ${day}.`,
        repairFeedback: `Ensure each day (1 to 7) has exactly one "${slot}". Do not duplicate meal slots for the same day.`,
      };
    }
    byDayAndSlot.set(key, block);
  }

  for (let day = 1; day <= 7; day++) {
    for (const slot of slots) {
      if (!byDayAndSlot.has(`${day}_${slot.slot}`)) {
        return {
          ok: false,
          errorCode: "provider_incomplete_week",
          message: `AI missed required meal slot "${slot.slot}" on day ${day}.`,
          repairFeedback: `Your previous response was missing required (day, mealSlot) entries, such as day ${day} slot "${slot.slot}". You MUST return meals for all 7 days with all ${slots.length} slots every day (exactly ${7 * slots.length} meal blocks total).`,
        };
      }
    }
  }

  // Dietary and avoidance validation
  for (const block of validBlocks) {
    const dishes = Array.isArray(block.steps) ? (block.steps as string[]) : [];
    for (const dish of dishes) {
      const cleanName = dish.split(/[—–-]/)[0].trim();
      const violation = checkDietaryCompliance(cleanName, context.foodType, context.foodsToAvoid);
      if (violation) {
        return {
          ok: false,
          errorCode: "provider_diet_violation",
          message: `AI generated meal violating ${context.foodType} diet: ${violation.reason} in "${violation.item}".`,
          repairFeedback: `Diet violation detected: "${violation.item}" (${violation.reason}). Strictly follow ${context.foodType} diet rules! Do NOT include any prohibited foods${context.foodsToAvoid ? ` and strictly avoid: ${context.foodsToAvoid}` : ''}. Replace this with a compliant option.`,
        };
      }
    }
  }

  // Nutrition targets validation per day (±15% calories, ±20% protein)
  const targetCalories = context.targetCalories;
  const proteinTarget = context.proteinTarget;
  for (let day = 1; day <= 7; day++) {
    let dayCalories = 0;
    let dayProtein = 0;
    for (const slot of slots) {
      const b = byDayAndSlot.get(`${day}_${slot.slot}`)!;
      dayCalories += Number(b.caloriesEstimate ?? 0);
      dayProtein += Number(b.proteinEstimate ?? 0);
    }
    if (targetCalories > 0) {
      const calMin = targetCalories * 0.85;
      const calMax = targetCalories * 1.15;
      if (dayCalories < calMin || dayCalories > calMax) {
        return {
          ok: false,
          errorCode: "provider_target_mismatch",
          message: `Generated calories on day ${day} (${dayCalories}) deviated from target (${targetCalories}).`,
          repairFeedback: `Daily calorie totals deviated outside ±15%: on day ${day}, calorie sum was ${dayCalories} kcal (target is ${targetCalories} kcal, allowed range: ${Math.round(calMin)}-${Math.round(calMax)} kcal). Recalculate meal estimates so every day's total calories falls within ±15% of ${targetCalories} kcal.`,
        };
      }
    }
    if (proteinTarget && proteinTarget > 0) {
      const pMin = proteinTarget * 0.80;
      const pMax = proteinTarget * 1.20;
      if (dayProtein < pMin || dayProtein > pMax) {
        return {
          ok: false,
          errorCode: "provider_target_mismatch",
          message: `Generated protein on day ${day} (${dayProtein}g) deviated from target (${proteinTarget}g).`,
          repairFeedback: `Daily protein totals deviated outside ±20%: on day ${day}, protein sum was ${dayProtein}g (target is ${proteinTarget}g, allowed range: ${Math.round(pMin)}-${Math.round(pMax)}g). Recalculate meal estimates so every day's total protein falls within ±20% of ${proteinTarget}g.`,
        };
      }
    }
  }

  // Weekly diversity validation: 7 distinct complete daily menus
  const dailySignatures = new Set<string>();
  for (let day = 1; day <= 7; day++) {
    const dayMenuSignature = slots.map((s) => {
      const b = byDayAndSlot.get(`${day}_${s.slot}`)!;
      return `${s.slot}:${mealSignature(b.steps as string[])}`;
    }).join("::");
    dailySignatures.add(dayMenuSignature);
  }
  if (dailySignatures.size !== 7) {
    return {
      ok: false,
      errorCode: "provider_insufficient_diversity",
      message: "AI generated repetitive meals across days without 7 unique daily menus.",
      repairFeedback: "Daily menus across days were repetitive. Ensure that every day has a completely distinct combination of meals across all slots.",
    };
  }

  // Same-slot diversity across days: all 7 days must have distinct full dish-set signatures for each mealSlot
  for (const slot of slots) {
    const slotSignatures = new Set<string>();
    for (let day = 1; day <= 7; day++) {
      const b = byDayAndSlot.get(`${day}_${slot.slot}`)!;
      slotSignatures.add(mealSignature(b.steps as string[]));
    }
    if (slotSignatures.size !== 7) {
      return {
        ok: false,
        errorCode: "provider_insufficient_diversity",
        message: `AI repeated dish combinations for meal slot "${slot.slot}" across the week.`,
        repairFeedback: `Dishes for meal slot "${slot.slot}" were repeated across days. Every single day must have a distinct combination of dishes for "${slot.slot}".`,
      };
    }
  }

  const orderedBlocks: Record<string, unknown>[] = [];
  for (let day = 1; day <= 7; day++) {
    for (const slot of slots) {
      orderedBlocks.push(byDayAndSlot.get(`${day}_${slot.slot}`)!);
    }
  }

  return { ok: true, blocks: orderedBlocks };
}

export function buildEatingRepairPrompt(
  context: any,
  repairFeedback: string,
): string {
  const basePrompt = buildEatingGeneratePrompt(context);
  return `${basePrompt}

CRITICAL REPAIR INSTRUCTIONS:
Your previous attempt failed validation with the following error:
${repairFeedback}

Please fix this issue completely in your revised JSON response.
Ensure:
1. Exactly 7 days × required slots are present.
2. Every day's calories are strictly within ±15% of ${context.targetCalories} kcal.${context.proteinTarget ? `\n3. Every day's protein is strictly within ±20% of ${context.proteinTarget} g.` : ""}
4. All dish combinations are 100% unique per slot across days.
5. Strictly adhere to ${context.foodType} diet rules and all avoidance constraints.
Output ONLY the corrected JSON.`;
}

function normalizeDish(d: string): string {
  return d.trim().toLowerCase().replace(/\s+/g, " ");
}

function mealSignature(dishes: string[]): string {
  return dishes
    .map(normalizeDish)
    .filter((d) => d.length > 0)
    .sort()
    .join("|");
}

function sanitizeMealCandidate(
  value: unknown,
  genericTerms: Set<string>,
  expectedSlots: MealSlot[],
): Record<string, unknown> | null {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    return null;
  }
  const block = value as Record<string, unknown>;
  const title = typeof block.title === "string" ? block.title.trim() : "";
  const mealCategory = typeof block.mealCategory === "string"
    ? block.mealCategory.trim().toLowerCase()
    : "";
  const rawMealSlot = typeof block.mealSlot === "string"
    ? block.mealSlot.trim().toLowerCase().replace(/-/g, "_")
    : "";

  let day: number | null = null;
  if (typeof block.day === "number" && Number.isInteger(block.day) && block.day >= 1 && block.day <= 7) {
    day = block.day;
  } else if (Array.isArray(block.repeatDays) && block.repeatDays.length > 0) {
    const firstDay = block.repeatDays[0];
    if (typeof firstDay === "number" && Number.isInteger(firstDay) && firstDay >= 1 && firstDay <= 7) {
      day = firstDay;
    }
  }

  if (day === null) {
    console.warn("[NutritionWorker] Dropping meal candidate without valid day (1-7).");
    return null;
  }

  const inferredSlot = inferMealSlot(rawMealSlot || mealCategory || title, block.startMinute, expectedSlots);
  if (!inferredSlot) {
    console.warn("[NutritionWorker] Dropping meal candidate without stable slot identity.");
    return null;
  }

  // Check items array first (Structured Output Contract)
  let cleanSteps: string[] = [];
  let caloriesEstimate: number | null = null;
  let proteinEstimate: number | null = null;
  const rawItems: Record<string, unknown>[] = [];

  if (Array.isArray(block.items) && block.items.length > 0) {
    let sumCal = 0;
    let sumProt = 0;
    for (const rawItem of block.items) {
      if (!rawItem || typeof rawItem !== "object") continue;
      const item = rawItem as Record<string, unknown>;
      const name = typeof item.name === "string" ? item.name.trim() : "";
      const quantity = typeof item.quantity === "number" && Number.isFinite(item.quantity) && item.quantity > 0
        ? item.quantity
        : null;
      const unit = typeof item.unit === "string" && item.unit.trim() ? item.unit.trim() : "";
      const itemCal = typeof item.caloriesEstimate === "number" && Number.isFinite(item.caloriesEstimate) && item.caloriesEstimate >= 0
        ? Math.round(item.caloriesEstimate)
        : null;
      const itemProt = typeof item.proteinEstimate === "number" && Number.isFinite(item.proteinEstimate) && item.proteinEstimate >= 0
        ? Math.round(item.proteinEstimate)
        : null;

      if (!name || genericTerms.has(name.toLowerCase()) || quantity === null || !unit || itemCal === null || itemProt === null) {
        continue;
      }
      cleanSteps.push(`${name} — ${quantity} ${unit}`);
      sumCal += itemCal;
      sumProt += itemProt;
      rawItems.push({
        name,
        quantity,
        unit,
        caloriesEstimate: itemCal,
        proteinEstimate: itemProt,
      });
    }
    if (cleanSteps.length >= 2 && sumCal > 0 && sumProt > 0) {
      caloriesEstimate = sumCal;
      proteinEstimate = sumProt;
    }
  }

  // Fallback if steps were provided directly (legacy / mock mode)
  if (cleanSteps.length === 0 && Array.isArray(block.steps)) {
    cleanSteps = block.steps
      .map((step) => typeof step === "string" ? step.trim() : "")
      .filter((step) => step !== "" && !genericTerms.has(step.toLowerCase()))
      .slice(0, 12);

    if (typeof block.caloriesEstimate === "number" && Number.isFinite(block.caloriesEstimate) && block.caloriesEstimate > 0) {
      caloriesEstimate = Math.round(block.caloriesEstimate);
    } else if (typeof block.calories === "number" && Number.isFinite(block.calories) && block.calories > 0) {
      caloriesEstimate = Math.round(block.calories);
    }

    if (typeof block.proteinEstimate === "number" && Number.isFinite(block.proteinEstimate) && block.proteinEstimate > 0) {
      proteinEstimate = Math.round(block.proteinEstimate);
    } else if (typeof block.protein === "number" && Number.isFinite(block.protein) && block.protein > 0) {
      proteinEstimate = Math.round(block.protein);
    }
  }

  if (cleanSteps.length < 2 || caloriesEstimate === null || proteinEstimate === null) {
    console.warn("[NutritionWorker] Dropping invalid candidate (insufficient steps or invalid estimates).");
    return null;
  }

  const confidence = typeof block.confidenceScore === "number" &&
      Number.isFinite(block.confidenceScore)
    ? Math.max(0, Math.min(1, block.confidenceScore))
    : 0.95;

  return {
    id: `meal_${inferredSlot.slot}_d${day}`,
    day,
    title: inferredSlot.title,
    mealSlot: inferredSlot.slot,
    startMinute: inferredSlot.startMinute,
    endMinute: inferredSlot.startMinute + inferredSlot.durationMinutes,
    repeatDays: [day],
    mealCategory: inferredSlot.category,
    steps: cleanSteps,
    items: rawItems.length > 0 ? rawItems : undefined,
    caloriesEstimate,
    proteinEstimate,
    blockType: "soft_block",
    candidateType: "block",
    confidenceScore: confidence,
  };
}

function inferMealSlot(raw: string, startMinute: unknown, expectedSlots: MealSlot[]): MealSlot | null {
  const normalized = raw.trim().toLowerCase().replace(/-/g, "_").replace(/\s+/g, "_");
  const direct = expectedSlots.find((slot) => slot.slot === normalized);
  if (direct) return direct;
  if (normalized.includes("morning") && normalized.includes("snack")) {
    return expectedSlots.find((slot) => slot.slot === "morning_snack") ?? null;
  }
  if ((normalized.includes("afternoon") || normalized.includes("evening")) && normalized.includes("snack")) {
    return expectedSlots.find((slot) => slot.slot === "afternoon_snack") ?? null;
  }
  if (normalized.includes("extra") && normalized.includes("snack")) {
    return expectedSlots.find((slot) => slot.slot === "morning_snack") ?? null;
  }
  for (const slot of expectedSlots) {
    if (slot.category !== "snack" && normalized.includes(slot.category)) return slot;
  }
  if (normalized === "snack" || normalized === "snacks") {
    const snackSlots = expectedSlots.filter((slot) => slot.category === "snack");
    if (typeof startMinute === "number" && Number.isInteger(startMinute)) {
      const exact = snackSlots.find((slot) => slot.startMinute === startMinute);
      if (exact) return exact;
    }
    return snackSlots.length === 1 ? snackSlots[0] : null;
  }
  return null;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const requestId = request.headers.get("x-request-id") || `req-eat-${Date.now()}-${Math.random().toString(36).substring(2, 9)}`;

    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: corsHeaders(request, env, requestId) });
    }

    try {
      const url = new URL(request.url);

      if (request.method === "GET" && url.pathname === "/health") {
        return jsonResponse(request, env, {
          ok: true,
          service: "nutrition-worker",
          version: WORKER_VERSION,
          projectId: env.FIREBASE_PROJECT_ID,
          aiProvider: env.AI_PROVIDER || "gemini",
          aiModel: env.AI_MODEL?.trim() || DEFAULT_AI_MODEL,
          aiFallbackModel: env.AI_FALLBACK_MODEL?.trim() || DEFAULT_AI_FALLBACK_MODEL,
        }, 200, requestId);
      }

      if (request.method === "POST" && url.pathname === "/v1/eating/generate-routine") {
        return await handleEatingGenerateRoutine(request, env, requestId);
      }

      return jsonResponse(request, env, { error: "not_found", requestId }, 404, requestId);
    } catch (error) {
      const httpError = error instanceof HttpError ? error : null;
      if (httpError) {
        return jsonResponse(request, env, { error: httpError.errorCode, message: httpError.message, requestId }, httpError.status, requestId);
      }
      return jsonResponse(request, env, { error: "internal_error", message: "An unexpected error occurred", requestId }, 500, requestId);
    }
  }
};
