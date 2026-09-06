import { beforeEach, describe, expect, test, vi } from "vitest";

vi.mock("jose", () => ({
  createRemoteJWKSet: vi.fn(() => ({})),
  jwtVerify: vi.fn(async () => ({
    payload: { sub: "uid-1", email_verified: true },
  })),
}));

import { jwtVerify } from "jose";
import worker from "./index";

type StoredObject = {
  body?: string;
  contentType?: string;
  size?: number;
  onRead?: () => void;
};

type FetchCall = {
  url: string;
  body: any;
};

function hasInlineImagePart(call: FetchCall): boolean {
  const parts = call.body?.contents?.[0]?.parts;
  return Array.isArray(parts) && parts.some((part: any) => part?.inlineData);
}

class MockR2Object {
  httpMetadata?: { contentType?: string };
  readonly size: number;
  private readonly body: string;
  private readonly onRead?: () => void;

  constructor(object: StoredObject = {}) {
    this.body = object.body ?? "image";
    this.size = object.size ?? new TextEncoder().encode(this.body).byteLength;
    this.onRead = object.onRead;
    this.httpMetadata =
      object.contentType === undefined
        ? {}
        : { contentType: object.contentType };
  }

  async arrayBuffer(): Promise<ArrayBuffer> {
    this.onRead?.();
    const bytes = new TextEncoder().encode(this.body);
    return bytes.buffer.slice(
      bytes.byteOffset,
      bytes.byteOffset + bytes.byteLength,
    ) as ArrayBuffer;
  }
}

function makeEnv(objects: Record<string, StoredObject> = {}) {
  return {
    FIREBASE_PROJECT_ID: "test-project",
    AI_PROVIDER: "gemini",
    AI_MODEL: "gemini-test",
    GEMINI_API_KEY: "gemini-key",
    ALLOWED_ORIGINS: "https://staging.example.test",
    UPLOAD_BUCKET: {
      get: vi.fn(async (key: string) => {
        if (!(key in objects)) return null;
        return new MockR2Object(objects[key]);
      }),
    },
  };
}

function authHeaders(): HeadersInit {
  return {
    Authorization: "Bearer test-token",
    "Content-Type": "application/json",
  };
}

function jsonRequest(path: string, body: unknown): Request {
  return new Request(`https://skin-care-worker.test${path}`, {
    method: "POST",
    headers: authHeaders(),
    body: JSON.stringify(body),
  });
}

function stubGemini(text: string, calls: FetchCall[] = []) {
  vi.stubGlobal(
    "fetch",
    vi.fn(async (url: string, init?: RequestInit) => {
      calls.push({
        url,
        body: JSON.parse(String(init?.body ?? "{}")),
      });
      return new Response(
        JSON.stringify({
          candidates: [{ content: { parts: [{ text }] } }],
        }),
        { status: 200, headers: { "Content-Type": "application/json" } },
      );
    }),
  );
}

function stubGeminiResponses(
  responses: Array<{ status: number; body: unknown }>,
  calls: FetchCall[] = [],
) {
  let index = 0;
  vi.stubGlobal(
    "fetch",
    vi.fn(async (url: string, init?: RequestInit) => {
      calls.push({
        url,
        body: JSON.parse(String(init?.body ?? "{}")),
      });
      const next = responses[Math.min(index, responses.length - 1)];
      index += 1;
      return new Response(JSON.stringify(next.body), {
        status: next.status,
        headers: { "Content-Type": "application/json" },
      });
    }),
  );
}

function geminiSuccess(text: string) {
  return {
    status: 200,
    body: {
      candidates: [{ content: { parts: [{ text }] } }],
    },
  };
}

function installAbortTimeoutRecorder(recorded: number[]) {
  const original = AbortSignal.timeout;
  vi.spyOn(AbortSignal, "timeout").mockImplementation((ms: number) => {
    recorded.push(ms);
    return original.call(AbortSignal, ms);
  });
}

function richProductPayload(size: number) {
  return {
    productsFromPhoto: [
      {
        name: "UV Aqua Gel",
        category: "sunscreen",
        keyIngredients: ["water", "glycerin", "zinc oxide", "x".repeat(size)],
        possibleActives: ["UV filters"],
        usageHint: "Reapply in daylight.",
        warningIfAny: "",
        confidence: "medium",
      },
    ],
    typedProductNames: ["Gentle Cleanser"],
    desiredApplicationsPerDay: 3,
  };
}

function fiveTypedProducts() {
  return [
    { name: "Beardo Detan Face Wash", category: "cleanser", source: "typed" },
    { name: "Minimalist SPF 50", category: "sunscreen", source: "typed" },
    { name: "Minimalist Vitamin C", category: "vitamin_c_serum", source: "typed" },
    { name: "Minimalist Alpha Arbutin", category: "treatment_serum", source: "typed" },
    { name: "Minimalist PHA Toner", category: "exfoliant", source: "typed" },
  ];
}

function completeIndianRecommendationProducts() {
  const product = (
    name: string,
    brand: string,
    category: string,
    estimatedPrice: string,
  ) => ({
    name,
    brand,
    category,
    estimatedPrice,
    currencyCode: "INR",
    reason: `Useful ${category.replaceAll("_", " ")} option`,
  });
  return [
    product("Gentle Cleanser", "Minimalist", "cleanser", "₹299"),
    product("Kind to Skin Face Wash", "Simple", "cleanser", "₹325"),
    product("Oil-Free Moisturizer", "Minimalist", "moisturizer", "₹349"),
    product("Hydro Boost Water Gel", "Neutrogena", "moisturizer", "₹499"),
    product("Ultra Light Sunscreen SPF 50", "Minimalist", "sunscreen", "₹399"),
    product("Oxybenzone Free Sunscreen SPF 50", "Re'equil", "sunscreen", "₹495"),
    product("10% Vitamin C Face Serum", "Minimalist", "vitamin_c_serum", "₹699"),
    product("Vitamin C 15% Face Serum", "Plum", "vitamin_c_serum", "₹790"),
    product("5% Niacinamide Face Serum", "Minimalist", "treatment_serum", "₹599"),
    product("2% Alpha Arbutin Face Serum", "Minimalist", "treatment_serum", "₹549"),
  ];
}

describe("Skin-care Worker", () => {
  beforeEach(() => {
    vi.restoreAllMocks();
    vi.unstubAllGlobals();
    vi.mocked(jwtVerify).mockReset().mockResolvedValue({
      payload: { sub: "uid-1", email_verified: true },
    } as never);
  });

  test("health endpoint returns service metadata", async () => {
    const response = await worker.fetch(
      new Request("https://skin-care-worker.test/health"),
      makeEnv() as any,
    );
    const json = await response.json() as any;

    expect(response.status).toBe(200);
    expect(json.ok).toBe(true);
    expect(json.service).toBe("skin-care-worker");
  });

  test("CORS echoes only an explicitly allowed origin", async () => {
    const allowed = await worker.fetch(
      new Request("https://skin-care-worker.test/health", {
        headers: { Origin: "https://staging.example.test" },
      }),
      makeEnv() as any,
    );
    const rejected = await worker.fetch(
      new Request("https://skin-care-worker.test/health", {
        headers: { Origin: "https://unapproved.example.test" },
      }),
      makeEnv() as any,
    );

    expect(allowed.headers.get("Access-Control-Allow-Origin")).toBe(
      "https://staging.example.test",
    );
    expect(allowed.headers.get("Vary")).toBe("Origin");
    expect(rejected.headers.get("Access-Control-Allow-Origin")).toBeNull();
  });

  test("protected endpoints reject missing authentication safely", async () => {
    const response = await worker.fetch(
      new Request(
        "https://skin-care-worker.test/v1/skin-care/products/analyze",
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ productPhotos: ["photo.jpg"] }),
        },
      ),
      makeEnv() as any,
    );
    const json = await response.json() as any;

    expect(response.status).toBe(401);
    expect(json.error).toBe("unauthorized");
    expect(json.message).toBe("Missing or malformed token");
  });

  test("malformed Authorization is rejected before token verification", async () => {
    const response = await worker.fetch(
      new Request(
        "https://skin-care-worker.test/v1/skin-care/products/analyze",
        {
          method: "POST",
          headers: {
            Authorization: "Basic token",
            "Content-Type": "application/json",
          },
          body: JSON.stringify({ productPhotos: ["photo.jpg"] }),
        },
      ),
      makeEnv() as any,
    );
    const json = await response.json() as any;

    expect(response.status).toBe(401);
    expect(json.error).toBe("unauthorized");
    expect(jwtVerify).not.toHaveBeenCalled();
  });

  test("invalid or expired token returns a safe 401", async () => {
    vi.mocked(jwtVerify).mockRejectedValue(
      new Error("expired verifier internal detail"),
    );
    const response = await worker.fetch(
      jsonRequest("/v1/skin-care/products/analyze", {
        productPhotos: ["photo.jpg"],
      }),
      makeEnv() as any,
    );
    const text = await response.text();

    expect(response.status).toBe(401);
    expect(JSON.parse(text).error).toBe("unauthorized");
    expect(text).not.toContain("internal detail");
  });

  test("malformed request JSON is rejected safely", async () => {
    const response = await worker.fetch(
      new Request(
        "https://skin-care-worker.test/v1/skin-care/routine/generate",
        {
          method: "POST",
          headers: authHeaders(),
          body: "{",
        },
      ),
      makeEnv() as any,
    );
    const json = await response.json() as any;

    expect(response.status).toBe(400);
    expect(json.error).toBe("invalid_json");
  });

  test("valid JSON that is not an object is rejected as invalid_json", async () => {
    const response = await worker.fetch(
      jsonRequest("/v1/skin-care/routine/generate", null),
      makeEnv() as any,
    );
    const json = await response.json() as any;

    expect(response.status).toBe(400);
    expect(json.error).toBe("invalid_json");
  });

  test("unsupported image content type returns unsupported_content_type", async () => {
    const key = "users/uid-1/onboarding/skin_products/products.gif";
    const response = await worker.fetch(
      jsonRequest("/v1/skin-care/products/analyze", {
        productPhotos: [key],
      }),
      makeEnv({ [key]: { contentType: "image/gif" } }) as any,
    );
    const json = await response.json() as any;

    expect(response.status).toBe(415);
    expect(json.error).toBe("unsupported_content_type");
  });

  test("product recommendations require a face photo", async () => {
    const response = await worker.fetch(
      jsonRequest("/v1/skin-care/routine/generate", {
        recommendationOnly: true,
        skinType: "oily",
        mainProblem: "pimples",
        budget: "low",
        countryCode: "IN",
        countryName: "India",
        currencyCode: "INR",
      }),
      makeEnv() as any,
    );
    const json = await response.json() as any;

    expect(response.status).toBe(400);
    expect(json.error).toBe("invalid_skin_care_request");
  });

  test("product recommendations are branded, priced, and location-aware", async () => {
    const key = "users/uid-1/onboarding/skin_face/face.jpg";
    const calls: FetchCall[] = [];
    const products = completeIndianRecommendationProducts();
    stubGemini(JSON.stringify({
      routinePlans: [],
      recommendedProducts: products,
      suggestedProducts: [],
      weeklyRoutine: [],
      warnings: [],
    }), calls);

    const response = await worker.fetch(
      jsonRequest("/v1/skin-care/routine/generate", {
        recommendationOnly: true,
        facePhotoR2Key: key,
        skinType: "oily",
        skinConcerns: ["pimples", "oiliness"],
        mainProblem: "pimples",
        budget: "low",
        countryCode: "IN",
        countryName: "India",
        currencyCode: "INR",
      }),
      makeEnv({ [key]: { contentType: "image/jpeg" } }) as any,
    );
    const json = await response.json() as any;

    expect(response.status).toBe(200);
    expect(json.routinePlans).toEqual([]);
    expect(json.recommendedProducts).toEqual(products);
    for (const category of ["cleanser", "moisturizer", "sunscreen"]) {
      expect(
        json.recommendedProducts.filter((item: any) => item.category === category),
      ).toHaveLength(2);
      expect(json.warnings).not.toContain(`ai_missing_product_category:${category}`);
    }
    const promptBody = JSON.stringify(calls[0].body);
    expect(promptBody).toContain("India (IN)");
    expect(promptBody).not.toContain("Minimalist");
    expect(promptBody).not.toContain("Mamaearth");
    expect(promptBody).toContain("vitamin_c_serum");
    expect(promptBody).toContain("treatment_serum");
    expect(hasInlineImagePart(calls[0])).toBe(true);
    expect(calls[0].body.generationConfig.maxOutputTokens).toBe(3072);
  });

  test("incomplete recommendations are repaired and common categories are canonicalized", async () => {
    const key = "users/uid-1/onboarding/skin_face/face.jpg";
    const calls: FetchCall[] = [];
    const repairProducts = completeIndianRecommendationProducts().slice(1);
    repairProducts[1] = {
      ...repairProducts[1],
      category: "Daily Hydrator",
    };
    repairProducts[3] = {
      ...repairProducts[3],
      category: "UV Sun Protection",
    };
    stubGeminiResponses([
      geminiSuccess(JSON.stringify({
        recommendedProducts: [
          {
            name: "Kind to Skin Refreshing Facial Wash",
            brand: "Simple",
            category: "Facial Wash",
            estimatedPrice: "₹325",
            currencyCode: "INR",
            reason: "A gentle daily wash",
          },
        ],
        warnings: [],
      })),
      geminiSuccess(JSON.stringify({
        recommendedProducts: repairProducts,
        warnings: [],
      })),
    ], calls);

    const response = await worker.fetch(
      jsonRequest("/v1/skin-care/routine/generate", {
        recommendationOnly: true,
        facePhotoR2Key: key,
        skinType: "combination",
        skinConcerns: ["pimples", "dark_spots"],
        budget: "medium",
        countryCode: "IN",
        countryName: "India",
        currencyCode: "INR",
      }),
      makeEnv({ [key]: { contentType: "image/jpeg" } }) as any,
    );
    const json = await response.json() as any;

    expect(response.status).toBe(200);
    for (const category of ["cleanser", "moisturizer", "sunscreen"]) {
      expect(
        json.recommendedProducts.filter((item: any) => item.category === category)
          .length,
      ).toBeGreaterThanOrEqual(2);
    }
    expect(json.warnings).toContain("ai_product_recommendations_repaired");
    expect(calls).toHaveLength(2);
    expect(JSON.stringify(calls[1].body)).toContain("Missing essential categories");
    expect(JSON.stringify(calls[1].body)).not.toContain("vitamin_c_serum");
    expect(JSON.stringify(calls[1].body)).not.toContain("treatment_serum");
    expect(hasInlineImagePart(calls[0])).toBe(true);
    expect(hasInlineImagePart(calls[1])).toBe(false);
    expect(calls[1].body.generationConfig.maxOutputTokens).toBe(1536);
  });

  test("incomplete product recommendations are removed before returning", async () => {
    const key = "users/uid-1/onboarding/skin_face/face.jpg";
    stubGemini(JSON.stringify({
      routinePlans: [],
      recommendedProducts: [
        {
          brand: "Brand without a product",
          category: "cleanser",
          estimatedPrice: "299",
          currencyCode: "INR",
          reason: "Missing an exact name",
        },
        {
          name: "Product without a price",
          brand: "Example Brand",
          category: "sunscreen",
          currencyCode: "INR",
          reason: "Missing price",
        },
      ],
      warnings: [],
    }));

    const response = await worker.fetch(
      jsonRequest("/v1/skin-care/routine/generate", {
        recommendationOnly: true,
        facePhotoR2Key: key,
        skinType: "oily",
        skinConcerns: ["pimples"],
        budget: "low",
        countryCode: "IN",
        countryName: "India",
        currencyCode: "INR",
      }),
      makeEnv({ [key]: { contentType: "image/jpeg" } }) as any,
    );
    const json = await response.json() as any;

    expect(response.status).toBe(200);
    expect(json.recommendedProducts).toEqual([]);
    expect(json.warnings).toContain("ai_returned_no_product_recommendations");
  });

  test("recommendation repair failure is identified without reporting routine success", async () => {
    const key = "users/uid-1/onboarding/skin_face/face.jpg";
    const calls: FetchCall[] = [];
    stubGeminiResponses([
      geminiSuccess(JSON.stringify({
        recommendedProducts: [{
          name: "Gentle Wash",
          brand: "Example",
          category: "cleanser",
          estimatedPrice: "₹300",
          currencyCode: "INR",
          reason: "Gentle cleanser",
        }],
        warnings: [],
      })),
      {
        status: 503,
        body: { error: { status: "UNAVAILABLE", message: "high demand" } },
      },
    ], calls);

    const response = await worker.fetch(
      jsonRequest("/v1/skin-care/routine/generate", {
        recommendationOnly: true,
        facePhotoR2Key: key,
        skinType: "oily",
        skinConcerns: ["pimples"],
        budget: "low",
        countryCode: "IN",
        countryName: "India",
        currencyCode: "INR",
      }),
      makeEnv({ [key]: { contentType: "image/jpeg" } }) as any,
    );
    const json = await response.json() as any;

    expect(response.status).toBe(200);
    expect(json.routinePlans).toEqual([]);
    expect(json.warnings).toContain(
      "ai_recommendation_repair_failed:provider_high_demand",
    );
    expect(calls).toHaveLength(3);
    expect(hasInlineImagePart(calls[1])).toBe(false);
    expect(hasInlineImagePart(calls[2])).toBe(false);
  });

  test("missing metadata with .jpg key is accepted", async () => {
    const key = "users/uid-1/onboarding/skin_products/products.jpg";
    const calls: FetchCall[] = [];
    stubGemini(JSON.stringify({
      products: [{ name: "UV Aqua Gel", category: "sunscreen" }],
      warnings: [],
    }), calls);

    const response = await worker.fetch(
      jsonRequest("/v1/skin-care/products/analyze", {
        productPhotos: [key],
      }),
      makeEnv({ [key]: {} }) as any,
    );
    const json = await response.json() as any;

    expect(response.status).toBe(200);
    expect(json.products[0].name).toBe("UV Aqua Gel");
    expect(calls[0].body.generationConfig.maxOutputTokens).toBe(2048);
  });

  test.each([
    ["jpg", "image/jpeg"],
    ["jpeg", "image/jpeg"],
    ["png", "image/png"],
    ["webp", "image/webp"],
  ])("product analysis accepts the supported .%s format", async (extension, contentType) => {
    const key = `users/uid-1/onboarding/skin_products/products.${extension}`;
    stubGemini(JSON.stringify({
      products: [{ name: "Daily Product", category: "cleanser" }],
      warnings: [],
    }));

    const response = await worker.fetch(
      jsonRequest("/v1/skin-care/products/analyze", {
        productPhotos: [key],
      }),
      makeEnv({ [key]: { contentType } }) as any,
    );

    expect(response.status).toBe(200);
  });

  test("product analysis invalid JSON returns provider_invalid_json", async () => {
    const key = "users/uid-1/onboarding/skin_products/products.jpg";
    stubGemini("not-json");

    const response = await worker.fetch(
      jsonRequest("/v1/skin-care/products/analyze", {
        productPhotos: [key],
      }),
      makeEnv({ [key]: { contentType: "image/jpeg" } }) as any,
    );
    const json = await response.json() as any;

    expect(response.status).toBe(502);
    expect(json.error).toBe("provider_invalid_json");
  });

  test("product analysis image above 15MB returns image_payload_too_large", async () => {
    const key = "users/uid-1/onboarding/skin_products/products.jpg";

    const response = await worker.fetch(
      jsonRequest("/v1/skin-care/products/analyze", {
        productPhotos: [key],
      }),
      makeEnv({
        [key]: { contentType: "image/jpeg", body: "x".repeat(15 * 1024 * 1024 + 1) },
      }) as any,
    );
    const json = await response.json() as any;

    expect(response.status).toBe(413);
    expect(json.error).toBe("image_payload_too_large");
  });

  test("oversize image metadata is rejected before reading the body", async () => {
    const key = "users/uid-1/onboarding/skin_products/products.jpg";
    const onRead = vi.fn();
    const response = await worker.fetch(
      jsonRequest("/v1/skin-care/products/analyze", {
        productPhotos: [key],
      }),
      makeEnv({
        [key]: {
          contentType: "image/jpeg",
          size: 15 * 1024 * 1024 + 1,
          onRead,
        },
      }) as any,
    );

    expect(response.status).toBe(413);
    expect(onRead).not.toHaveBeenCalled();
  });

  test("product analysis accepts exactly one image", async () => {
    const key = "users/uid-1/onboarding/skin_products/products.jpg";
    const zero = await worker.fetch(
      jsonRequest("/v1/skin-care/products/analyze", { productPhotos: [] }),
      makeEnv() as any,
    );
    const multiple = await worker.fetch(
      jsonRequest("/v1/skin-care/products/analyze", {
        productPhotos: [key, key],
      }),
      makeEnv({ [key]: { contentType: "image/jpeg" } }) as any,
    );

    expect(zero.status).toBe(400);
    expect(multiple.status).toBe(400);
    expect((await multiple.json() as any).error).toBe("too_many_photos");
  });

  test.each([
    "users/other/onboarding/skin_products/products.jpg",
    "users/uid-1/onboarding/skin_products/../products.jpg",
    "users/uid-1/onboarding//skin_products.jpg",
    "users\\uid-1\\onboarding\\skin_products\\products.jpg",
    "users/uid-1/onboarding/skin_products/not safe.jpg",
  ])("invalid R2 key is rejected: %s", async (key) => {
    const response = await worker.fetch(
      jsonRequest("/v1/skin-care/products/analyze", {
        productPhotos: [key],
      }),
      makeEnv() as any,
    );
    const json = await response.json() as any;

    expect(response.status).toBe(403);
    expect(json.error).toBe("forbidden");
  });

  test.each(["gif", "heic", "heif", "pdf"])(
    "unsupported .%s product image is rejected",
    async (extension) => {
      const key = `users/uid-1/onboarding/skin_products/products.${extension}`;
      const response = await worker.fetch(
        jsonRequest("/v1/skin-care/products/analyze", {
          productPhotos: [key],
        }),
        makeEnv() as any,
      );
      const json = await response.json() as any;

      expect(response.status).toBe(415);
      expect(json.error).toBe("unsupported_content_type");
    },
  );

  test("missing Gemini key returns internal error", async () => {
    const key = "users/uid-1/onboarding/skin_products/products.jpg";
    const env = makeEnv({ [key]: { contentType: "image/jpeg" } }) as any;
    delete env.GEMINI_API_KEY;

    const response = await worker.fetch(
      jsonRequest("/v1/skin-care/products/analyze", {
        productPhotos: [key],
      }),
      env,
    );
    const json = await response.json() as any;

    expect(response.status).toBe(500);
    expect(json.error).toBe("internal_error");
  });

  test("provider authorization failure is preserved and does not retry another model", async () => {
    const calls: FetchCall[] = [];
    stubGeminiResponses([
      {
        status: 403,
        body: {
          error: {
            code: 403,
            status: "PERMISSION_DENIED",
            message: "API key not valid.",
          },
        },
      },
    ], calls);
    const env = {
      ...makeEnv(),
      AI_FALLBACK_MODEL: "gemini-fallback",
    };

    const response = await worker.fetch(
      jsonRequest("/v1/skin-care/routine/generate", {
        typedProductNames: ["Cleanser"],
        desiredApplicationsPerDay: 2,
      }),
      env as any,
    );
    const json = await response.json() as any;

    expect(response.status).toBe(502);
    expect(json.error).toBe("provider_unauthorized");
    expect(calls).toHaveLength(1);
  });

  test("primary recommendation succeeds without fallback", async () => {
    const key = "users/uid-1/onboarding/skin_face/face.jpg";
    const calls: FetchCall[] = [];
    stubGemini(JSON.stringify({
      recommendedProducts: completeIndianRecommendationProducts(),
      warnings: [],
    }), calls);

    const response = await worker.fetch(
      jsonRequest("/v1/skin-care/routine/generate", {
        recommendationOnly: true,
        facePhotoR2Key: key,
        skinType: "oily",
        skinConcerns: ["pimples"],
        budget: "low",
        countryCode: "IN",
        countryName: "India",
        currencyCode: "INR",
      }),
      {
        ...makeEnv({ [key]: { contentType: "image/jpeg" } }),
        AI_FALLBACK_MODEL: "gemini-fallback",
      } as any,
    );

    expect(response.status).toBe(200);
    expect(calls).toHaveLength(1);
    expect(calls[0].url).toContain("gemini-test");
  });

  test("primary high demand falls back once and succeeds", async () => {
    const calls: FetchCall[] = [];
    stubGeminiResponses([
      {
        status: 503,
        body: { error: { status: "UNAVAILABLE", message: "high demand" } },
      },
      geminiSuccess(JSON.stringify({
        routinePlans: [
          {
            slotLabel: "morning",
            title: "Morning",
            steps: ["Cleanse"],
            productNames: ["Cleanser"],
          },
        ],
      })),
    ], calls);

    const response = await worker.fetch(
      jsonRequest("/v1/skin-care/routine/generate", {
        typedProductNames: ["Cleanser"],
        desiredApplicationsPerDay: 2,
      }),
      {
        ...makeEnv(),
        AI_FALLBACK_MODEL: "gemini-fallback",
      } as any,
    );

    expect(response.status).toBe(200);
    expect(calls).toHaveLength(2);
    expect(calls[0].url).toContain("gemini-test");
    expect(calls[1].url).toContain("gemini-fallback");
  });

  test("primary cannot consume the fallback reserved attempt budget", async () => {
    const calls: FetchCall[] = [];
    const timeoutMs: number[] = [];
    let now = 1_000_000;
    vi.spyOn(Date, "now").mockImplementation(() => now);
    installAbortTimeoutRecorder(timeoutMs);
    stubGeminiResponses([
      {
        status: 503,
        body: { error: { status: "UNAVAILABLE", message: "high demand" } },
      },
      geminiSuccess(JSON.stringify({
        routinePlans: [
          {
            slotLabel: "morning",
            title: "Morning",
            steps: ["Cleanse"],
            productNames: ["Cleanser"],
          },
        ],
      })),
    ], calls);
    vi.mocked(fetch).mockImplementation(async (input: RequestInfo | URL, init?: RequestInit) => {
      const url = String(input);
      calls.push({ url, body: JSON.parse(String(init?.body ?? "{}")) });
      const response = calls.length === 1
        ? {
            status: 503,
            body: { error: { status: "UNAVAILABLE", message: "high demand" } },
          }
        : geminiSuccess(JSON.stringify({
            routinePlans: [
              {
                slotLabel: "morning",
                title: "Morning",
                steps: ["Cleanse"],
                productNames: ["Cleanser"],
              },
            ],
          }));
      if (calls.length === 1) now += 24_000;
      return new Response(JSON.stringify(response.body), {
        status: response.status,
        headers: { "Content-Type": "application/json" },
      });
    });

    const response = await worker.fetch(
      jsonRequest("/v1/skin-care/routine/generate", {
        typedProductNames: ["Cleanser"],
        desiredApplicationsPerDay: 2,
      }),
      {
        ...makeEnv(),
        AI_FALLBACK_MODEL: "gemini-fallback",
      } as any,
    );

    expect(response.status).toBe(200);
    expect(timeoutMs[0]).toBeLessThanOrEqual(25_000);
    expect(timeoutMs[1]).toBe(20_000);
    expect(calls).toHaveLength(2);
  });

  test("both models high demand fail bounded without retry storm", async () => {
    const calls: FetchCall[] = [];
    stubGeminiResponses([
      {
        status: 503,
        body: { error: { status: "UNAVAILABLE", message: "high demand" } },
      },
      {
        status: 503,
        body: { error: { status: "UNAVAILABLE", message: "still high demand" } },
      },
    ], calls);

    const response = await worker.fetch(
      jsonRequest("/v1/skin-care/routine/generate", {
        typedProductNames: ["Cleanser"],
        desiredApplicationsPerDay: 2,
      }),
      {
        ...makeEnv(),
        AI_FALLBACK_MODEL: "gemini-fallback",
      } as any,
    );
    const json = await response.json() as any;

    expect(response.status).toBe(503);
    expect(json.error).toBe("provider_high_demand");
    expect(json.stage).toBe("routine_generation");
    expect(json.requestId).toMatch(/^[a-f0-9-]{8}$/i);
    expect(calls).toHaveLength(2);
  });

  test("provider quota failure is preserved after fallback also fails", async () => {
    const calls: FetchCall[] = [];
    stubGeminiResponses([
      {
        status: 429,
        body: {
          error: {
            code: 429,
            status: "RESOURCE_EXHAUSTED",
            message: "Quota exceeded.",
          },
        },
      },
      {
        status: 429,
        body: {
          error: {
            code: 429,
            status: "RESOURCE_EXHAUSTED",
            message: "Quota exceeded.",
          },
        },
      },
    ], calls);
    const env = {
      ...makeEnv(),
      AI_FALLBACK_MODEL: "gemini-fallback",
    };

    const response = await worker.fetch(
      jsonRequest("/v1/skin-care/routine/generate", {
        typedProductNames: ["Cleanser"],
        desiredApplicationsPerDay: 2,
      }),
      env as any,
    );
    const json = await response.json() as any;

    expect(response.status).toBe(429);
    expect(json.error).toBe("provider_quota_exceeded");
    expect(calls).toHaveLength(2);
  });

  test("fallback succeeds when the primary model is unavailable", async () => {
    const calls: FetchCall[] = [];
    stubGeminiResponses([
      {
        status: 404,
        body: {
          error: {
            code: 404,
            status: "NOT_FOUND",
            message: "Model not found for API version.",
          },
        },
      },
      geminiSuccess(JSON.stringify({
        routinePlans: [
          {
            slotLabel: "morning",
            title: "Morning",
            steps: ["Cleanse"],
            productNames: ["Cleanser"],
          },
        ],
      })),
    ], calls);
    const env = {
      ...makeEnv(),
      AI_FALLBACK_MODEL: "gemini-fallback",
    };

    const response = await worker.fetch(
      jsonRequest("/v1/skin-care/routine/generate", {
        typedProductNames: ["Cleanser"],
        desiredApplicationsPerDay: 2,
      }),
      env as any,
    );
    const json = await response.json() as any;

    expect(response.status).toBe(200);
    expect(json.routinePlans).toHaveLength(1);
    expect(calls).toHaveLength(2);
    expect(calls[1].url).toContain("gemini-fallback");
  });

  test("fallback succeeds when the primary model returns invalid JSON", async () => {
    const calls: FetchCall[] = [];
    stubGeminiResponses([
      geminiSuccess("not-json"),
      geminiSuccess(JSON.stringify({
        routinePlans: [
          {
            slotLabel: "night",
            title: "Night",
            steps: ["Cleanse"],
            productNames: ["Cleanser"],
          },
        ],
      })),
    ], calls);
    const env = {
      ...makeEnv(),
      AI_FALLBACK_MODEL: "gemini-fallback",
    };

    const response = await worker.fetch(
      jsonRequest("/v1/skin-care/routine/generate", {
        typedProductNames: ["Cleanser"],
        desiredApplicationsPerDay: 2,
      }),
      env as any,
    );
    const json = await response.json() as any;

    expect(response.status).toBe(200);
    expect(json.routinePlans).toHaveLength(1);
    expect(json.routinePlans[0].slotLabel).toBe("night");
    expect(calls).toHaveLength(2);
  });

  test("empty provider candidates return provider_empty_candidates", async () => {
    stubGeminiResponses([
      {
        status: 200,
        body: { candidates: [] },
      },
    ]);

    const response = await worker.fetch(
      jsonRequest("/v1/skin-care/routine/generate", {
        typedProductNames: ["Cleanser"],
        desiredApplicationsPerDay: 2,
      }),
      makeEnv() as any,
    );
    const json = await response.json() as any;

    expect(response.status).toBe(502);
    expect(json.error).toBe("provider_empty_candidates");
  });

  test("provider network timeout returns provider_timeout", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn(async () => {
        throw new DOMException("Timed out", "TimeoutError");
      }),
    );

    const response = await worker.fetch(
      jsonRequest("/v1/skin-care/routine/generate", {
        typedProductNames: ["Cleanser"],
        desiredApplicationsPerDay: 2,
      }),
      makeEnv() as any,
    );
    const json = await response.json() as any;

    expect(response.status).toBe(504);
    expect(json.error).toBe("provider_timeout");
  });

  test("provider invalid JSON maps to safe error", async () => {
    stubGemini("not-json");

    const response = await worker.fetch(
      jsonRequest("/v1/skin-care/routine/generate", {
        typedProductNames: ["Cleanser"],
        desiredApplicationsPerDay: 2,
      }),
      makeEnv() as any,
    );
    const json = await response.json() as any;

    expect(response.status).toBe(502);
    expect(json.error).toBe("provider_invalid_json");
  });

  test("routine generate accepts rich productsFromPhoto above 8KB", async () => {
    const calls: FetchCall[] = [];
    stubGemini(JSON.stringify({
      routinePlans: [
        {
          slotLabel: "morning",
          title: "Morning Skin Care",
          steps: ["Cleanse", "Apply sunscreen"],
          productNames: ["Gentle Cleanser", "UV Aqua Gel"],
        },
        {
          slotLabel: "midday",
          title: "Midday Skin Care",
          steps: ["Reapply sunscreen"],
          productNames: ["UV Aqua Gel"],
        },
        {
          slotLabel: "night",
          title: "Night Skin Care",
          steps: ["Cleanse"],
          productNames: ["Gentle Cleanser"],
        },
      ],
    }), calls);

    const response = await worker.fetch(
      jsonRequest("/v1/skin-care/routine/generate", richProductPayload(9000)),
      makeEnv() as any,
    );
    const json = await response.json() as any;

    expect(response.status).toBe(200);
    expect(json.routinePlans).toHaveLength(2);
    expect(json.routinePlans[0].productNames).toEqual(["UV Aqua Gel"]);
    expect(json.routinePlans[1].productNames).toEqual(["UV Aqua Gel"]);
    expect(json.warnings).toContain("ai_returned_fewer_routines");
    expect(calls[0].body.contents[0].parts[0].text).toContain("UV Aqua");
  });

  test("routine generate rejects JSON above 64KB", async () => {
    const response = await worker.fetch(
      jsonRequest("/v1/skin-care/routine/generate", richProductPayload(70 * 1024)),
      makeEnv() as any,
    );
    const json = await response.json() as any;

    expect(response.status).toBe(413);
    expect(json.error).toBe("json_payload_too_large");
  });

  test("routine generate returns routinePlans and compatibility timeline", async () => {
    const calls: FetchCall[] = [];
    stubGemini(JSON.stringify({
      routinePlans: [
        {
          slotLabel: "morning",
          title: "Morning Skin Care",
          steps: ["Face wash", "Apply sunscreen"],
          productNames: ["Gentle Cleanser", "UV Aqua Gel"],
        },
      ],
      warnings: [],
    }), calls);

    const response = await worker.fetch(
      jsonRequest("/v1/skin-care/routine/generate", {
        productsFromPhoto: [
          {
            name: "Gentle Cleanser",
            category: "cleanser",
          },
          {
            name: "UV Aqua Gel",
            category: "sunscreen",
            possibleActives: ["UV filters"],
          },
        ],
        desiredApplicationsPerDay: 2,
      }),
      makeEnv() as any,
    );
    const json = await response.json() as any;

    expect(response.status).toBe(200);
    expect(json.routinePlans).toHaveLength(1);
    expect(json.warnings).toContain("ai_returned_fewer_routines");
    expect(json.timelineBlocks).toHaveLength(1);
    expect(json.timelineBlocks[0].endMinute - json.timelineBlocks[0].startMinute).toBe(15);
    expect(calls[0].body.generationConfig.maxOutputTokens).toBe(4096);
  });

  test("typed source prompt uses typedProductDetails and excludes photo products", async () => {
    const calls: FetchCall[] = [];
    stubGemini(JSON.stringify({
      routinePlans: [
        {
          slotLabel: "morning",
          title: "Morning",
          steps: ["Apply sunscreen"],
          productNames: ["Minimalist SPF 50"],
        },
      ],
    }), calls);

    const response = await worker.fetch(
      jsonRequest("/v1/skin-care/routine/generate", {
        productInputSource: "typed",
        typedProductDetails: [
          {
            name: "Minimalist SPF 50",
            category: "sunscreen",
            source: "typed",
          },
        ],
        productsFromPhoto: [{ name: "Inactive Photo Cleanser" }],
        desiredApplicationsPerDay: 2,
      }),
      makeEnv() as any,
    );

    const prompt = calls[0].body.contents[0].parts[0].text as string;
    expect(response.status).toBe(200);
    expect(prompt).toContain("Active Product Source: typed");
    expect(prompt).toContain("Minimalist SPF 50");
    expect(prompt).not.toContain("Inactive Photo Cleanser");
  });

  test("text-only owned products do not get fallback plans when AI returns notes only", async () => {
    stubGemini(JSON.stringify({
      suggestedProducts: ["Missing moisturizer"],
      weeklyRoutine: [],
      warnings: ["No moisturizer detected"],
      routinePlans: [],
    }));

    const response = await worker.fetch(
      jsonRequest("/v1/skin-care/routine/generate", {
        productInputSource: "typed",
        typedProductDetails: fiveTypedProducts(),
        desiredApplicationsPerDay: 2,
      }),
      makeEnv() as any,
    );
    const json = await response.json() as any;

    expect(response.status).toBe(200);
    expect(json.routinePlans).toHaveLength(0);
    expect(json.weeklyRoutine).toEqual([]);
    expect(json.warnings.join(" ").toLowerCase()).toContain("moisturizer");
    expect(json.warnings).toContain("ai_returned_no_usable_routine");
  });

  test("text-only owned products preserve exact sanitized AI routine names", async () => {
    stubGemini(JSON.stringify({
      suggestedProducts: [],
      weeklyRoutine: [
        "Use Minimalist PHA Toner 1-2 times per week at night. Do not combine with other strong actives.",
      ],
      warnings: ["No moisturizer detected"],
      routinePlans: [
        {
          slotLabel: "morning",
          title: "Morning Skin Care",
          steps: [
            "Cleanse face",
            "Apply Minimalist Vitamin C",
            "Apply Minimalist SPF 50",
          ],
          productNames: [
            "Beardo Detan Face Wash",
            "Minimalist Vitamin C",
            "Minimalist SPF 50",
          ],
        },
        {
          slotLabel: "night",
          title: "Night Skin Care",
          steps: [
            "Cleanse face",
            "Apply Minimalist Alpha Arbutin",
            "Add moisturizer after serum when available",
          ],
          productNames: [
            "Beardo Detan Face Wash",
            "Minimalist Alpha Arbutin",
          ],
          missingItems: [
            {
              name: "Moisturizer",
              importance: "important",
              reason: "Helps reduce dryness/irritation after serum.",
            },
          ],
        },
      ],
    }));

    const response = await worker.fetch(
      jsonRequest("/v1/skin-care/routine/generate", {
        productInputSource: "typed",
        typedProductDetails: fiveTypedProducts(),
        desiredApplicationsPerDay: 2,
      }),
      makeEnv() as any,
    );
    const json = await response.json() as any;

    expect(response.status).toBe(200);
    expect(json.routinePlans).toHaveLength(2);
    expect(json.routinePlans[0].productNames).toEqual([
      "Beardo Detan Face Wash",
      "Minimalist Vitamin C",
      "Minimalist SPF 50",
    ]);
    expect(json.routinePlans[1].productNames).toEqual([
      "Beardo Detan Face Wash",
      "Minimalist Alpha Arbutin",
    ]);
    expect(json.routinePlans[1].missingItems).toEqual([
      {
        name: "Moisturizer",
        importance: "important",
        reason: "Helps reduce dryness/irritation after serum.",
      },
    ]);
    expect(json.routinePlans[1].productNames).not.toContain("Moisturizer");
    expect(json.weeklyRoutine).toContain(
      "Use Minimalist PHA Toner 1-2 times per week at night. Do not combine with other strong actives.",
    );
  });

  test("selected Vitamin C and treatment serums are used and never returned as missing", async () => {
    stubGemini(JSON.stringify({
      suggestedProducts: [],
      weeklyRoutine: [],
      warnings: [],
      routinePlans: [
        {
          slotLabel: "morning",
          title: "Morning Skin Care",
          steps: [
            "Cleanse",
            "Apply Vitamin C serum",
            "Apply moisturizer",
            "Apply sunscreen",
          ],
          productNames: [
            "Beardo Detan Face Wash",
            "Minimalist Vitamin C",
            "Minimalist SPF 50",
          ],
          missingItems: [{
            name: "Vitamin C Serum (important, missing)",
            importance: "important",
            reason: "Brightening support",
          }],
        },
        {
          slotLabel: "night",
          title: "Night Skin Care",
          steps: ["Cleanse", "Apply treatment serum"],
          productNames: [
            "Beardo Detan Face Wash",
            "Minimalist Alpha Arbutin",
          ],
          missingItems: [{
            name: "Treatment Serum (e.g., Niacinamide or Alpha Arbutin)",
            importance: "important",
            reason: "Concern support",
          }],
        },
      ],
    }));

    const response = await worker.fetch(
      jsonRequest("/v1/skin-care/routine/generate", {
        productInputSource: "typed",
        typedProductDetails: fiveTypedProducts(),
        desiredApplicationsPerDay: 2,
      }),
      makeEnv() as any,
    );
    const json = await response.json() as any;

    expect(response.status).toBe(200);
    expect(json.routinePlans).toHaveLength(2);
    expect(json.routinePlans[0].productNames).toContain("Minimalist Vitamin C");
    expect(json.routinePlans[1].productNames).toContain(
      "Minimalist Alpha Arbutin",
    );
    expect(json.routinePlans.flatMap((plan: any) => plan.missingItems)).toEqual(
      [],
    );
  });

  test("missing moisturizer warning does not make owned-product routine empty", async () => {
    stubGemini(JSON.stringify({
      suggestedProducts: ["No moisturizer detected"],
      weeklyRoutine: [],
      warnings: ["No moisturizer detected"],
      routinePlans: [
        {
          slotLabel: "morning",
          title: "Morning SPF",
          steps: ["Cleanse", "Apply Daily SPF 50"],
          productNames: ["Gentle Cleanser", "Daily SPF 50"],
        },
        {
          slotLabel: "night",
          title: "Night Cleanse",
          steps: ["Cleanse", "Add moisturizer after serum when available"],
          productNames: ["Gentle Cleanser"],
          missingItems: [
            {
              name: "Moisturizer",
              importance: "important",
              reason: "Helps reduce dryness/irritation after serum.",
            },
          ],
        },
      ],
    }));

    const response = await worker.fetch(
      jsonRequest("/v1/skin-care/routine/generate", {
        productInputSource: "typed",
        typedProductDetails: [
          { name: "Gentle Cleanser", category: "cleanser", source: "typed" },
          { name: "Daily SPF 50", category: "sunscreen", source: "typed" },
        ],
        desiredApplicationsPerDay: 2,
      }),
      makeEnv() as any,
    );
    const json = await response.json() as any;

    expect(response.status).toBe(200);
    expect(json.routinePlans.length).toBeGreaterThanOrEqual(2);
    expect(json.routinePlans.flatMap((plan: any) => plan.productNames)).toEqual(
      expect.arrayContaining(["Gentle Cleanser", "Daily SPF 50"]),
    );
    expect(json.routinePlans[1].missingItems).toEqual([
      {
        name: "Moisturizer",
        importance: "important",
        reason: "Helps reduce dryness/irritation after serum.",
      },
    ]);
    expect(json.routinePlans.flatMap((plan: any) => plan.productNames))
      .not.toContain("Moisturizer");
    expect(json.warnings.join(" ").toLowerCase()).toContain("moisturizer");
  });

  test("missing sunscreen and cleanser stay missingItems, not owned products", async () => {
    stubGemini(JSON.stringify({
      suggestedProducts: [],
      weeklyRoutine: [],
      warnings: ["No sunscreen or cleanser detected"],
      routinePlans: [
        {
          slotLabel: "morning",
          title: "Morning Serum",
          steps: ["Apply Hydrating Serum", "Add sunscreen when available"],
          productNames: ["Hydrating Serum"],
          missingItems: [
            {
              name: "Sunscreen",
              importance: "important",
              reason: "Needed for daytime protection.",
            },
            {
              name: "Cleanser",
              importance: "important",
              reason: "Needed before applying leave-on products.",
            },
          ],
        },
      ],
    }));

    const response = await worker.fetch(
      jsonRequest("/v1/skin-care/routine/generate", {
        productInputSource: "typed",
        typedProductDetails: [
          { name: "Hydrating Serum", category: "serum", source: "typed" },
        ],
        desiredApplicationsPerDay: 2,
      }),
      makeEnv() as any,
    );
    const json = await response.json() as any;

    expect(response.status).toBe(200);
    expect(json.routinePlans).toHaveLength(1);
    expect(json.routinePlans[0].productNames).toEqual(["Hydrating Serum"]);
    expect(json.routinePlans[0].missingItems.map((item: any) => item.name))
      .toEqual([
        "Sunscreen",
        "Cleanser",
      ]);
    expect(json.routinePlans[0].productNames).not.toContain("Sunscreen");
    expect(json.routinePlans[0].productNames).not.toContain("Cleanser");
  });

  test("owned-product sanitizer infers products from steps when productNames are missing", async () => {
    stubGemini(JSON.stringify({
      suggestedProducts: [],
      weeklyRoutine: [],
      warnings: [],
      routinePlans: [
        {
          slotLabel: "morning",
          title: "Morning Skin Care",
          steps: ["Cleanse face", "Apply sunscreen"],
          productNames: [],
        },
      ],
    }));

    const response = await worker.fetch(
      jsonRequest("/v1/skin-care/routine/generate", {
        productInputSource: "typed",
        typedProductDetails: [
          { name: "Gentle Cleanser", category: "cleanser", source: "typed" },
          { name: "Daily SPF 50", category: "sunscreen", source: "typed" },
        ],
        desiredApplicationsPerDay: 2,
      }),
      makeEnv() as any,
    );
    const json = await response.json() as any;

    expect(response.status).toBe(200);
    expect(json.routinePlans).toHaveLength(1);
    expect(json.routinePlans[0].productNames).toEqual([
      "Gentle Cleanser",
      "Daily SPF 50",
    ]);
    expect(json.rejectedPlanReasons).toContain(
      "missing_product_names_inferred:morning",
    );
  });

  test("owned-product sanitizer maps common product-name variations", async () => {
    stubGemini(JSON.stringify({
      suggestedProducts: [],
      weeklyRoutine: [],
      warnings: [],
      routinePlans: [
        {
          slotLabel: "morning",
          title: "Morning Skin Care",
          steps: ["Vitamin C serum", "Apply sunscreen"],
          productNames: ["Vitamin C serum", "Minimalist SPF 50 Sunscreen"],
        },
        {
          slotLabel: "midday",
          title: "Midday Skin Care",
          steps: ["Reapply sunscreen"],
          productNames: ["sunscreen"],
        },
        {
          slotLabel: "night",
          title: "Night Skin Care",
          steps: ["Face wash", "Alpha Arbutin serum"],
          productNames: ["face wash", "Alpha Arbutin serum"],
        },
      ],
    }));

    const response = await worker.fetch(
      jsonRequest("/v1/skin-care/routine/generate", {
        productInputSource: "typed",
        typedProductDetails: fiveTypedProducts(),
        desiredApplicationsPerDay: 3,
      }),
      makeEnv() as any,
    );
    const json = await response.json() as any;

    expect(response.status).toBe(200);
    expect(json.routinePlans).toHaveLength(3);
    expect(json.routinePlans[0].productNames).toEqual([
      "Minimalist Vitamin C",
      "Minimalist SPF 50",
    ]);
    expect(json.routinePlans[1].productNames).toEqual(["Minimalist SPF 50"]);
    expect(json.routinePlans[2].productNames).toEqual([
      "Beardo Detan Face Wash",
      "Minimalist Alpha Arbutin",
    ]);
  });

  test("routine generate warns when 3/day is missing required midday slot", async () => {
    stubGemini(JSON.stringify({
      suggestedProducts: [],
      weeklyRoutine: [],
      warnings: [],
      routinePlans: [
        {
          slotLabel: "morning",
          title: "Morning Skin Care",
          steps: ["Cleanse face", "Apply Minimalist SPF 50"],
          productNames: ["Beardo Detan Face Wash", "Minimalist SPF 50"],
          repeatDays: [1, 2, 3, 4, 5, 6, 7],
        },
        {
          slotLabel: "night",
          title: "Night Skin Care",
          steps: ["Cleanse face", "Apply Minimalist Alpha Arbutin"],
          productNames: [
            "Beardo Detan Face Wash",
            "Minimalist Alpha Arbutin",
          ],
          repeatDays: [1, 2, 4, 5, 7],
        },
        {
          slotLabel: "night",
          title: "Active Night Skin Care",
          steps: [
            "Cleanse face",
            "Apply Minimalist Alpha Arbutin",
            "Apply Minimalist PHA Toner",
          ],
          productNames: [
            "Beardo Detan Face Wash",
            "Minimalist Alpha Arbutin",
            "Minimalist PHA Toner",
          ],
          repeatDays: [3, 6],
        },
      ],
    }));

    const response = await worker.fetch(
      jsonRequest("/v1/skin-care/routine/generate", {
        productInputSource: "typed",
        typedProductDetails: fiveTypedProducts(),
        desiredApplicationsPerDay: 3,
      }),
      makeEnv() as any,
    );
    const json = await response.json() as any;

    expect(response.status).toBe(200);
    expect(json.routinePlans).toHaveLength(3);
    expect(json.warnings).toContain("ai_missing_required_slot:midday");
    expect(json.warnings).toContain("ai_wrong_daily_slot_count");
    expect(json.warnings).toContain("ai_returned_fewer_routines");
  });

  test("routine generate warns when 4/day is missing required afternoon slot", async () => {
    stubGemini(JSON.stringify({
      suggestedProducts: [],
      weeklyRoutine: [],
      warnings: [],
      routinePlans: [
        {
          slotLabel: "morning",
          title: "Morning Skin Care",
          steps: ["Apply Minimalist SPF 50"],
          productNames: ["Minimalist SPF 50"],
          repeatDays: [1, 2, 3, 4, 5, 6, 7],
        },
        {
          slotLabel: "midday",
          title: "Midday Skin Care",
          steps: ["Reapply Minimalist SPF 50"],
          productNames: ["Minimalist SPF 50"],
          repeatDays: [1, 2, 3, 4, 5, 6, 7],
        },
        {
          slotLabel: "night",
          title: "Night Skin Care",
          steps: ["Cleanse face"],
          productNames: ["Beardo Detan Face Wash"],
          repeatDays: [1, 2, 3, 4, 5, 6, 7],
        },
      ],
    }));

    const response = await worker.fetch(
      jsonRequest("/v1/skin-care/routine/generate", {
        productInputSource: "typed",
        typedProductDetails: fiveTypedProducts(),
        desiredApplicationsPerDay: 4,
      }),
      makeEnv() as any,
    );
    const json = await response.json() as any;

    expect(response.status).toBe(200);
    expect(json.warnings).toContain("ai_missing_required_slot:afternoon");
    expect(json.warnings).toContain("ai_wrong_daily_slot_count");
  });

  test("owned-product sanitizer removes morning strong active without creating active night variant", async () => {
    stubGemini(JSON.stringify({
      suggestedProducts: [],
      weeklyRoutine: [],
      warnings: [],
      routinePlans: [
        {
          slotLabel: "morning",
          title: "Morning Skin Care",
          steps: [
            "Cleanse face",
            "Apply Minimalist Vitamin C",
            "Apply Minimalist SPF 50",
            "Apply Minimalist PHA Toner",
          ],
          productNames: [
            "Beardo Detan Face Wash",
            "Minimalist Vitamin C",
            "Minimalist SPF 50",
            "Minimalist PHA Toner",
          ],
          repeatDays: [1, 2, 3, 4, 5, 6, 7],
        },
        {
          slotLabel: "midday",
          title: "Midday Skin Care",
          steps: ["Reapply Minimalist SPF 50"],
          productNames: ["Minimalist SPF 50"],
          repeatDays: [1, 2, 3, 4, 5, 6, 7],
        },
        {
          slotLabel: "night",
          title: "Night Skin Care",
          steps: ["Cleanse face", "Apply Minimalist Alpha Arbutin"],
          productNames: [
            "Beardo Detan Face Wash",
            "Minimalist Alpha Arbutin",
          ],
          repeatDays: [1, 2, 3, 4, 5, 6, 7],
        },
      ],
    }));

    const response = await worker.fetch(
      jsonRequest("/v1/skin-care/routine/generate", {
        productInputSource: "typed",
        typedProductDetails: fiveTypedProducts(),
        desiredApplicationsPerDay: 3,
      }),
      makeEnv() as any,
    );
    const json = await response.json() as any;
    const morning = json.routinePlans.find((plan: any) => plan.slotLabel === "morning");

    expect(response.status).toBe(200);
    expect(json.routinePlans).toHaveLength(3);
    expect(morning.repeatDays).toEqual([1, 2, 3, 4, 5, 6, 7]);
    expect(morning.productNames).toEqual([
      "Beardo Detan Face Wash",
      "Minimalist Vitamin C",
      "Minimalist SPF 50",
    ]);
    expect(morning.productNames).not.toContain("Minimalist PHA Toner");
    expect(morning.steps).toEqual([
      "Cleanse face",
      "Apply Minimalist Vitamin C",
      "Apply Minimalist SPF 50",
    ]);
    expect(
      json.routinePlans.some((plan: any) =>
        plan.slotLabel === "night" &&
        JSON.stringify(plan.repeatDays) === JSON.stringify([3, 6]) &&
        plan.productNames.includes("Minimalist PHA Toner")),
    ).toBe(false);
    expect(json.rejectedPlanReasons).toContain(
      "strong_active_removed_from_non_night:morning:Minimalist PHA Toner",
    );
    expect(json.weeklyRoutine).toContain(
      "Minimalist PHA Toner was removed from the daily morning routine and moved to special-care notes. Add it manually on two nights only after review.",
    );
    expect(json.warnings).not.toContain("ai_returned_fewer_routines");
  });

  test("owned-product sanitizer removes midday strong active without creating active night variant", async () => {
    stubGemini(JSON.stringify({
      suggestedProducts: [],
      weeklyRoutine: [],
      warnings: [],
      routinePlans: [
        {
          slotLabel: "morning",
          title: "Morning Skin Care",
          steps: ["Apply Minimalist SPF 50"],
          productNames: ["Minimalist SPF 50"],
          repeatDays: [1, 2, 3, 4, 5, 6, 7],
        },
        {
          slotLabel: "midday",
          title: "Midday Skin Care",
          steps: [
            "Reapply Minimalist SPF 50",
            "Apply Minimalist PHA Toner",
          ],
          productNames: ["Minimalist SPF 50", "Minimalist PHA Toner"],
          repeatDays: [1, 2, 3, 4, 5, 6, 7],
        },
        {
          slotLabel: "night",
          title: "Night Skin Care",
          steps: ["Cleanse face"],
          productNames: ["Beardo Detan Face Wash"],
          repeatDays: [1, 2, 3, 4, 5, 6, 7],
        },
      ],
    }));

    const response = await worker.fetch(
      jsonRequest("/v1/skin-care/routine/generate", {
        productInputSource: "typed",
        typedProductDetails: fiveTypedProducts(),
        desiredApplicationsPerDay: 3,
      }),
      makeEnv() as any,
    );
    const json = await response.json() as any;
    const midday = json.routinePlans.find((plan: any) => plan.slotLabel === "midday");

    expect(response.status).toBe(200);
    expect(json.routinePlans).toHaveLength(3);
    expect(midday.repeatDays).toEqual([1, 2, 3, 4, 5, 6, 7]);
    expect(midday.productNames).toEqual(["Minimalist SPF 50"]);
    expect(midday.steps).toEqual(["Reapply Minimalist SPF 50"]);
    expect(
      json.routinePlans.some((plan: any) =>
        plan.slotLabel === "night" &&
        JSON.stringify(plan.repeatDays) === JSON.stringify([3, 6]) &&
        plan.productNames.includes("Minimalist PHA Toner")),
    ).toBe(false);
    expect(json.rejectedPlanReasons).toContain(
      "strong_active_removed_from_non_night:midday:Minimalist PHA Toner",
    );
  });

  test("owned-product sanitizer does not double-split existing night variants", async () => {
    stubGemini(JSON.stringify({
      suggestedProducts: [],
      weeklyRoutine: [],
      warnings: [],
      routinePlans: [
        {
          slotLabel: "morning",
          title: "Morning Skin Care",
          steps: ["Apply Minimalist SPF 50"],
          productNames: ["Minimalist SPF 50"],
          repeatDays: [1, 2, 3, 4, 5, 6, 7],
        },
        {
          slotLabel: "midday",
          title: "Midday Skin Care",
          steps: ["Reapply Minimalist SPF 50"],
          productNames: ["Minimalist SPF 50"],
          repeatDays: [1, 2, 3, 4, 5, 6, 7],
        },
        {
          slotLabel: "night",
          title: "Night Skin Care",
          steps: ["Cleanse face", "Apply Minimalist Alpha Arbutin"],
          productNames: [
            "Beardo Detan Face Wash",
            "Minimalist Alpha Arbutin",
          ],
          repeatDays: [1, 2, 4, 5, 7],
        },
        {
          slotLabel: "night",
          title: "Night Skin Care",
          steps: [
            "Cleanse face",
            "Apply Minimalist Alpha Arbutin",
            "Apply Minimalist PHA Toner",
          ],
          productNames: [
            "Beardo Detan Face Wash",
            "Minimalist Alpha Arbutin",
            "Minimalist PHA Toner",
          ],
          repeatDays: [3, 6],
        },
      ],
    }));

    const response = await worker.fetch(
      jsonRequest("/v1/skin-care/routine/generate", {
        productInputSource: "typed",
        typedProductDetails: fiveTypedProducts(),
        desiredApplicationsPerDay: 3,
      }),
      makeEnv() as any,
    );
    const json = await response.json() as any;
    const normalNights = json.routinePlans.filter(
      (plan: any) =>
        plan.slotLabel === "night" &&
        JSON.stringify(plan.repeatDays) === JSON.stringify([1, 2, 4, 5, 7]),
    );
    const activeNights = json.routinePlans.filter(
      (plan: any) =>
        plan.slotLabel === "night" &&
        JSON.stringify(plan.repeatDays) === JSON.stringify([3, 6]),
    );

    expect(response.status).toBe(200);
    expect(normalNights).toHaveLength(1);
    expect(activeNights).toHaveLength(1);
    expect(activeNights[0].productNames).toContain("Minimalist PHA Toner");
    expect(json.warnings).not.toContain("ai_extra_daily_slot_count");
    expect(json.warnings).not.toContain("ai_returned_fewer_routines");
  });

  test("owned-product sanitizer keeps already-limited active night without creating normal variant", async () => {
    stubGemini(JSON.stringify({
      suggestedProducts: [],
      weeklyRoutine: [],
      warnings: [],
      routinePlans: [
        {
          slotLabel: "night",
          title: "Active Night Skin Care",
          steps: [
            "Cleanse face",
            "Apply Minimalist PHA Toner",
          ],
          productNames: [
            "Beardo Detan Face Wash",
            "Minimalist PHA Toner",
          ],
          repeatDays: [3, 6],
        },
      ],
    }));

    const response = await worker.fetch(
      jsonRequest("/v1/skin-care/routine/generate", {
        productInputSource: "typed",
        typedProductDetails: fiveTypedProducts(),
        desiredApplicationsPerDay: 2,
      }),
      makeEnv() as any,
    );
    const json = await response.json() as any;

    expect(response.status).toBe(200);
    expect(json.routinePlans).toHaveLength(1);
    expect(json.routinePlans[0].repeatDays).toEqual([3, 6]);
    expect(json.routinePlans[0].productNames).toContain("Minimalist PHA Toner");
    expect(
      json.routinePlans.some((plan: any) =>
        JSON.stringify(plan.repeatDays) === JSON.stringify([1, 2, 4, 5, 7])),
    ).toBe(false);
  });

  test("owned-product sanitizer splits daily night strong active into night variants", async () => {
    stubGemini(JSON.stringify({
      suggestedProducts: [],
      weeklyRoutine: [],
      warnings: [],
      routinePlans: [
        {
          slotLabel: "morning",
          title: "Morning Skin Care",
          steps: [
            "Cleanse face",
            "Apply Minimalist Vitamin C",
            "Apply Minimalist SPF 50",
          ],
          productNames: [
            "Beardo Detan Face Wash",
            "Minimalist Vitamin C",
            "Minimalist SPF 50",
          ],
          repeatDays: [1, 2, 3, 4, 5, 6, 7],
        },
        {
          slotLabel: "midday",
          title: "Midday Skin Care",
          steps: ["Reapply Minimalist SPF 50"],
          productNames: ["Minimalist SPF 50"],
          repeatDays: [1, 2, 3, 4, 5, 6, 7],
        },
        {
          slotLabel: "night",
          title: "Night Skin Care",
          steps: [
            "Cleanse face",
            "Apply Minimalist Alpha Arbutin",
            "Apply Minimalist PHA Toner",
          ],
          productNames: [
            "Beardo Detan Face Wash",
            "Minimalist Alpha Arbutin",
            "Minimalist PHA Toner",
          ],
          missingItems: [
            {
              name: "Moisturizer",
              importance: "important",
              reason: "Helps reduce dryness/irritation after serum.",
            },
          ],
          repeatDays: [1, 2, 3, 4, 5, 6, 7],
        },
      ],
    }));

    const response = await worker.fetch(
      jsonRequest("/v1/skin-care/routine/generate", {
        productInputSource: "typed",
        typedProductDetails: fiveTypedProducts(),
        desiredApplicationsPerDay: 3,
      }),
      makeEnv() as any,
    );
    const json = await response.json() as any;
    const normalNight = json.routinePlans.find(
      (plan: any) =>
        plan.slotLabel === "night" &&
        JSON.stringify(plan.repeatDays) === JSON.stringify([1, 2, 4, 5, 7]),
    );
    const activeNight = json.routinePlans.find(
      (plan: any) =>
        plan.slotLabel === "night" &&
        JSON.stringify(plan.repeatDays) === JSON.stringify([3, 6]),
    );

    expect(response.status).toBe(200);
    expect(json.routinePlans).toHaveLength(4);
    expect(normalNight).toBeTruthy();
    expect(activeNight).toBeTruthy();
    expect(normalNight!.productNames).toEqual([
      "Beardo Detan Face Wash",
      "Minimalist Alpha Arbutin",
    ]);
    expect(normalNight!.productNames).not.toContain("Minimalist PHA Toner");
    expect(activeNight!.productNames).toEqual([
      "Beardo Detan Face Wash",
      "Minimalist Alpha Arbutin",
      "Minimalist PHA Toner",
    ]);
    expect(activeNight!.warnings).toContain(
      "Use strong actives only 2 times per week. Do not combine with other exfoliants/retinoids.",
    );
    expect(activeNight!.missingItems.map((item: any) => item.name)).toEqual([
      "Moisturizer",
    ]);
    expect(json.weeklyRoutine).toContain(
      "Minimalist PHA Toner is used only on Wednesday and Saturday nights. Do not combine with other strong actives.",
    );
    expect(json.rejectedPlanReasons).toContain(
      "strong_active_split:night:Minimalist PHA Toner",
    );
    expect(json.warnings).not.toContain("ai_returned_fewer_routines");
  });

  test("warning text mentioning sunscreen does not turn cleanser and serum into sunscreen", async () => {
    stubGemini(JSON.stringify({
      routinePlans: [
        {
          slotLabel: "morning",
          title: "Morning Skin Care",
          steps: ["Apply sunscreen"],
          productNames: ["Sunscreen SPF 50 PA++++"],
          repeatDays: [1, 2, 3, 4, 5, 6, 7],
        },
        {
          slotLabel: "night",
          title: "Night Skin Care",
          steps: ["Cleanse face", "Apply Alpha Arbutin serum"],
          productNames: [
            "De-Tan Face Wash Coffee Detox",
            "Alpha Arbutin 02% Face Serum",
          ],
          repeatDays: [1, 2, 3, 4, 5, 6, 7],
        },
      ],
    }));

    const response = await worker.fetch(
      jsonRequest("/v1/skin-care/routine/generate", {
        productInputSource: "photo",
        productsFromPhoto: [
          {
            name: "De-Tan Face Wash Coffee Detox",
            category: "cleanser",
            keyIngredients: ["Glycolic Acid", "Lactic Acid"],
            warningIfAny:
              "Contains AHAs. Always use a broad-spectrum sunscreen during the day.",
          },
          {
            name: "Alpha Arbutin 02% Face Serum",
            category: "serum",
            possibleActives: ["Alpha Arbutin"],
            warningIfAny:
              "Do not combine with benzoyl peroxide. Always use sunscreen.",
          },
          {
            name: "Sunscreen SPF 50 PA++++",
            category: "sunscreen",
            possibleActives: ["UV filters"],
          },
        ],
        desiredApplicationsPerDay: 2,
      }),
      makeEnv() as any,
    );
    const json = await response.json() as any;
    const night = json.routinePlans.find(
      (plan: any) => plan.slotLabel === "night",
    );

    expect(response.status).toBe(200);
    expect(night).toBeTruthy();
    expect(night.productNames).toEqual([
      "De-Tan Face Wash Coffee Detox",
      "Alpha Arbutin 02% Face Serum",
    ]);
    expect(json.rejectedPlanReasons.join("|")).not.toContain(
      "night_sunscreen",
    );
    expect(json.rejectedPlanReasons.join("|")).not.toContain(
      "strong_active",
    );
  });

  test("rinse-off acid cleanser is not removed as a strong active", async () => {
    stubGemini(JSON.stringify({
      suggestedProducts: [],
      weeklyRoutine: [],
      warnings: [],
      routinePlans: [
        {
          slotLabel: "morning",
          title: "Morning Skin Care",
          steps: [
            "Cleanse with Beardo De-Tan Face Wash Coffee Detox glycolic lactic acid",
            "Apply Minimalist SPF 50",
          ],
          productNames: [
            "Beardo De-Tan Face Wash Coffee Detox",
            "Minimalist SPF 50",
          ],
          repeatDays: [1, 2, 3, 4, 5, 6, 7],
        },
        {
          slotLabel: "night",
          title: "Night Skin Care",
          steps: ["Cleanse with Beardo De-Tan Face Wash Coffee Detox"],
          productNames: ["Beardo De-Tan Face Wash Coffee Detox"],
          repeatDays: [1, 2, 3, 4, 5, 6, 7],
        },
      ],
    }));

    const response = await worker.fetch(
      jsonRequest("/v1/skin-care/routine/generate", {
        productInputSource: "typed",
        typedProductDetails: [
          {
            name: "Beardo De-Tan Face Wash Coffee Detox",
            category: "cleanser",
            keyIngredients: ["glycolic acid", "lactic acid"],
            source: "typed",
          },
          { name: "Minimalist SPF 50", category: "sunscreen", source: "typed" },
        ],
        desiredApplicationsPerDay: 2,
      }),
      makeEnv() as any,
    );
    const json = await response.json() as any;

    expect(response.status).toBe(200);
    expect(json.routinePlans).toHaveLength(2);
    expect(json.routinePlans[0].productNames).toContain(
      "Beardo De-Tan Face Wash Coffee Detox",
    );
    expect(json.routinePlans[1].productNames).toContain(
      "Beardo De-Tan Face Wash Coffee Detox",
    );
    expect(json.rejectedPlanReasons.join("|")).not.toContain(
      "strong_active",
    );
  });

  test("owned-product sanitizer rejects strong-active-only plans without fallback routines", async () => {
    stubGemini(JSON.stringify({
      suggestedProducts: [],
      weeklyRoutine: [],
      warnings: [],
      routinePlans: [
        {
          slotLabel: "night",
          title: "PHA Night",
          steps: ["Apply Minimalist PHA Toner"],
          productNames: ["Minimalist PHA Toner"],
          repeatDays: [1, 2, 3, 4, 5, 6, 7],
        },
      ],
    }));

    const response = await worker.fetch(
      jsonRequest("/v1/skin-care/routine/generate", {
        productInputSource: "typed",
        typedProductDetails: fiveTypedProducts(),
        desiredApplicationsPerDay: 2,
      }),
      makeEnv() as any,
    );
    const json = await response.json() as any;

    expect(response.status).toBe(200);
    expect(json.routinePlans).toEqual([]);
    expect(json.warnings).toContain("ai_returned_no_usable_routine");
    expect(json.rejectedPlanReasons).toContain(
      "unsafe_no_safe_products:night:PHA Night",
    );
  });

  test("owned-product sanitizer rejects non-night strong-active-only plans without fallback routines", async () => {
    stubGemini(JSON.stringify({
      suggestedProducts: [],
      weeklyRoutine: [],
      warnings: [],
      routinePlans: [
        {
          slotLabel: "morning",
          title: "Morning PHA",
          steps: ["Apply Minimalist PHA Toner"],
          productNames: ["Minimalist PHA Toner"],
          repeatDays: [1, 2, 3, 4, 5, 6, 7],
        },
      ],
    }));

    const response = await worker.fetch(
      jsonRequest("/v1/skin-care/routine/generate", {
        productInputSource: "typed",
        typedProductDetails: fiveTypedProducts(),
        desiredApplicationsPerDay: 2,
      }),
      makeEnv() as any,
    );
    const json = await response.json() as any;

    expect(response.status).toBe(200);
    expect(json.routinePlans).toEqual([]);
    expect(json.warnings).toContain("ai_returned_no_usable_routine");
    expect(json.rejectedPlanReasons).toContain(
      "unsafe_no_safe_products:morning:Morning PHA",
    );
  });

  test("owned-product routine rejects clearly outside products", async () => {
    stubGemini(JSON.stringify({
      suggestedProducts: ["Try CeraVe Moisturizing Cream"],
      weeklyRoutine: [],
      warnings: [],
      routinePlans: [
        {
          slotLabel: "night",
          title: "Outside Product",
          steps: ["Apply moisturizer"],
          productNames: ["CeraVe Moisturizing Cream"],
        },
      ],
    }));

    const response = await worker.fetch(
      jsonRequest("/v1/skin-care/routine/generate", {
        productInputSource: "typed",
        typedProductDetails: [
          { name: "Daily SPF 50", category: "sunscreen", source: "typed" },
        ],
        desiredApplicationsPerDay: 2,
      }),
      makeEnv() as any,
    );
    const json = await response.json() as any;

    expect(response.status).toBe(200);
    expect(json.routinePlans).toEqual([]);
    expect(json.suggestedProducts).toEqual([]);
    expect(json.warnings).toContain("ai_returned_no_usable_routine");
    expect(json.rejectedPlanReasons.join("|")).toContain("product_mismatch");
  });

  test("three per day with limited owned products returns two safe plans and ai_returned_fewer_routines warning", async () => {
    stubGemini(JSON.stringify({
      suggestedProducts: [],
      weeklyRoutine: [],
      warnings: [],
      routinePlans: [
        {
          slotLabel: "morning",
          title: "Morning Skin Care",
          steps: ["Cleanse face", "Apply Minimalist Vitamin C", "Apply Minimalist SPF 50"],
          productNames: ["Beardo Detan Face Wash", "Minimalist Vitamin C", "Minimalist SPF 50"],
        },
        {
          slotLabel: "night",
          title: "Night Skin Care",
          steps: ["Cleanse face", "Apply Minimalist Alpha Arbutin"],
          productNames: ["Beardo Detan Face Wash", "Minimalist Alpha Arbutin"],
        },
      ],
    }));

    const response = await worker.fetch(
      jsonRequest("/v1/skin-care/routine/generate", {
        productInputSource: "typed",
        typedProductDetails: fiveTypedProducts(),
        desiredApplicationsPerDay: 3,
      }),
      makeEnv() as any,
    );
    const json = await response.json() as any;

    expect(response.status).toBe(200);
    expect(json.routinePlans).toHaveLength(2);
    expect(json.warnings).toContain("ai_returned_fewer_routines");
  });

  test("photo source prompt uses productsFromPhoto and excludes typed products", async () => {
    const calls: FetchCall[] = [];
    stubGemini(JSON.stringify({
      routinePlans: [
        {
          slotLabel: "morning",
          title: "Morning",
          steps: ["Cleanse"],
          productNames: ["Photo Cleanser"],
        },
      ],
    }), calls);

    const response = await worker.fetch(
      jsonRequest("/v1/skin-care/routine/generate", {
        productInputSource: "photo",
        productsFromPhoto: [{ name: "Photo Cleanser", category: "cleanser" }],
        typedProductDetails: [
          {
            name: "Inactive Typed SPF",
            category: "sunscreen",
            source: "typed",
          },
        ],
        desiredApplicationsPerDay: 2,
      }),
      makeEnv() as any,
    );

    const prompt = calls[0].body.contents[0].parts[0].text as string;
    expect(response.status).toBe(200);
    expect(prompt).toContain("Active Product Source: photo");
    expect(prompt).toContain("Photo Cleanser");
    expect(prompt).not.toContain("Inactive Typed SPF");
  });

  test("desiredApplicationsPerDay 1 is clamped to 2 in prompt", async () => {
    const calls: FetchCall[] = [];
    stubGemini(JSON.stringify({
      routinePlans: [
        { slotLabel: "morning", title: "Morning", steps: ["Cleanse"] },
      ],
    }), calls);

    await worker.fetch(
      jsonRequest("/v1/skin-care/routine/generate", {
        typedProductNames: ["Cleanser"],
        desiredApplicationsPerDay: 1,
      }),
      makeEnv() as any,
    );

    const prompt = calls[0].body.contents[0].parts[0].text as string;
    expect(prompt).toContain("Desired Applications Per Day: 2");
  });

  test("desiredApplicationsPerDay 99 is capped to 4 in prompt", async () => {
    const calls: FetchCall[] = [];
    stubGemini(JSON.stringify({
      routinePlans: [
        { slotLabel: "morning", title: "Morning", steps: ["Cleanse"] },
      ],
    }), calls);

    await worker.fetch(
      jsonRequest("/v1/skin-care/routine/generate", {
        typedProductNames: ["Cleanser"],
        desiredApplicationsPerDay: 99,
      }),
      makeEnv() as any,
    );

    const prompt = calls[0].body.contents[0].parts[0].text as string;
    expect(prompt).toContain("Desired Applications Per Day: 4");
  });

  test("title-only routine plans are filtered and compatibility uses valid plans", async () => {
    stubGemini(JSON.stringify({
      routinePlans: [
        { slotLabel: "morning", title: "Morning Skin Care" },
        {
          slotLabel: "night",
          title: "Night Skin Care",
          steps: ["Cleanse"],
          productNames: ["Gentle Cleanser"],
        },
      ],
      timelineBlocks: [
        { title: "Bad Compatibility", startMinute: 1, endMinute: 2 },
      ],
      warnings: [],
    }));

    const response = await worker.fetch(
      jsonRequest("/v1/skin-care/routine/generate", {
        typedProductNames: ["Gentle Cleanser"],
        desiredApplicationsPerDay: 2,
      }),
      makeEnv() as any,
    );
    const json = await response.json() as any;

    expect(response.status).toBe(200);
    expect(json.routinePlans).toHaveLength(1);
    expect(json.routinePlans[0].slotLabel).toBe("night");
    expect(json.warnings).toContain("ai_returned_fewer_routines");
    expect(json.timelineBlocks).toHaveLength(1);
    expect(json.timelineBlocks[0].title).toBe("Night Skin Care");
    expect(json.timelineBlocks[0].title).not.toBe("Bad Compatibility");
  });
});
