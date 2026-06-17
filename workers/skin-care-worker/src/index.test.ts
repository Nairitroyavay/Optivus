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
    expect(json.routinePlans).toHaveLength(3);
    expect(calls[0].body.contents[0].parts[0].text).toContain("UV Aqua Gel");
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
          productNames: ["Cleanser", "UV Aqua Gel"],
        },
      ],
      warnings: [],
    }));

    const response = await worker.fetch(
      jsonRequest("/v1/skin-care/routine/generate", {
        productsFromPhoto: [
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
    expect(json.timelineBlocks).toHaveLength(1);
    expect(json.timelineBlocks[0].endMinute - json.timelineBlocks[0].startMinute).toBe(15);
    expect(json.warnings).toContain("routine_plan_count_mismatch");
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
    expect(json.timelineBlocks).toHaveLength(1);
    expect(json.timelineBlocks[0].title).toBe("Night Skin Care");
    expect(json.timelineBlocks[0].title).not.toBe("Bad Compatibility");
    expect(json.warnings).toContain("routine_plan_count_mismatch");
  });
});
