import { createRemoteJWKSet, jwtVerify } from "jose";

const ROUTINE_GENERATE_JSON_MAX_BYTES = 64 * 1024;
const IMAGE_MAX_BYTES = 15 * 1024 * 1024;
const GEMINI_RESPONSE_MAX_BYTES = 1024 * 1024;
const GEMINI_REQUEST_TIMEOUT_MS = 60_000;

type OwnedSkinCareProduct = {
  name: string;
  category: string;
  searchableFields: string[];
};

type ProviderFailureCode =
  | "provider_model_not_found"
  | "provider_invalid_image_payload"
  | "provider_invalid_request"
  | "provider_unauthorized"
  | "provider_quota_exceeded"
  | "provider_timeout"
  | "provider_empty_candidates"
  | "provider_invalid_json"
  | "provider_invalid_response"
  | "provider_high_demand"
  | "provider_unavailable"
  | "provider_request_failed";

type ProviderFailure = {
  errorCode: ProviderFailureCode;
  providerStatus?: number;
  providerCode?: string;
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

class ProviderRequestError extends Error {
  failure: ProviderFailure;

  constructor(failure: ProviderFailure) {
    super(failure.errorCode);
    this.failure = failure;
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
    headers: {
      ...Object.fromEntries(corsHeaders(request, env)),
      "Cache-Control": "no-store",
      "Content-Type": "application/json",
    },
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

function normalizeMissingItems(
  value: any,
): Array<{ name: string; importance: string; reason: string }> {
  const raw = Array.isArray(value)
    ? value
    : value == null
      ? []
      : [value];
  const seen = new Set<string>();
  const result: Array<{ name: string; importance: string; reason: string }> = [];

  for (const item of raw) {
    const source = item && typeof item === "object" ? item : { name: item };
    const name = String(source.name || source.product || source.productName || source.category || "")
      .trim()
      .replace(/\s+/g, " ");
    if (!name) continue;
    const key = name.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    const importance = String(source.importance || source.priority || "important")
      .trim()
      .toLowerCase()
      .replace(/[_-]+/g, " ")
      .replace(/\s+/g, " ") || "important";
    const reason = String(source.reason || source.note || source.why || "")
      .trim()
      .replace(/\s+/g, " ");
    result.push({ name, importance, reason });
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

function canonicalRoutineSlot(slot: string): string {
  const value = String(slot || "").toLowerCase().trim().replace(/[-\s]+/g, "_");
  if (value === "evening" || value === "pm" || value === "bedtime") return "night";
  if (value === "noon" || value === "lunch") return "midday";
  if (value === "am" || value === "after_bath") return "morning";
  return value;
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
    missingItems: normalizeMissingItems(
      plan.missingItems || plan.missing_items || plan.missingProducts || plan.missing_products,
    ),
    warnings: stringList(plan.warnings || plan.warningIfAny),
    repeatDays: repeatDays(plan.repeatDays || plan.days),
  };
}

function normalizeRecommendedProducts(value: any): Array<{
  name: string;
  brand: string;
  category: string;
  estimatedPrice: string;
  currencyCode: string;
  reason: string;
}> {
  const raw = Array.isArray(value) ? value : [];
  const seen = new Set<string>();
  const result: Array<{
    name: string;
    brand: string;
    category: string;
    estimatedPrice: string;
    currencyCode: string;
    reason: string;
  }> = [];
  for (const item of raw) {
    const source = item && typeof item === "object" ? item : { name: item };
    const name = String(source.name || source.productName || "").trim().replace(/\s+/g, " ");
    const brand = String(source.brand || "").trim().replace(/\s+/g, " ");
    if (!name || !brand) continue;
    const key = normalizedProductKey(`${brand} ${name}`);
    if (!key || seen.has(key)) continue;
    seen.add(key);
    result.push({
      name,
      brand,
      category: String(source.category || "").trim().toLowerCase().replace(/\s+/g, " "),
      estimatedPrice: String(source.estimatedPrice || source.price || source.priceRange || "")
        .trim()
        .replace(/\s+/g, " "),
      currencyCode: String(source.currencyCode || source.currency || "").trim().toUpperCase(),
      reason: String(source.reason || source.why || "").trim().replace(/\s+/g, " "),
    });
    if (result.length >= 12) break;
  }
  return result;
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

function looksLikeLeaveOnStrongActive(value: string): boolean {
  return looksLikeStrongActive(value) && !looksLikeCleanser(value);
}

function productClassificationText(product: OwnedSkinCareProduct): string {
  return [product.name, product.category, ...product.searchableFields].join(" ");
}

function isSunscreen(product: OwnedSkinCareProduct): boolean {
  return product.category === "sunscreen" ||
    looksLikeSunscreen(productClassificationText(product));
}

function isCleanser(product: OwnedSkinCareProduct): boolean {
  return product.category === "cleanser" ||
    looksLikeCleanser(productClassificationText(product));
}

function isRinseOffCleanser(product: OwnedSkinCareProduct): boolean {
  const lower = productClassificationText(product).toLowerCase();
  return product.category === "cleanser" ||
    lower.includes("face wash") ||
    lower.includes("cleanser") ||
    lower.includes("cleansing gel") ||
    lower.includes("cleansing foam");
}

function isMoisturizer(product: OwnedSkinCareProduct): boolean {
  return product.category === "moisturizer" ||
    product.category === "moisturiser" ||
    looksLikeMoisturizer(productClassificationText(product));
}

function isSerum(product: OwnedSkinCareProduct): boolean {
  return product.category === "serum" ||
    looksLikeSerum(productClassificationText(product));
}

function isStrongActive(product: OwnedSkinCareProduct): boolean {
  if (isRinseOffCleanser(product)) return false;
  return product.category === "exfoliant" ||
    product.category === "exfoliator" ||
    looksLikeStrongActive(productClassificationText(product));
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

function isSafeSerum(product: OwnedSkinCareProduct): boolean {
  return isSerum(product) && !isStrongActive(product);
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

function inferOwnedProductFromStep(step: string, products: OwnedSkinCareProduct[]): OwnedSkinCareProduct | null {
  const lower = step.toLowerCase();
  const direct = matchOwnedProduct(step, products);
  if (direct) return direct;
  if (looksLikeCleanser(lower)) return singleOwnedProduct(products, isCleanser);
  if (looksLikeSunscreen(lower) || lower.includes("sun protection")) {
    return singleOwnedProduct(products, isSunscreen);
  }
  if (lower.includes("vitamin c")) return matchOwnedProduct("vitamin c serum", products);
  if (lower.includes("alpha arbutin")) return matchOwnedProduct("alpha arbutin serum", products);
  if (looksLikeSerum(lower)) return singleOwnedProduct(products, isSafeSerum);
  return null;
}

function inferOwnedProductsFromSteps(
  steps: string[],
  products: OwnedSkinCareProduct[],
): OwnedSkinCareProduct[] {
  const inferred: OwnedSkinCareProduct[] = [];
  for (const step of steps) {
    const product = inferOwnedProductFromStep(step, products);
    if (product) inferred.push(product);
  }
  return dedupeOwnedProducts(inferred);
}

function safeRepeatDays(value: any): number[] {
  const days = repeatDays(value);
  return days.length > 0 ? days : [1, 2, 3, 4, 5, 6, 7];
}

function sameRepeatDays(left: number[], right: number[]): boolean {
  if (left.length !== right.length) return false;
  return left.every((day, index) => day === right[index]);
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
): { plans: any[]; strongActiveSplitNotes: string[] } {
  const normalized = normalizeRoutinePlan(plan);
  if (!normalized) {
    rejectedPlanReasons.push("empty");
    return { plans: [], strongActiveSplitNotes: [] };
  }

  const matched: OwnedSkinCareProduct[] = [];
  if (normalized.productNames.length === 0) {
    const inferred = inferOwnedProductsFromSteps(normalized.steps, products);
    if (inferred.length === 0) {
      rejectedPlanReasons.push(`missing_product_names:${normalized.slotLabel}:${normalized.title}`);
      return { plans: [], strongActiveSplitNotes: [] };
    } else {
      rejectedPlanReasons.push(`missing_product_names_inferred:${normalized.slotLabel}`);
      matched.push(...inferred);
    }
  } else {
    for (const productName of normalized.productNames) {
      const product = matchOwnedProduct(productName, products);
      if (!product) {
        rejectedPlanReasons.push(`product_mismatch:${normalized.slotLabel}:${productName}`);
      } else {
        matched.push(product);
      }
    }
    matched.push(...inferOwnedProductsFromSteps(normalized.steps, products));
  }

  const ownedPlanProducts = dedupeOwnedProducts(matched);
  if (ownedPlanProducts.length === 0) {
    rejectedPlanReasons.push(`empty:${normalized.slotLabel}:${normalized.title}`);
    return { plans: [], strongActiveSplitNotes: [] };
  }
  if (normalized.slotLabel === "night" && ownedPlanProducts.every(isSunscreen)) {
    rejectedPlanReasons.push(`unsafe:${normalized.slotLabel}:night_sunscreen`);
    return { plans: [], strongActiveSplitNotes: [] };
  }

  const missingItems = sanitizeMissingItemsForOwnedProducts(
    normalized.missingItems,
    products,
  );
  const planHasStrongActive = _planHasStrongActive(normalized, ownedPlanProducts);
  if (planHasStrongActive && !_planExplicitlyAllowsDailyStrongActive(normalized)) {
    return repairStrongActiveRoutinePlan(
      normalized,
      ownedPlanProducts,
      missingItems,
      rejectedPlanReasons,
    );
  }

  return {
    plans: [{
      ...normalized,
      steps: normalized.steps,
      productNames: ownedPlanProducts.map((product) => product.name),
      missingItems,
    }],
    strongActiveSplitNotes: [],
  };
}

function repairStrongActiveRoutinePlan(
  normalized: any,
  ownedPlanProducts: OwnedSkinCareProduct[],
  missingItems: Array<{ name: string; importance: string; reason: string }>,
  rejectedPlanReasons: string[],
): { plans: any[]; strongActiveSplitNotes: string[] } {
  const safeProducts = dedupeOwnedProducts(
    ownedPlanProducts.filter((product) => !isStrongActive(product)),
  );
  const strongProducts = dedupeOwnedProducts(
    ownedPlanProducts.filter((product) => isStrongActive(product)),
  );
  const safeSteps = normalized.steps.filter((step: string) => !looksLikeLeaveOnStrongActive(step));
  const activeSteps = normalized.steps.filter((step: string) => looksLikeLeaveOnStrongActive(step));
  if (safeProducts.length === 0) {
    rejectedPlanReasons.push(`unsafe_no_safe_products:${normalized.slotLabel}:${normalized.title}`);
    return { plans: [], strongActiveSplitNotes: [] };
  }

  const slot = canonicalRoutineSlot(normalized.slotLabel);
  const activeProductName = strongProducts[0]?.name || activeSteps[0] || normalized.title;
  const days = safeRepeatDays(normalized.repeatDays);
  if (slot !== "night") {
    rejectedPlanReasons.push(`strong_active_removed_from_non_night:${slot}:${activeProductName}`);
    return {
      plans: [{
        ...normalized,
        repeatDays: days,
        productNames: safeProducts.map((product) => product.name),
        steps: safeSteps,
        missingItems,
      }],
      strongActiveSplitNotes: [
        `${activeProductName} was removed from the daily ${slot} routine and moved to special-care notes. Add it manually on two nights only after review.`,
      ],
    };
  }

  if (sameRepeatDays(days, [3, 6])) {
    return {
      plans: [{
        ...normalized,
        slotLabel: "night",
        repeatDays: [3, 6],
        productNames: dedupeOwnedProducts([...safeProducts, ...strongProducts])
          .map((product) => product.name),
        steps: [...safeSteps, ...activeSteps],
        missingItems,
        warnings: [
          ...normalized.warnings,
          "Use strong actives only 2 times per week. Do not combine with other exfoliants/retinoids.",
        ],
      }],
      strongActiveSplitNotes: [
        `${activeProductName} is used only on Wednesday and Saturday nights. Do not combine with other strong actives.`,
      ],
    };
  }

  if (!sameRepeatDays(days, [1, 2, 3, 4, 5, 6, 7])) {
    return {
      plans: [{
        ...normalized,
        repeatDays: days,
        productNames: safeProducts.map((product) => product.name),
        steps: safeSteps,
        missingItems,
      }],
      strongActiveSplitNotes: [
        `${activeProductName} was removed from a limited night routine. Add it manually on two nights only after review.`,
      ],
    };
  }

  const normalPlan = {
    ...normalized,
    repeatDays: [1, 2, 4, 5, 7],
    productNames: safeProducts.map((product) => product.name),
    steps: safeSteps,
    missingItems,
  };
  const activeProducts = dedupeOwnedProducts([...safeProducts, ...strongProducts]);
  const activePlan = {
    ...normalized,
    slotLabel: "night",
    repeatDays: [3, 6],
    productNames: activeProducts.map((product) => product.name),
    steps: [...safeSteps, ...activeSteps],
    missingItems,
    warnings: [
      ...normalized.warnings,
      "Use strong actives only 2 times per week. Do not combine with other exfoliants/retinoids.",
    ],
  };
  rejectedPlanReasons.push(`strong_active_split:${slot}:${activeProductName}`);
  return {
    plans: [normalPlan, activePlan],
    strongActiveSplitNotes: [
      `${activeProductName} is used only on Wednesday and Saturday nights. Do not combine with other strong actives.`,
    ],
  };
}

function sanitizeMissingItemsForOwnedProducts(
  missingItems: Array<{ name: string; importance: string; reason: string }>,
  products: OwnedSkinCareProduct[],
): Array<{ name: string; importance: string; reason: string }> {
  const seen = new Set<string>();
  const result: Array<{ name: string; importance: string; reason: string }> = [];
  for (const item of missingItems) {
    const name = String(item.name || "").trim().replace(/\s+/g, " ");
    if (!name) continue;
    if (matchOwnedProduct(name, products)) continue;
    const key = normalizedProductKey(name);
    if (!key || seen.has(key)) continue;
    seen.add(key);
    result.push({
      name,
      importance: String(item.importance || "important").trim() || "important",
      reason: String(item.reason || "").trim(),
    });
  }
  return result;
}

function _planHasStrongActive(plan: any, products: OwnedSkinCareProduct[]): boolean {
  return products.some(isStrongActive) ||
    plan.steps.some((step: string) => looksLikeLeaveOnStrongActive(step));
}

function _planExplicitlyAllowsDailyStrongActive(plan: any): boolean {
  const content = [
    plan.title,
    ...plan.steps,
    ...plan.productNames,
    ...plan.warnings,
  ].join(" ").toLowerCase();
  return content.includes("safe daily") ||
    content.includes("safe for daily") ||
    content.includes("safe to use daily") ||
    content.includes("daily safe") ||
    content.includes("daily use is safe");
}

function routinePlanPerDayCounts(plans: any[]): Record<string, number> {
  const counts: Record<string, number> = {
    "1": 0,
    "2": 0,
    "3": 0,
    "4": 0,
    "5": 0,
    "6": 0,
    "7": 0,
  };
  for (const plan of plans) {
    for (const day of safeRepeatDays(plan?.repeatDays)) {
      counts[String(day)] = (counts[String(day)] || 0) + 1;
    }
  }
  return counts;
}

function requiredSlotsForFrequency(desired: number): string[] {
  if (desired <= 2) return ["morning", "night"];
  if (desired === 3) return ["morning", "midday", "night"];
  return ["morning", "midday", "afternoon", "night"];
}

function slotCoverageByDay(plans: any[]): Record<string, Set<string>> {
  const coverage: Record<string, Set<string>> = {
    "1": new Set<string>(),
    "2": new Set<string>(),
    "3": new Set<string>(),
    "4": new Set<string>(),
    "5": new Set<string>(),
    "6": new Set<string>(),
    "7": new Set<string>(),
  };
  for (const plan of plans) {
    const slot = canonicalRoutineSlot(plan?.slotLabel || "");
    if (!slot) continue;
    for (const day of safeRepeatDays(plan?.repeatDays)) {
      coverage[String(day)].add(slot);
    }
  }
  return coverage;
}

function serializableSlotCoverage(coverage: Record<string, Set<string>>): Record<string, string[]> {
  const result: Record<string, string[]> = {};
  for (const day of Object.keys(coverage)) {
    result[day] = Array.from(coverage[day]).sort();
  }
  return result;
}

function routineCoverageWarnings(plans: any[], desiredApplicationsPerDay: number): string[] {
  if (plans.length === 0) return [];
  const requiredSlots = requiredSlotsForFrequency(desiredApplicationsPerDay);
  const coverage = slotCoverageByDay(plans);
  const counts = routinePlanPerDayCounts(plans);
  const warnings: string[] = [];
  const missingSlots = new Set<string>();

  for (const day of ["1", "2", "3", "4", "5", "6", "7"]) {
    for (const slot of requiredSlots) {
      if (!coverage[day].has(slot)) missingSlots.add(slot);
    }
  }

  for (const slot of missingSlots) {
    warnings.push(`ai_missing_required_slot:${slot}`);
  }

  const hasExtra = ["1", "2", "3", "4", "5", "6", "7"].some((day) =>
    (counts[day] || 0) > desiredApplicationsPerDay ||
    coverage[day].size > desiredApplicationsPerDay
  );
  if (hasExtra) warnings.push("ai_extra_daily_slot_count");

  if (missingSlots.size > 0 || hasExtra) {
    warnings.push("ai_wrong_daily_slot_count");
  }
  if (missingSlots.size > 0) {
    warnings.push("ai_returned_fewer_routines");
  }

  return warnings;
}

function rejectionReasonCounts(reasons: string[]): Record<string, number> {
  const counts: Record<string, number> = {};
  for (const reason of reasons) {
    const [kind = "unknown", slot = ""] = reason.split(":");
    const key = slot ? `${kind}:${slot}` : kind;
    counts[key] = (counts[key] || 0) + 1;
  }
  return counts;
}

function routinePlanDedupeKey(plan: any): string {
  return [
    canonicalRoutineSlot(plan?.slotLabel || ""),
    safeRepeatDays(plan?.repeatDays).join(","),
    normalizedProductKey(String(plan?.title || "")),
    stringList(plan?.productNames).map(normalizedProductKey).sort().join(","),
  ].join("|");
}

function routinePlanRichness(plan: any): number {
  return stringList(plan?.productNames).length * 100 +
    stringList(plan?.steps).length * 10 +
    (Array.isArray(plan?.missingItems) ? plan.missingItems.length : 0);
}

function dedupeRoutinePlans(plans: any[]): any[] {
  const byKey = new Map<string, any>();
  for (const plan of plans) {
    const key = routinePlanDedupeKey(plan);
    const existing = byKey.get(key);
    if (!existing || routinePlanRichness(plan) > routinePlanRichness(existing)) {
      byKey.set(key, plan);
    }
  }
  return Array.from(byKey.values());
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

function objectValue(value: unknown): Record<string, unknown> {
  return value !== null && typeof value === "object"
    ? value as Record<string, unknown>
    : {};
}

function compactProviderToken(value: unknown, fallback: string): string {
  const text = String(value ?? "")
    .trim()
    .replace(/[^a-zA-Z0-9_.-]+/g, "_")
    .slice(0, 80);
  return text || fallback;
}

async function readBoundedResponseText(
  response: Response,
  maxBytes = GEMINI_RESPONSE_MAX_BYTES,
): Promise<string> {
  const declaredLength = Number.parseInt(
    response.headers.get("content-length") || "0",
    10,
  );
  if (declaredLength > maxBytes) {
    await response.body?.cancel();
    throw new ProviderRequestError({
      errorCode: "provider_invalid_response",
      providerStatus: response.status,
      providerCode: "response_too_large",
    });
  }

  if (!response.body) return "";
  const reader = response.body.getReader();
  const chunks: Uint8Array[] = [];
  let totalBytes = 0;

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    if (!value) continue;
    totalBytes += value.byteLength;
    if (totalBytes > maxBytes) {
      await reader.cancel();
      throw new ProviderRequestError({
        errorCode: "provider_invalid_response",
        providerStatus: response.status,
        providerCode: "response_too_large",
      });
    }
    chunks.push(value);
  }

  const merged = new Uint8Array(totalBytes);
  let offset = 0;
  for (const chunk of chunks) {
    merged.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return new TextDecoder().decode(merged);
}

function classifyProviderFailure(
  providerStatus: number,
  providerCode: string,
  providerMessage: string,
): ProviderFailure {
  const normalized = `${providerCode} ${providerMessage}`.toLowerCase();
  let errorCode: ProviderFailureCode = "provider_request_failed";

  if (
    providerStatus === 401 ||
    providerStatus === 403 ||
    normalized.includes("api_key_invalid") ||
    normalized.includes("api key") ||
    normalized.includes("permission_denied") ||
    normalized.includes("unauthorized") ||
    normalized.includes("forbidden")
  ) {
    errorCode = "provider_unauthorized";
  } else if (
    providerStatus === 404 ||
    normalized.includes("not_found") ||
    normalized.includes("model not found") ||
    normalized.includes("not found for api version") ||
    normalized.includes("not supported for generatecontent")
  ) {
    errorCode = "provider_model_not_found";
  } else if (
    providerStatus === 429 ||
    normalized.includes("quota") ||
    normalized.includes("rate limit") ||
    normalized.includes("resource_exhausted")
  ) {
    errorCode = "provider_quota_exceeded";
  } else if (
    providerStatus === 408 ||
    normalized.includes("timeout") ||
    normalized.includes("deadline")
  ) {
    errorCode = "provider_timeout";
  } else if (
    providerStatus >= 500 ||
    normalized.includes("busy") ||
    normalized.includes("high demand") ||
    normalized.includes("overloaded")
  ) {
    errorCode = "provider_high_demand";
  } else if (
    providerStatus === 400 &&
    (normalized.includes("image") ||
      normalized.includes("inline") ||
      normalized.includes("mime") ||
      normalized.includes("base64") ||
      normalized.includes("payload"))
  ) {
    errorCode = "provider_invalid_image_payload";
  } else if (providerStatus === 400) {
    errorCode = "provider_invalid_request";
  }

  return {
    errorCode,
    providerStatus,
    providerCode: compactProviderToken(
      providerCode,
      `http_${providerStatus}`,
    ),
  };
}

function providerFailureFromResponse(
  response: Response,
  responseText: string,
): ProviderFailure {
  let parsed: unknown;
  try {
    parsed = responseText.trim() ? JSON.parse(responseText) : undefined;
  } catch {
    parsed = undefined;
  }

  const body = objectValue(parsed);
  const providerError = objectValue(body.error);
  const providerCode = String(
    providerError.status ??
      providerError.code ??
      body.error ??
      `http_${response.status}`,
  );
  const providerMessage = String(
    providerError.message ??
      body.message ??
      response.statusText ??
      "Provider request failed.",
  );
  return classifyProviderFailure(
    response.status,
    providerCode,
    providerMessage,
  );
}

function geminiCandidateText(providerBody: unknown): string {
  const candidates = objectValue(providerBody).candidates;
  if (!Array.isArray(candidates) || candidates.length === 0) return "";
  const content = objectValue(objectValue(candidates[0]).content);
  const parts = content.parts;
  if (!Array.isArray(parts)) return "";
  return parts
    .map((part) => objectValue(part).text)
    .filter((text): text is string => typeof text === "string")
    .join("")
    .trim();
}

function logProviderFailure(
  model: string,
  failure: ProviderFailure,
  attempt: "primary" | "fallback",
): void {
  console.warn(JSON.stringify({
    event: "skin_care_provider_request_failed",
    provider: "gemini",
    model: compactProviderToken(model, "unknown"),
    attempt,
    status: failure.providerStatus ?? null,
    providerCode: compactProviderToken(
      failure.providerCode,
      failure.errorCode,
    ),
    errorCode: failure.errorCode,
  }));
}

function providerFailureToHttpError(failure: ProviderFailure): HttpError {
  switch (failure.errorCode) {
    case "provider_unauthorized":
      return new HttpError(
        502,
        failure.errorCode,
        "AI provider authorization failed.",
      );
    case "provider_model_not_found":
      return new HttpError(
        502,
        failure.errorCode,
        "AI provider model is unavailable.",
      );
    case "provider_quota_exceeded":
      return new HttpError(
        429,
        failure.errorCode,
        "AI provider quota was exceeded.",
      );
    case "provider_timeout":
      return new HttpError(
        504,
        failure.errorCode,
        "AI provider request timed out.",
      );
    case "provider_high_demand":
      return new HttpError(
        503,
        failure.errorCode,
        "AI provider is temporarily unavailable.",
      );
    case "provider_invalid_image_payload":
      return new HttpError(
        502,
        failure.errorCode,
        "AI provider rejected the image payload.",
      );
    case "provider_invalid_request":
      return new HttpError(
        502,
        failure.errorCode,
        "AI provider rejected the request.",
      );
    case "provider_empty_candidates":
      return new HttpError(
        502,
        failure.errorCode,
        "AI provider returned no usable response.",
      );
    case "provider_invalid_response":
    case "provider_invalid_json":
      return new HttpError(
        502,
        failure.errorCode,
        "AI provider returned an invalid response.",
      );
    case "provider_unavailable":
      return new HttpError(
        503,
        failure.errorCode,
        "AI provider could not be reached.",
      );
    default:
      return new HttpError(
        502,
        "provider_request_failed",
        "AI provider request failed.",
      );
  }
}

function shouldTryFallback(failure: ProviderFailure): boolean {
  return failure.errorCode !== "provider_unauthorized" &&
    failure.errorCode !== "provider_invalid_image_payload" &&
    failure.errorCode !== "provider_invalid_request";
}

async function callGeminiWithFallback(prompt: string, imageParts: any[], env: Env): Promise<string> {
  const provider = env.AI_PROVIDER || "gemini";
  if (provider !== "gemini") {
    throw new HttpError(400, "ai_disabled", "AI provider is disabled or unsupported.");
  }

  const apiKey = requiredEnv(env.GEMINI_API_KEY, "GEMINI_API_KEY");
  const primaryModel = env.AI_MODEL?.trim() || "gemini-2.5-flash";
  const fallbackModel = env.AI_FALLBACK_MODEL?.trim() || "gemini-3.5-flash";

  const fetchGemini = async (model: string): Promise<string> => {
    const modelId = model.replace(/^models\//, "");
    const url =
      `https://generativelanguage.googleapis.com/v1beta/models/` +
      `${encodeURIComponent(modelId)}:generateContent`;
    try {
      const response = await fetch(url, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-goog-api-key": apiKey,
        },
        body: JSON.stringify({
          contents: [{ role: "user", parts: [{ text: prompt }, ...imageParts] }],
          generationConfig: {
            maxOutputTokens: 8192,
            responseMimeType: "application/json",
            temperature: 0,
          },
        }),
        signal: AbortSignal.timeout(GEMINI_REQUEST_TIMEOUT_MS),
      });
      const responseText = await readBoundedResponseText(response);
      if (!response.ok) {
        throw new ProviderRequestError(
          providerFailureFromResponse(response, responseText),
        );
      }

      let providerBody: unknown;
      try {
        providerBody = responseText.trim()
          ? JSON.parse(responseText)
          : undefined;
      } catch {
        throw new ProviderRequestError({
          errorCode: "provider_invalid_response",
          providerStatus: response.status,
          providerCode: "invalid_json",
        });
      }
      const text = geminiCandidateText(providerBody);
      if (!text) {
        throw new ProviderRequestError({
          errorCode: "provider_empty_candidates",
          providerStatus: response.status,
          providerCode: "empty_candidates",
        });
      }
      if (!parseAiJsonText(text)) {
        throw new ProviderRequestError({
          errorCode: "provider_invalid_json",
          providerStatus: response.status,
          providerCode: "invalid_model_json",
        });
      }
      return text;
    } catch (error) {
      if (error instanceof ProviderRequestError) throw error;
      const errorName = error instanceof Error
        ? error.name.toLowerCase()
        : "";
      const timedOut = errorName.includes("timeout") ||
        errorName.includes("abort");
      throw new ProviderRequestError({
        errorCode: timedOut ? "provider_timeout" : "provider_unavailable",
        providerCode: timedOut ? "request_timeout" : "fetch_failed",
      });
    }
  };

  try {
    return await fetchGemini(primaryModel);
  } catch (error) {
    const primaryFailure = error instanceof ProviderRequestError
      ? error.failure
      : {
          errorCode: "provider_unavailable" as const,
          providerCode: "unknown_failure",
        };
    logProviderFailure(primaryModel, primaryFailure, "primary");
    if (
      fallbackModel &&
      fallbackModel !== primaryModel &&
      shouldTryFallback(primaryFailure)
    ) {
      try {
        return await fetchGemini(fallbackModel);
      } catch (fallbackError) {
        const fallbackFailure = fallbackError instanceof ProviderRequestError
          ? fallbackError.failure
          : {
              errorCode: "provider_unavailable" as const,
              providerCode: "unknown_failure",
            };
        logProviderFailure(fallbackModel, fallbackFailure, "fallback");
        throw providerFailureToHttpError(fallbackFailure);
      }
    }
    throw providerFailureToHttpError(primaryFailure);
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
  const recommendationOnly = body.recommendationOnly === true;
  const countryName = String(body.countryName || "Unknown").trim() || "Unknown";
  const countryCode = String(body.countryCode || "ZZ").trim().toUpperCase() || "ZZ";
  const currencyCode = String(body.currencyCode || "USD").trim().toUpperCase() || "USD";
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
      console.warn(JSON.stringify({
        event: "skin_care_face_photo_load_failed",
        errorType: err instanceof Error ? err.name : "unknown",
      }));
    }
  }
  if (recommendationOnly && imageParts.length === 0) {
    throw new HttpError(
      400,
      body.facePhotoR2Key ? "r2_image_missing" : "invalid_skin_care_request",
      "A face photo is required before recommending products.",
    );
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
Use ONLY the owned products above. Do not merge photo and typed products. Do not invent owned products. Do not suggest CeraVe, La Roche-Posay, Paula's Choice, or any product outside the owned list unless the user owns it.
When source is photo, these are productsFromPhoto. When source is typed, these are typedProductDetails.
Pay attention to name, category, source, keyIngredients, possibleActives, usageHint, warningIfAny, and confidence.
Use product categories and ingredient/active metadata to identify product roles, especially sunscreen. A product may be sunscreen if category is sunscreen, name mentions UV/sun/SPF, ingredients/actives mention UV filters, or warnings/usage imply sun protection.
Use only owned products. Return exact owned product names in routinePlans.productNames. If product names are unclear, use the closest exact owned name from the owned list.
If at least one usable owned product exists, do not return notes only. Return routinePlans with productNames using exact owned product names and missingItems for important missing categories.
Missing moisturizer, cleanser, or sunscreen must not block generation or reduce selected routine count. If moisturizer is missing, add missingItems entry {"name":"Moisturizer","importance":"important","reason":"Helps reduce dryness/irritation after serum."} to the night routine when relevant. If sunscreen is missing, add missingItems entry {"name":"Sunscreen","importance":"important","reason":"Needed for daytime protection."} to morning/daytime routine when relevant. If cleanser is missing, add missingItems entry {"name":"Cleanser","importance":"important","reason":"Needed before applying leave-on products."} to morning/night routine when relevant.
Do not name outside products in suggestedProducts, weeklyRoutine, routinePlans.productNames, warnings, or notes for an owned-product request. missingItems may use generic category names only and must not be converted into productNames. If the user owns an incomplete set, still build the best safe limited routine from available products.
Return routinePlans.productNames using EXACT owned product names from the list above. Do not use generic names if an exact product name is available.
If at least one usable owned product exists, return the selected routine count per day.
For selected frequency, required slots are strict every day:
2/day requires exactly these slots every day: morning, night.
3/day requires exactly these slots every day: morning, midday, night.
4/day requires exactly these slots every day: morning, midday, afternoon, night.
Do not omit midday for 3/day. Do not replace midday with night active.
Missing important categories must go into missingItems.
Missing moisturizer/cleanser/sunscreen must not reduce routinePlan count.
Only return fewer routinePlans if no safe usable routine can be described.
Do not invent owned products.
productNames = exact owned product names only.
missingItems = missing important categories/products not owned.
Rinse-off cleanser/face wash may contain acids but should still be treated as cleanser, not removed as a leave-on strong active.
Leave-on strong actives include PHA/AHA/BHA toner, exfoliant, retinol, retinal, tretinoin, adapalene, peeling solution, glycolic/lactic/salicylic/mandelic leave-on products, and benzoyl peroxide.
Do not put strong actives in daily morning/midday/afternoon routines. Do not create an extra special-care block.
Put strong actives only inside the existing night slot on exactly two repeat days per week.
Strong-active split is only a variation of the night slot, not an extra slot.
Split night routine when needed: normal night without strong active repeatDays [1,2,4,5,7], active night with strong active repeatDays [3,6].
This must not increase the number of blocks on any day. For 3/day with a strong active, valid routinePlans are morning [1,2,3,4,5,6,7], midday [1,2,3,4,5,6,7], night normal [1,2,4,5,7], night active [3,6]. Per-day count remains 3.`
    : recommendationOnly
      ? `The user owns no products. Recommend 6 to 10 real, commonly available products in ${countryName} (${countryCode}) that match the user's skin details and budget.
Return exact company/brand and product names, category, a realistic estimated local price or price range in ${currencyCode}, and one short usefulness reason.
Cover the essential categories needed for a simple routine, including cleanser, moisturizer, and sunscreen when appropriate. Offer useful alternatives so the user can select products within budget.
For India, brands such as Minimalist, Mamaearth, Cetaphil, Neutrogena, Plum, and Re'equil may be considered only when the specific product is suitable. For other countries, prefer brands normally sold in that country.
Do not invent brands, products, prices, medical diagnoses, or guaranteed availability. Do not generate routinePlans in recommendation-only mode.`
      : `No owned products were provided. Build a general safe starter routine from the user's skin details.`;

  const prompt = `You are an expert dermatologist. Generate skin-care routine plans. Flutter owns all schedule placement and duration. Do NOT choose final schedule times.
Skin Type: ${body.skinType || "unknown"}
Main Problem: ${body.mainProblem || "none"}
Skin Concerns: ${JSON.stringify(stringList(body.skinConcerns))}
Budget: ${body.budget || "medium"}
Country: ${countryName} (${countryCode})
Currency: ${currencyCode}
Routine Preference: ${body.routinePreference || "balanced"}
Desired Applications Per Day: ${desiredApplicationsPerDay}
${ownedProductInstruction}
Use warningIfAny and possibleActives to avoid unsafe conflicts. E.g. avoid Retinol + AHA/BHA in the same routine block, sunscreen in morning when appropriate.
If a face photo is provided, use it to personalize the routine and suggested products.
Use slot labels from: morning, midday, afternoon, night, custom.
For 2/day prefer morning + night.
For 3/day use morning + midday + night.
For 4/day prefer morning + midday + afternoon + night.

Return ONLY a strict JSON object. routinePlans are authoritative. timelineBlocks may be included only for compatibility; Flutter will ignore all start/end times:
{
  "routinePlans": [
    {
      "slotLabel": "morning",
      "title": "Morning Skin Care",
      "steps": ["Face wash", "Vitamin C", "Sunscreen"],
      "productNames": ["Cleanser Name", "Vitamin C Serum Name", "Sunscreen Name"],
      "missingItems": [
        {
          "name": "Moisturizer",
          "importance": "important",
          "reason": "Helps reduce dryness/irritation after serum."
        }
      ],
      "warnings": [],
      "repeatDays": [1,2,3,4,5,6,7]
    }
  ],
  "recommendedProducts": [
    {
      "name": "Exact Product Name",
      "brand": "Company or Brand",
      "category": "cleanser | moisturizer | sunscreen | serum | toner | treatment",
      "estimatedPrice": "realistic local price or range",
      "currencyCode": "${currencyCode}",
      "reason": "Why it suits this user"
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
  "warnings": ["Patch test new products", "Any other warnings"]
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
  const rawWeeklyRoutine = Array.isArray(parsed.weeklyRoutine) ? parsed.weeklyRoutine : [];
  const rawSuggestedProducts = Array.isArray(parsed.suggestedProducts) ? parsed.suggestedProducts : [];
  const strongActiveSplitNotes: string[] = [];
  let routinePlans = recommendationOnly
    ? []
    : ownedProductMode
    ? rawRoutinePlans.flatMap((plan: any) => {
        const result = sanitizeOwnedRoutinePlan(plan, catalog, rejectedPlanReasons);
        strongActiveSplitNotes.push(...result.strongActiveSplitNotes);
        return result.plans;
      })
    : rawRoutinePlans
        .map(normalizeRoutinePlan)
        .filter((plan: any) => plan !== null);
  routinePlans = dedupeRoutinePlans(routinePlans);
  const warnings = stringList(parsed.warnings);
  if (routinePlans.length === 0 && !recommendationOnly) {
    warnings.push("ai_returned_no_usable_routine");
  } else {
    for (const warning of routineCoverageWarnings(routinePlans, desiredApplicationsPerDay)) {
      if (!warnings.includes(warning)) warnings.push(warning);
    }
  }
  const weeklyRoutine = ownedProductMode
    ? stringList([
        ...rawWeeklyRoutine.filter((item: any) => ownedNoteAllowed(item, catalog)).map(noteText),
        ...strongActiveSplitNotes,
      ])
    : rawWeeklyRoutine;
  const suggestedProducts = ownedProductMode
    ? stringList(rawSuggestedProducts.filter((item: any) => ownedNoteAllowed(item, catalog)).map(noteText))
    : rawSuggestedProducts;
  const recommendedProducts = normalizeRecommendedProducts(parsed.recommendedProducts)
    .map((product) => ({
      ...product,
      currencyCode: product.currencyCode || currencyCode,
    }))
    .filter((product) =>
      product.name.length > 0 &&
      product.brand.length > 0 &&
      product.category.length > 0 &&
      product.estimatedPrice.length > 0 &&
      product.currencyCode.length > 0 &&
      product.reason.length > 0
    );
  if (recommendationOnly && recommendedProducts.length === 0) {
    warnings.push("ai_returned_no_product_recommendations");
  }
  if (recommendationOnly && recommendedProducts.length > 0) {
    const categories = new Set(recommendedProducts.map((product) => {
      const category = product.category.toLowerCase();
      if (category === "face wash") return "cleanser";
      if (category === "moisturiser") return "moisturizer";
      if (category === "spf") return "sunscreen";
      return category;
    }));
    for (const requiredCategory of ["cleanser", "moisturizer", "sunscreen"]) {
      if (!categories.has(requiredCategory)) {
        warnings.push(`ai_missing_product_category:${requiredCategory}`);
      }
    }
  }
  const perDayRoutineCounts = routinePlanPerDayCounts(routinePlans);
  const perDaySlotCoverage = serializableSlotCoverage(slotCoverageByDay(routinePlans));
  console.log(JSON.stringify({
    event: "skin_care_routine_generated",
    productInputSource: activeSource,
    ownedProductCount: ownedProducts.length,
    rawPlanCount: rawRoutinePlans.length,
    sanitizedPlanCount: routinePlans.length,
    rejectionReasonCounts: rejectionReasonCounts(rejectedPlanReasons),
    strongActiveSplitCount: strongActiveSplitNotes.length,
    perDayRoutineCounts,
    perDaySlotCoverage,
    recommendedProductCount: recommendedProducts.length,
  }));
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
          missingItems: Array.isArray(plan?.missingItems) ? plan.missingItems : [],
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
    recommendedProducts,
    suggestedProducts,
    warnings,
    rejectedPlanReasons,
    strongActiveSplitNotes,
    perDayRoutineCounts,
    perDaySlotCoverage
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
      console.error(JSON.stringify({
        event: "skin_care_unexpected_error",
        errorType: error instanceof Error ? error.name : "unknown",
      }));
      return jsonResponse(request, env, { error: "internal_error", message: "An unexpected error occurred" }, 500);
    }
  }
} satisfies ExportedHandler<Env>;
