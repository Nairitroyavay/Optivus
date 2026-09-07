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

type MealSlot = {
  slot: string;
  category: "breakfast" | "lunch" | "snack" | "dinner";
  title: string;
  startMinute: number;
  durationMinutes: number;
};

function expectedMealSlots(context: any): MealSlot[] {
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

function buildEatingGeneratePrompt(context: any): string {
  const slots = expectedMealSlots(context);
  const slotLines = slots
    .map((slot) => `- ${slot.slot}: title "${slot.title}", mealCategory "${slot.category}", startMinute ${slot.startMinute}, duration ${slot.durationMinutes} min`)
    .join("\n");
  const totalMeals = 7 * slots.length;

  return `You are a nutrition expert generating a personalized, highly diverse, 7-day meal routine JSON.
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
- Lifestyle: ${context.lifestyle ?? "Unknown"}
- Country: ${context.country ?? "Unknown"}

Meal Slots Per Day (${slots.length} slots):
${slotLines}

Generation Requirements:
1. You MUST generate meals for ALL 7 DAYS of the week (day 1=Monday, day 2=Tuesday, day 3=Wednesday, day 4=Thursday, day 5=Friday, day 6=Saturday, day 7=Sunday).
2. For EACH day (1 to 7), you MUST provide every required meal slot listed above. Exactly ${totalMeals} meal objects total (${slots.length} meals × 7 days).
3. ALL 7 days must have distinct complete daily menus. For each meal slot, the full dish combination must differ from that same meal slot on every other day. Individual ingredients may repeat, but the complete meal composition may not.
4. Each meal block MUST contain:
   - "day": integer from 1 to 7 (1=Monday .. 7=Sunday)
   - "repeatDays": array with exactly that single day, e.g. [1] or [2]
   - "mealSlot": one of exactly ${slots.map((s) => `"${s.slot}"`).join(", ")}
   - "title": the canonical title for that slot
   - "startMinute": integer (the requested startMinute for that slot)
   - "endMinute": integer (startMinute + durationMinutes)
   - "mealCategory": category of the slot ("breakfast", "lunch", "snack", or "dinner")
   - "steps": array of at least 2 specific dish items (e.g. ["Steel Cut Oats with Almond Butter", "Greek Yogurt with Blueberries"]). Do NOT output generic terms like "Food", "Meal", or repeat the meal title.
   - "caloriesEstimate": realistic integer number of calories for this specific meal.
   - "proteinEstimate": realistic integer number of grams of protein for this specific meal.
   - "blockType": "soft_block"
   - "candidateType": "block"
   - "confidenceScore": 0.95
5. Daily Nutrition Target Invariant:
   - For every single day, the sum of "caloriesEstimate" for all meals of that day MUST be within ±15% of the Daily Target Calories (${context.targetCalories} kcal).
   ${context.proteinTarget ? `- For every single day, the sum of "proteinEstimate" for all meals of that day MUST be within ±20% of the Daily Protein Target (${context.proteinTarget} g).` : ""}

Return ONLY valid JSON matching this schema:
{
  "candidates": [
    {
      "day": 1,
      "repeatDays": [1],
      "mealSlot": "breakfast",
      "title": "Breakfast",
      "startMinute": ${slots[0].startMinute},
      "endMinute": ${slots[0].startMinute + slots[0].durationMinutes},
      "mealCategory": "${slots[0].category}",
      "steps": ["Dish 1", "Dish 2"],
      "caloriesEstimate": 450,
      "proteinEstimate": 25,
      "blockType": "soft_block",
      "candidateType": "block",
      "confidenceScore": 0.95
    }
  ]
}`;
}

async function handleEatingGenerateRoutine(request: Request, env: Env): Promise<Response> {
  const user = await requireVerifiedFirebaseUser(request, env);
  const body = await readSmallJson(request);

  const context = {
    bodyGoal: readRequiredString(body, "bodyGoal"),
    eatingMode: readRequiredString(body, "eatingMode"),
    foodType: readRequiredString(body, "foodType"),
    foodStyleCustomText: readOptionalString(body, "foodStyleCustomText"),
    mealsPerDay: readRequiredNumber(body, "mealsPerDay"),
    targetCalories: readRequiredNumber(body, "targetCalories"),
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

  if (!Number.isInteger(context.mealsPerDay) || context.mealsPerDay < 3 || context.mealsPerDay > 5) {
    throw new HttpError(400, "invalid_eating_request", "mealsPerDay must be 3, 4, or 5.");
  }
  if (context.targetCalories <= 0 || !Number.isFinite(context.targetCalories)) {
    throw new HttpError(400, "invalid_eating_request", "targetCalories must be positive and finite.");
  }
  if (context.proteinTarget !== undefined && (!Number.isFinite(context.proteinTarget) || context.proteinTarget <= 0)) {
    throw new HttpError(400, "invalid_eating_request", "proteinTarget must be positive and finite.");
  }

  const prompt = buildEatingGeneratePrompt(context);
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

  const slots = expectedMealSlots(context);
  const validBlocks = blocks
    .map((block: unknown) => sanitizeMealCandidate(block, genericTerms, slots))
    .filter((block: Record<string, unknown> | null): block is Record<string, unknown> => block !== null);

  if (validBlocks.length === 0) {
    throw new HttpError(500, "provider_empty_candidates", "AI returned no valid meals.");
  }

  const byDayAndSlot = new Map<string, Record<string, unknown>>();
  const expectedSlotIds = new Set(slots.map((slot) => slot.slot));
  for (const block of validBlocks) {
    const slot = String(block.mealSlot || "");
    const day = Number(block.day);
    if (!expectedSlotIds.has(slot)) {
      throw new HttpError(500, "provider_unexpected_meal_slot", "AI returned an unexpected meal slot.");
    }
    const key = `${day}_${slot}`;
    if (byDayAndSlot.has(key)) {
      throw new HttpError(500, "provider_duplicate_meal_slot", `AI returned a duplicate meal slot for day ${day}.`);
    }
    byDayAndSlot.set(key, block);
  }

  for (let day = 1; day <= 7; day++) {
    for (const slot of slots) {
      if (!byDayAndSlot.has(`${day}_${slot.slot}`)) {
        throw new HttpError(500, "provider_incomplete_week", `AI missed required meal slot "${slot.slot}" on day ${day}.`);
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
        throw new HttpError(500, "provider_target_mismatch", `Generated calories on day ${day} (${dayCalories}) deviated from target (${targetCalories}).`);
      }
    }
    if (proteinTarget && proteinTarget > 0) {
      const pMin = proteinTarget * 0.80;
      const pMax = proteinTarget * 1.20;
      if (dayProtein < pMin || dayProtein > pMax) {
        throw new HttpError(500, "provider_target_mismatch", `Generated protein on day ${day} (${dayProtein}g) deviated from target (${proteinTarget}g).`);
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
    throw new HttpError(500, "provider_insufficient_diversity", "AI generated repetitive meals across days without 7 unique daily menus.");
  }

  // Same-slot diversity across days: all 7 days must have distinct full dish-set signatures for each mealSlot
  for (const slot of slots) {
    const slotSignatures = new Set<string>();
    for (let day = 1; day <= 7; day++) {
      const b = byDayAndSlot.get(`${day}_${slot.slot}`)!;
      slotSignatures.add(mealSignature(b.steps as string[]));
    }
    if (slotSignatures.size !== 7) {
      throw new HttpError(500, "provider_insufficient_diversity", `AI repeated dish combinations for meal slot "${slot.slot}" across the week.`);
    }
  }

  const orderedBlocks: Record<string, unknown>[] = [];
  for (let day = 1; day <= 7; day++) {
    for (const slot of slots) {
      orderedBlocks.push(byDayAndSlot.get(`${day}_${slot.slot}`)!);
    }
  }

  return jsonResponse(request, env, { 
    id: `eat-gen-${Date.now()}`,
    uid: user.uid,
    candidates: orderedBlocks
  });
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

  const cleanSteps = Array.isArray(block.steps)
    ? block.steps
        .map((step) => typeof step === "string" ? step.trim() : "")
        .filter((step) => step !== "" && !genericTerms.has(step.toLowerCase()))
        .slice(0, 12)
    : [];

  const inferredSlot = inferMealSlot(rawMealSlot || mealCategory || title, block.startMinute, expectedSlots);
  if (!inferredSlot) {
    console.warn("[NutritionWorker] Dropping meal candidate without stable slot identity.");
    return null;
  }

  const validCategory = inferredSlot.category === mealCategory ||
    (inferredSlot.category === "snack" && (mealCategory === "snack" || mealCategory === "snacks"));

  if (
    title === "" ||
    title.length > 120 ||
    !validCategory ||
    cleanSteps.length < 2
  ) {
    console.warn("[NutritionWorker] Dropping invalid meal candidate.");
    return null;
  }

  let caloriesEstimate: number | null = null;
  if (typeof block.caloriesEstimate === "number" && Number.isFinite(block.caloriesEstimate) && block.caloriesEstimate > 0) {
    caloriesEstimate = Math.round(block.caloriesEstimate);
  } else if (typeof block.calories === "number" && Number.isFinite(block.calories) && block.calories > 0) {
    caloriesEstimate = Math.round(block.calories);
  }

  let proteinEstimate: number | null = null;
  if (typeof block.proteinEstimate === "number" && Number.isFinite(block.proteinEstimate) && block.proteinEstimate > 0) {
    proteinEstimate = Math.round(block.proteinEstimate);
  } else if (typeof block.protein === "number" && Number.isFinite(block.protein) && block.protein > 0) {
    proteinEstimate = Math.round(block.protein);
  }

  if (caloriesEstimate === null) {
    console.warn("[NutritionWorker] Dropping candidate without valid positive caloriesEstimate.");
    return null;
  }
  if (proteinEstimate === null) {
    console.warn("[NutritionWorker] Dropping candidate without valid positive proteinEstimate.");
    return null;
  }

  const confidence = typeof block.confidenceScore === "number" &&
      Number.isFinite(block.confidenceScore)
    ? Math.max(0, Math.min(1, block.confidenceScore))
    : 0.8;

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
        return await handleEatingGenerateRoutine(request, env);
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
