import { beforeEach, describe, expect, test, vi } from "vitest";

vi.mock("jose", () => ({
  createRemoteJWKSet: vi.fn(() => ({})),
  jwtVerify: vi.fn(async () => ({
    payload: { sub: "uid-1", email_verified: true },
  })),
}));

import worker from "./index";

type StoredObject = {
  body?: string;
  contentType?: string;
};

type FetchCall = {
  url: string;
  body: any;
};

class MockR2Object {
  httpMetadata?: { contentType?: string };
  private readonly body: string;

  constructor(object: StoredObject = {}) {
    this.body = object.body ?? "image";
    this.httpMetadata =
      object.contentType === undefined
        ? {}
        : { contentType: object.contentType };
  }

  async arrayBuffer(): Promise<ArrayBuffer> {
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
    { name: "Minimalist Vitamin C", category: "serum", source: "typed" },
    { name: "Minimalist Alpha Arbutin", category: "serum", source: "typed" },
    { name: "Minimalist PHA Toner", category: "exfoliant", source: "typed" },
  ];
}

describe("Skin-care Worker", () => {
  beforeEach(() => {
    vi.restoreAllMocks();
    vi.unstubAllGlobals();
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

  test("unsupported image content type returns unsupported_content_type", async () => {
    const key = "users/uid-1/onboarding/skin_care/products.gif";
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

  test("missing metadata with .jpg key is accepted", async () => {
    const key = "users/uid-1/onboarding/skin_care/products.jpg";
    stubGemini(JSON.stringify({
      products: [{ name: "UV Aqua Gel", category: "sunscreen" }],
      warnings: [],
    }));

    const response = await worker.fetch(
      jsonRequest("/v1/skin-care/products/analyze", {
        productPhotos: [key],
      }),
      makeEnv({ [key]: {} }) as any,
    );
    const json = await response.json() as any;

    expect(response.status).toBe(200);
    expect(json.products[0].name).toBe("UV Aqua Gel");
  });

  test("product analysis invalid JSON returns provider_invalid_json", async () => {
    const key = "users/uid-1/onboarding/skin_care/products.jpg";
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
    const key = "users/uid-1/onboarding/skin_care/products.jpg";

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

  test("invalid R2 key is rejected", async () => {
    const response = await worker.fetch(
      jsonRequest("/v1/skin-care/products/analyze", {
        productPhotos: ["users/other/onboarding/skin_care/products.jpg"],
      }),
      makeEnv() as any,
    );
    const json = await response.json() as any;

    expect(response.status).toBe(403);
    expect(json.error).toBe("forbidden");
  });

  test("missing Gemini key returns internal error", async () => {
    const key = "users/uid-1/onboarding/skin_care/products.jpg";
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
    }));

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
