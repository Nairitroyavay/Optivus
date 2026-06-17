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
const UNSAFE_FREQUENCY_WARNING =
  "These products may not safely support 3 routines per day. Try 2 times per day.";

type OwnedSkinCareProduct = {
  name: string;
  category: string;
  searchableFields: string[];
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

function normalizedProductKey(value: string): string {
  return value
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, " ")
    .trim()
    .replace(/\s+/g, " ");
}

function containsInitialism(value: string, token: string): boolean {
  return new RegExp(`(^|[^a-z0-9])${token}([^a-z0-9]|$)`).test(value);
}

function looksLikeSunscreen(value: string): boolean {
  const lower = value.toLowerCase();
  return lower.includes("sunscreen") ||
    lower.includes("spf") ||
    lower.includes("sun cream") ||
    lower.includes("suncream") ||
    lower.includes("sunblock") ||
    lower.includes("uv") ||
    lower.includes("pa++++") ||
    lower.includes("pa ++++") ||
    lower.includes("uv filter") ||
    lower.includes("uv-filter");
}

function looksLikeCleanser(value: string): boolean {
  const lower = value.toLowerCase();
  return lower.includes("cleanser") ||
    lower.includes("face wash") ||
    lower.includes("wash face") ||
    lower.includes("cleansing gel") ||
    lower.includes("cleansing foam") ||
    lower.includes("micellar") ||
    lower.includes("cleanse");
}

function looksLikeMoisturizer(value: string): boolean {
  const lower = value.toLowerCase();
  if (looksLikeSunscreen(lower) || lower.includes("sun protection")) return false;
  return lower.includes("moisturizer") ||
    lower.includes("moisturiser") ||
    lower.includes("barrier cream") ||
    lower.includes("gel cream") ||
    lower.includes("lotion") ||
    lower.includes("barrier repair");
}

function looksLikeSerum(value: string): boolean {
  const lower = value.toLowerCase();
  return lower.includes("serum") ||
    lower.includes("ampoule") ||
    lower.includes("essence") ||
    lower.includes("vitamin c") ||
    lower.includes("alpha arbutin") ||
    lower.includes("niacinamide");
}

function looksLikeStrongActive(value: string): boolean {
  const lower = value.toLowerCase();
  return lower.includes("retinol") ||
    lower.includes("retinal") ||
    lower.includes("tretinoin") ||
    lower.includes("adapalene") ||
    lower.includes("exfoliant") ||
    lower.includes("exfoliate") ||
    lower.includes("exfoliator") ||
    lower.includes("peeling") ||
    lower.includes("peel") ||
    containsInitialism(lower, "pha") ||
    containsInitialism(lower, "aha") ||
    containsInitialism(lower, "bha") ||
    lower.includes("glycolic") ||
    lower.includes("lactic") ||
    lower.includes("salicylic") ||
    lower.includes("mandelic") ||
    lower.includes("benzoyl peroxide") ||
    lower.includes("strong active");
}

function productText(product: OwnedSkinCareProduct): string {
  return [product.name, product.category, ...product.searchableFields].join(" ");
}

function isSunscreen(product: OwnedSkinCareProduct): boolean {
  return product.category === "sunscreen" || looksLikeSunscreen(productText(product));
}

function isCleanser(product: OwnedSkinCareProduct): boolean {
  return product.category === "cleanser" || looksLikeCleanser(productText(product));
}

function isMoisturizer(product: OwnedSkinCareProduct): boolean {
  return product.category === "moisturizer" ||
    product.category === "moisturiser" ||
    looksLikeMoisturizer(productText(product));
}

function isSerum(product: OwnedSkinCareProduct): boolean {
  return product.category === "serum" || looksLikeSerum(productText(product));
}

function isStrongActive(product: OwnedSkinCareProduct): boolean {
  return product.category === "exfoliant" ||
    product.category === "exfoliator" ||
    looksLikeStrongActive(productText(product));
}

function isUsableDailyProduct(product: OwnedSkinCareProduct): boolean {
  if (isStrongActive(product)) return false;
  return isCleanser(product) ||
    isSunscreen(product) ||
    isMoisturizer(product) ||
    isSerum(product) ||
    product.category === "toner";
}

function isVitaminC(product: OwnedSkinCareProduct): boolean {
  return productText(product).toLowerCase().includes("vitamin c");
}

function isAlphaArbutin(product: OwnedSkinCareProduct): boolean {
  return productText(product).toLowerCase().includes("alpha arbutin");
}

function ownedProductName(value: any): string {
  if (typeof value === "string") return value.trim().replace(/\s+/g, " ");
  if (!value || typeof value !== "object") return "";
  const name = String(value.name || value.productName || value.product || "").trim().replace(/\s+/g, " ");
  const brand = String(value.brand || "").trim().replace(/\s+/g, " ");
  if (!name) return brand;
  if (!brand || name.toLowerCase().includes(brand.toLowerCase())) return name;
  return `${brand} ${name}`;
}

function ownedProductCatalog(rawProducts: any[]): OwnedSkinCareProduct[] {
  const seen = new Set<string>();
  const products: OwnedSkinCareProduct[] = [];

  for (const raw of rawProducts) {
    const name = ownedProductName(raw);
    if (!name) continue;
    const category = raw && typeof raw === "object"
      ? String(raw.category || "").trim().toLowerCase()
      : "";
    const searchableFields = stringList([
      name,
      category,
      raw && typeof raw === "object" ? raw.brand : "",
      ...(raw && typeof raw === "object" ? stringList(raw.keyIngredients || raw.ingredients) : []),
      ...(raw && typeof raw === "object" ? stringList(raw.possibleActives || raw.actives) : []),
      raw && typeof raw === "object" ? raw.usageHint || raw.usage : "",
      raw && typeof raw === "object" ? raw.warningIfAny || raw.warning || raw.warnings : "",
      raw && typeof raw === "object" ? raw.confidence : "",
    ]);
    const key = normalizedProductKey(name);
    if (!key || seen.has(key)) continue;
    seen.add(key);
    products.push({ name, category, searchableFields });
  }

  return products;
}

function significantProductTokens(value: string): Set<string> {
  const stopWords = new Set([
    "the",
    "and",
    "with",
    "for",
    "skin",
    "care",
    "product",
    "daily",
    "apply",
    "use",
    "serum",
    "sunscreen",
    "spf",
    "cleanser",
    "face",
    "wash",
    "moisturizer",
    "moisturiser",
    "cream",
    "lotion",
    "toner",
    "exfoliant",
    "exfoliator",
  ]);
  return new Set(normalizedProductKey(value)
    .split(" ")
    .filter((token) => token && !stopWords.has(token)));
}

function isGenericProductName(value: string): boolean {
  return new Set([
    "sunscreen",
    "spf",
    "cleanser",
    "face wash",
    "moisturizer",
    "moisturiser",
    "serum",
  ]).has(normalizedProductKey(value));
}

function singleOwnedProduct(
  products: OwnedSkinCareProduct[],
  test: (product: OwnedSkinCareProduct) => boolean,
): OwnedSkinCareProduct | null {
  const matches = products.filter(test);
  return matches.length === 1 ? matches[0] : null;
}

function matchOwnedProduct(value: string, products: OwnedSkinCareProduct[]): OwnedSkinCareProduct | null {
  const query = normalizedProductKey(value);
  if (!query) return null;
  const lower = value.toLowerCase();

  if (isGenericProductName(value)) {
    if (looksLikeSunscreen(lower)) return singleOwnedProduct(products, isSunscreen);
    if (looksLikeCleanser(lower)) return singleOwnedProduct(products, isCleanser);
    if (looksLikeMoisturizer(lower)) return singleOwnedProduct(products, isMoisturizer);
    if (looksLikeSerum(lower)) return singleOwnedProduct(products, isSerum);
  }

  for (const product of products) {
    if (normalizedProductKey(product.name) === query) return product;
  }
  for (const product of products) {
    const productKey = normalizedProductKey(product.name);
    if (query.length >= 4 && (productKey.includes(query) || query.includes(productKey))) {
      return product;
    }
  }

  const queryTokens = significantProductTokens(query);
  if (queryTokens.size > 0) {
    const tokenMatches = products.filter((product) => {
      const productTokens = significantProductTokens(product.name);
      if (productTokens.size === 0) return false;
      return [...queryTokens].every((token) => productTokens.has(token)) ||
        [...productTokens].every((token) => queryTokens.has(token));
    });
    if (tokenMatches.length === 1) return tokenMatches[0];
  }

  if (looksLikeSunscreen(lower)) return singleOwnedProduct(products, isSunscreen);
  if (looksLikeCleanser(lower)) return singleOwnedProduct(products, isCleanser);
  if (looksLikeMoisturizer(lower)) return singleOwnedProduct(products, isMoisturizer);
  if (looksLikeSerum(lower)) return singleOwnedProduct(products, isSerum);
  return null;
}

function dedupeOwnedProducts(products: OwnedSkinCareProduct[]): OwnedSkinCareProduct[] {
  const seen = new Set<string>();
  const result: OwnedSkinCareProduct[] = [];
  for (const product of products) {
    const key = normalizedProductKey(product.name);
    if (key && !seen.has(key)) {
      seen.add(key);
      result.push(product);
    }
  }
  return result;
}

function safeStepListForProducts(products: OwnedSkinCareProduct[]): string[] {
  return products.map((product) => isCleanser(product) ? "Cleanse face" : `Apply ${product.name}`);
}

function sameProducts(a: OwnedSkinCareProduct[], b: OwnedSkinCareProduct[]): boolean {
  const aKey = a.map((product) => normalizedProductKey(product.name)).join("|");
  const bKey = b.map((product) => normalizedProductKey(product.name)).join("|");
  return aKey === bKey;
}

function deterministicOwnedRoutine(
  products: OwnedSkinCareProduct[],
  desiredApplicationsPerDay: number,
): { routinePlans: any[]; weeklyRoutine: string[]; warnings: string[] } {
  const cleanser = products.find(isCleanser);
  const sunscreen = products.find(isSunscreen);
  const moisturizer = products.find(isMoisturizer);
  const safeSerums = products.filter((product) => isSerum(product) && !isStrongActive(product));
  const vitaminC = safeSerums.find(isVitaminC);
  const alphaArbutin = safeSerums.find(isAlphaArbutin);
  const fallbackSerum = safeSerums[0];
  const morningSerum = vitaminC || fallbackSerum;
  const nightSerum = alphaArbutin ||
    safeSerums.find((product) => product !== morningSerum) ||
    (!sunscreen ? morningSerum : undefined);

  const morningProducts = dedupeOwnedProducts([
    ...(cleanser ? [cleanser] : []),
    ...(morningSerum ? [morningSerum] : []),
    ...(moisturizer && !sunscreen ? [moisturizer] : []),
    ...(sunscreen ? [sunscreen] : []),
  ]);
  const nightProducts = dedupeOwnedProducts([
    ...(cleanser ? [cleanser] : []),
    ...(nightSerum ? [nightSerum] : []),
    ...(moisturizer ? [moisturizer] : []),
  ]);

  const routinePlans: any[] = [];
  if (morningProducts.length > 0) {
    routinePlans.push({
      slotLabel: "morning",
      title: "Morning Skin Care",
      steps: safeStepListForProducts(morningProducts),
      productNames: morningProducts.map((product) => product.name),
      warnings: [],
      repeatDays: [1, 2, 3, 4, 5, 6, 7],
    });
  }
  if (nightProducts.length > 0 && !sameProducts(morningProducts, nightProducts)) {
    routinePlans.push({
      slotLabel: "night",
      title: "Night Skin Care",
      steps: safeStepListForProducts(nightProducts),
      productNames: nightProducts.map((product) => product.name),
      warnings: [],
      repeatDays: [1, 2, 3, 4, 5, 6, 7],
    });
  }
  if (routinePlans.length === 0) {
    const firstDaily = products.find(isUsableDailyProduct);
    if (firstDaily) {
      routinePlans.push({
        slotLabel: isSunscreen(firstDaily) ? "morning" : "night",
        title: isSunscreen(firstDaily) ? "Morning Skin Care" : "Night Skin Care",
        steps: safeStepListForProducts([firstDaily]),
        productNames: [firstDaily.name],
        warnings: [],
        repeatDays: [1, 2, 3, 4, 5, 6, 7],
      });
    }
  }

  const weeklyRoutine = products
    .filter(isStrongActive)
    .map((product) => `Use ${product.name} 1-2 times per week at night. Do not combine with other strong actives.`);
  const warnings = [
    ...(!moisturizer
      ? ["No moisturizer detected. You can still use your current products, but adding moisturizer may improve night routine balance."]
      : []),
    ...(!sunscreen ? ["No sunscreen detected. Consider SPF for daytime protection."] : []),
    ...(!cleanser ? ["No cleanser detected. Add a cleanser if you want a complete cleanse step."] : []),
  ];
  if (desiredApplicationsPerDay > 2 && routinePlans.length > 0 && routinePlans.length < desiredApplicationsPerDay) {
    warnings.push(UNSAFE_FREQUENCY_WARNING);
  }

  return {
    routinePlans: routinePlans.slice(0, desiredApplicationsPerDay > 2 ? 2 : desiredApplicationsPerDay),
    weeklyRoutine,
    warnings,
  };
}

function noteText(value: any): string {
  if (typeof value === "string") return value;
  if (!value || typeof value !== "object") return String(value || "");
  return stringList([
    value.title,
    value.name,
    value.productName,
    value.product,
    value.warning,
    value.warningIfAny,
    value.instruction,
    value.step,
    value.text,
    ...(Array.isArray(value.products) ? stringList(value.products) : []),
    ...(Array.isArray(value.productNames) ? stringList(value.productNames) : []),
    ...(Array.isArray(value.steps) ? stringList(value.steps) : []),
    ...(Array.isArray(value.warnings) ? stringList(value.warnings) : []),
  ]).join(" ");
}

function ownedNoteAllowed(value: any, products: OwnedSkinCareProduct[]): boolean {
  const text = noteText(value).trim();
  if (!text) return false;
  const lower = text.toLowerCase();
  const outsideBrand = lower.includes("cerave") ||
    lower.includes("cera ve") ||
    lower.includes("la roche") ||
    lower.includes("laroche") ||
    lower.includes("posay") ||
    lower.includes("paula");
  const outsideBrandOwned = products.some((product) => {
    const productLower = product.name.toLowerCase();
    return (lower.includes("cerave") && productLower.includes("cerave")) ||
      (lower.includes("cera ve") && productLower.includes("cera ve")) ||
      (lower.includes("la roche") && productLower.includes("la roche")) ||
      (lower.includes("laroche") && productLower.includes("laroche")) ||
      (lower.includes("posay") && productLower.includes("posay")) ||
      (lower.includes("paula") && productLower.includes("paula"));
  });
  if (outsideBrand && !outsideBrandOwned) return false;
  if (products.some((product) => normalizedProductKey(text).includes(normalizedProductKey(product.name)))) {
    return true;
  }
  return lower.includes("no moisturizer") ||
    lower.includes("missing moisturizer") ||
    lower.includes("no sunscreen") ||
    lower.includes("missing sunscreen") ||
    lower.includes("no cleanser") ||
    lower.includes("missing cleanser") ||
    lower.startsWith("warning") ||
    lower.includes("warning:") ||
    lower.startsWith("missing:");
}

function sanitizeOwnedRoutinePlan(
  plan: any,
  products: OwnedSkinCareProduct[],
  rejectedPlanReasons: string[],
): any | null {
  const normalized = normalizeRoutinePlan(plan);
  if (!normalized) {
    rejectedPlanReasons.push("empty");
    return null;
  }

  const matched: OwnedSkinCareProduct[] = [];
  if (normalized.productNames.length > 0) {
    for (const productName of normalized.productNames) {
      const product = matchOwnedProduct(productName, products);
      if (!product) {
        rejectedPlanReasons.push(`product_mismatch:${normalized.slotLabel}:${productName}`);
        return null;
      }
      matched.push(product);
    }
  } else {
    for (const step of normalized.steps) {
      const product = matchOwnedProduct(step, products);
      if (product) matched.push(product);
      else if (looksLikeSunscreen(step)) {
        const sunscreen = singleOwnedProduct(products, isSunscreen);
        if (sunscreen) matched.push(sunscreen);
      } else if (looksLikeCleanser(step)) {
        const cleanser = singleOwnedProduct(products, isCleanser);
        if (cleanser) matched.push(cleanser);
      } else if (looksLikeMoisturizer(step)) {
        const moisturizer = singleOwnedProduct(products, isMoisturizer);
        if (moisturizer) matched.push(moisturizer);
      }
    }
  }

  const safeProducts = dedupeOwnedProducts(matched).filter((product) => !isStrongActive(product));
  if (safeProducts.length === 0) {
    rejectedPlanReasons.push(`unsafe:${normalized.slotLabel}:${normalized.title}`);
    return null;
  }
  if (normalized.slotLabel === "night" && safeProducts.every(isSunscreen)) {
    rejectedPlanReasons.push(`unsafe:${normalized.slotLabel}:night_sunscreen`);
    return null;
  }

  const safeSteps = stringList(normalized.steps).filter((step) => !looksLikeStrongActive(step));
  return {
    ...normalized,
    steps: safeSteps.length > 0 ? safeSteps : safeStepListForProducts(safeProducts),
    productNames: safeProducts.map((product) => product.name),
  };
}

function mergeOwnedRoutinePlans(
  aiPlans: any[],
  fallbackPlans: any[],
  desiredApplicationsPerDay: number,
  minimumPlanCount: number,
): any[] {
  const orderedSlots = ["morning", "midday", "afternoon", "night", "custom"];
  const orderPlans = (plans: any[]): any[] => {
    const bySlot = new Map<string, any>();
    for (const plan of plans) {
      const slot = String(plan.slotLabel || "custom").toLowerCase();
      if (!bySlot.has(slot)) bySlot.set(slot, plan);
    }
    const ordered: any[] = [];
    for (const slot of orderedSlots) {
      const plan = bySlot.get(slot);
      if (plan) ordered.push(plan);
    }
    for (const [slot, plan] of bySlot.entries()) {
      if (!orderedSlots.includes(slot)) ordered.push(plan);
    }
    return ordered;
  };

  if (aiPlans.length > 0 && aiPlans.length >= minimumPlanCount) {
    return orderPlans(aiPlans).slice(0, desiredApplicationsPerDay);
  }

  const bySlot = new Map<string, any>();
  for (const plan of aiPlans) {
    const slot = String(plan.slotLabel || "custom").toLowerCase();
    if (!bySlot.has(slot)) bySlot.set(slot, plan);
  }
  for (const plan of fallbackPlans) {
    const slot = String(plan.slotLabel || "custom").toLowerCase();
    if (!bySlot.has(slot)) bySlot.set(slot, plan);
  }
  const ordered: any[] = [];
  for (const slot of orderedSlots) {
    const plan = bySlot.get(slot);
    if (plan) ordered.push(plan);
  }
  for (const [slot, plan] of bySlot.entries()) {
    if (!orderedSlots.includes(slot)) ordered.push(plan);
  }
  const targetCount = aiPlans.length >= desiredApplicationsPerDay
    ? desiredApplicationsPerDay
    : Math.min(
        Math.max(aiPlans.length, minimumPlanCount),
        desiredApplicationsPerDay > 2 ? 2 : desiredApplicationsPerDay,
      );
  return ordered.slice(0, targetCount);
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

async function callGeminiWithFallback(prompt: string, imageParts: any[], env: Env): Promise<string> {
  const provider = env.AI_PROVIDER || "gemini";
  if (provider !== "gemini") {
    throw new HttpError(400, "ai_disabled", "AI provider is disabled or unsupported.");
  }

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
    return await fetchGemini(primaryModel);
  } catch (err) {
    if (fallbackModel && fallbackModel !== primaryModel) {
      console.warn(`[SkinCareWorker] Primary model ${primaryModel} failed. Attempting fallback ${fallbackModel}.`);
      try {
        return await fetchGemini(fallbackModel);
      } catch {
        throw new HttpError(500, "provider_request_failed", "AI provider request failed.");
      }
    } else {
      throw new HttpError(500, "provider_request_failed", "AI provider request failed.");
    }
  }
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

  const text = await callGeminiWithFallback(prompt, imageParts, env);
  
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

  const productsFromPhoto = Array.isArray(body.productsFromPhoto)
    ? body.productsFromPhoto
    : [];
  const requestedProductInputSource = String(body.productInputSource || "").toLowerCase();
  const legacyTypedProductNames = Array.isArray(body.typedProductNames)
    ? stringList(body.typedProductNames)
    : [];
  const explicitTypedProductDetails = Array.isArray(body.typedProductDetails)
    ? body.typedProductDetails
    : [];
  const typedProductDetails = explicitTypedProductDetails.length > 0
    ? explicitTypedProductDetails
    : (requestedProductInputSource === "typed" || productsFromPhoto.length === 0)
      ? legacyTypedProductNames.map((name) => ({ name, source: "typed" }))
      : [];
  const activeSource = String(
    requestedProductInputSource ||
      (typedProductDetails.length > 0
        ? "typed"
        : productsFromPhoto.length > 0
          ? "photo"
          : "none")
  ).toLowerCase();
  const ownedProducts = activeSource === "photo"
    ? productsFromPhoto
    : activeSource === "typed"
      ? typedProductDetails
      : [];
  if ((activeSource === "photo" || activeSource === "typed") && ownedProducts.length === 0) {
    throw new HttpError(400, "invalid_skin_care_request", "No owned products were provided for routine generation.");
  }
  const ownedProductInstruction = activeSource === "photo" || activeSource === "typed"
    ? `Active Product Source: ${activeSource}
Owned Products From Active Source Only: ${JSON.stringify(ownedProducts)}
Use ONLY the owned products above. Do not merge photo and typed products. Do not invent missing products. Do not suggest CeraVe, La Roche-Posay, Paula's Choice, or any product outside the owned list unless the user owns it.
When source is photo, these are productsFromPhoto. When source is typed, these are typedProductDetails.
Pay attention to name, category, source, keyIngredients, possibleActives, usageHint, warningIfAny, and confidence.
Use product categories and ingredient/active metadata to identify product roles, especially sunscreen. A product may be sunscreen if category is sunscreen, name mentions UV/sun/SPF, ingredients/actives mention UV filters, or warnings/usage imply sun protection.
If moisturizer is missing, add a generic warning/note only. If sunscreen is missing, add a generic warning/note only. Do not name outside products in suggestedProducts, weeklyRoutine, routinePlans, warnings, or notes for an owned-product request. Missing moisturizer, cleanser, or sunscreen must not block generation. If the user owns an incomplete set, still build the best safe limited routine from available products.
Return routinePlans using EXACT owned product names from the list above. Do not use generic names if an exact product name is available.
Return exactly ${desiredApplicationsPerDay} routinePlans unless there is a safety reason not to. If owned products cannot safely support ${desiredApplicationsPerDay} routines per day, return fewer routinePlans and include warnings explaining the limit.
If a product is a strong active or exfoliant, do not schedule it daily unless the owned product metadata explicitly says daily use is safe.`
    : `No owned products were provided. Build a general safe starter routine from the user's skin details.`;

  const prompt = `You are an expert dermatologist. Generate skin-care routine plans. Flutter owns all schedule placement and duration. Do NOT choose final schedule times.
Skin Type: ${body.skinType || "unknown"}
Main Problem: ${body.mainProblem || "none"}
Budget: ${body.budget || "medium"}
Routine Preference: ${body.routinePreference || "balanced"}
Desired Applications Per Day: ${desiredApplicationsPerDay}
${ownedProductInstruction}
Use warningIfAny and possibleActives to avoid unsafe conflicts. E.g. avoid Retinol + AHA/BHA in the same routine block, sunscreen in morning when appropriate.
If a face photo is provided, use it to personalize the routine and suggested products.
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
  "suggestedProducts": ["Warnings or optional generic gap notes only. For owned-product requests, do not name unowned products here."],
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

  const text = await callGeminiWithFallback(prompt, imageParts, env);

  const parsed = parseAiJsonText(text);
  if (!parsed) {
    throw new HttpError(502, "provider_invalid_json", "AI response could not be read safely. Please try again.");
  }
  const rawRoutinePlans = Array.isArray(parsed.routinePlans)
    ? parsed.routinePlans
    : Array.isArray(parsed.plans)
      ? parsed.plans
      : [];
  const rejectedPlanReasons: string[] = [];
  const ownedProductMode = activeSource === "photo" || activeSource === "typed";
  const catalog = ownedProductMode ? ownedProductCatalog(ownedProducts) : [];
  const fallback = ownedProductMode
    ? deterministicOwnedRoutine(catalog, desiredApplicationsPerDay)
    : { routinePlans: [], weeklyRoutine: [], warnings: [] };
  const rawWeeklyRoutine = Array.isArray(parsed.weeklyRoutine) ? parsed.weeklyRoutine : [];
  const rawSuggestedProducts = Array.isArray(parsed.suggestedProducts) ? parsed.suggestedProducts : [];
  const aiRoutinePlans = ownedProductMode
    ? rawRoutinePlans
        .map((plan: any) => sanitizeOwnedRoutinePlan(plan, catalog, rejectedPlanReasons))
        .filter((plan: any) => plan !== null)
    : rawRoutinePlans
        .map(normalizeRoutinePlan)
        .filter((plan: any) => plan !== null);
  const minimumOwnedPlanCount = ownedProductMode && catalog.some(isUsableDailyProduct)
    ? catalog.some(isCleanser) && catalog.some(isSunscreen)
      ? Math.min(2, desiredApplicationsPerDay)
      : aiRoutinePlans.length === 0
        ? Math.min(1, fallback.routinePlans.length)
        : aiRoutinePlans.length
    : 0;
  const routinePlans = ownedProductMode
    ? mergeOwnedRoutinePlans(
        aiRoutinePlans,
        fallback.routinePlans,
        desiredApplicationsPerDay,
        minimumOwnedPlanCount,
      )
    : aiRoutinePlans;
  const warnings = stringList([
    ...stringList(parsed.warnings),
    ...(ownedProductMode ? fallback.warnings : []),
  ]);
  if (routinePlans.length < desiredApplicationsPerDay) {
    warnings.push("routine_plan_count_mismatch");
  }
  const weeklyRoutine = ownedProductMode
    ? stringList([
        ...rawWeeklyRoutine.filter((item: any) => ownedNoteAllowed(item, catalog)).map(noteText),
        ...fallback.weeklyRoutine,
      ])
    : rawWeeklyRoutine;
  const suggestedProducts = ownedProductMode
    ? stringList(rawSuggestedProducts.filter((item: any) => ownedNoteAllowed(item, catalog)).map(noteText))
    : rawSuggestedProducts;
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
    weeklyRoutine,
    timelineBlocks: compatibilityTimelineBlocks,
    suggestedProducts,
    warnings,
    rejectedPlanReasons
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
