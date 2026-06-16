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
        desiredApplicationsPerDay: 1,
      }),
      makeEnv() as any,
    );
    const json = await response.json() as any;

    expect(response.status).toBe(200);
    expect(json.routinePlans).toHaveLength(1);
    expect(json.timelineBlocks).toHaveLength(1);
    expect(json.timelineBlocks[0].endMinute - json.timelineBlocks[0].startMinute).toBe(15);
  });

  test("desiredApplicationsPerDay is included in prompt and capped to 2-4", async () => {
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
});
