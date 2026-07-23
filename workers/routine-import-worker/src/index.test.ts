import { beforeEach, describe, expect, test, vi } from "vitest";

vi.mock("jose", () => ({
  createRemoteJWKSet: vi.fn(() => ({})),
  jwtVerify: vi.fn(),
}));

import { jwtVerify } from "jose";
import worker from "./index";

const objectKey =
  "users/uid-1/onboarding/class_timetable/asset-1.jpg";

class MockR2Object {
  readonly size: number;
  readonly httpMetadata: { contentType: string };

  constructor(
    private readonly body = "synthetic-image",
    contentType = "image/jpeg",
  ) {
    this.size = new TextEncoder().encode(body).byteLength;
    this.httpMetadata = { contentType };
  }

  async arrayBuffer(): Promise<ArrayBuffer> {
    const bytes = new TextEncoder().encode(this.body);
    return bytes.buffer.slice(
      bytes.byteOffset,
      bytes.byteOffset + bytes.byteLength,
    ) as ArrayBuffer;
  }
}

function makeEnv(
  overrides: Record<string, unknown> = {},
  storedObject: MockR2Object | null = new MockR2Object(),
) {
  return {
    FIREBASE_PROJECT_ID: "test-project",
    R2_BUCKET_NAME: "test-staging-bucket",
    MAX_IMAGE_BYTES: String(15 * 1024 * 1024),
    GEMINI_INLINE_MAX_IMAGE_BYTES: String(11 * 1024 * 1024),
    AI_PROVIDER: "gemini",
    AI_MODEL: "gemini-test",
    AI_FALLBACK_MODEL: "gemini-test",
    GEMINI_API_KEY: "gemini-key",
    ALLOWED_ORIGINS: "https://staging.example.test",
    UPLOAD_BUCKET: {
      get: vi.fn(async () => storedObject),
    },
    ...overrides,
  };
}

function extractionBody(overrides: Record<string, unknown> = {}) {
  return {
    reviewId: "review-1",
    source: "classes",
    uploadedAssetId: "asset-1",
    uploadedAssetR2Key: objectKey,
    sourceLabel: "Classes",
    ...overrides,
  };
}

function request(
  body: unknown,
  headers: HeadersInit = {
    Authorization: "Bearer valid-token",
    "Content-Type": "application/json",
  },
): Request {
  return new Request(
    "https://routine-import-worker.test/v1/routine-import/extract",
    {
      method: "POST",
      headers,
      body: typeof body === "string" ? body : JSON.stringify(body),
    },
  );
}

function stubGemini(status: number, body: unknown): void {
  vi.stubGlobal(
    "fetch",
    vi.fn(async () =>
      new Response(JSON.stringify(body), {
        status,
        headers: { "Content-Type": "application/json" },
      })
    ),
  );
}

describe("Routine Import Worker request boundary", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    vi.unstubAllGlobals();
    vi.mocked(jwtVerify).mockResolvedValue({
      payload: { sub: "uid-1", email_verified: true },
    } as never);
  });

  test("health endpoint reports configured service metadata", async () => {
    const response = await worker.fetch(
      new Request("https://routine-import-worker.test/health"),
      makeEnv() as never,
    );
    const json = await response.json() as Record<string, unknown>;

    expect(response.status).toBe(200);
    expect(json).toMatchObject({
      ok: true,
      service: "routine-import-worker",
      projectId: "test-project",
      bucket: "test-staging-bucket",
      aiProvider: "gemini",
    });
  });

  test("CORS echoes only an explicitly allowed origin", async () => {
    const allowed = await worker.fetch(
      new Request("https://routine-import-worker.test/health", {
        headers: { Origin: "https://staging.example.test" },
      }),
      makeEnv() as never,
    );
    const rejected = await worker.fetch(
      new Request("https://routine-import-worker.test/health", {
        headers: { Origin: "https://unapproved.example.test" },
      }),
      makeEnv() as never,
    );

    expect(allowed.headers.get("Access-Control-Allow-Origin")).toBe(
      "https://staging.example.test",
    );
    expect(allowed.headers.get("Vary")).toBe("Origin");
    expect(rejected.headers.get("Access-Control-Allow-Origin")).toBeNull();
  });

  test("missing and malformed Authorization are rejected before verification", async () => {
    for (const authorization of [undefined, "Basic token", "Bearer   "]) {
      const headers: Record<string, string> = {
        "Content-Type": "application/json",
      };
      if (authorization) headers.Authorization = authorization;
      const response = await worker.fetch(
        request(extractionBody(), headers),
        makeEnv() as never,
      );
      expect(response.status).toBe(401);
      expect((await response.json() as Record<string, unknown>).error).toBe(
        "missing_auth",
      );
    }
    expect(jwtVerify).not.toHaveBeenCalled();
  });

  test("invalid or expired JWT is a safe 401", async () => {
    vi.mocked(jwtVerify).mockRejectedValue(
      new Error("expired token verifier internals"),
    );
    const response = await worker.fetch(
      request(extractionBody()),
      makeEnv() as never,
    );
    const text = await response.text();

    expect(response.status).toBe(401);
    expect(JSON.parse(text).error).toBe("invalid_auth");
    expect(text).not.toContain("verifier internals");
  });

  test("malformed JSON, oversized JSON, and missing fields are rejected", async () => {
    const malformed = await worker.fetch(
      request("{"),
      makeEnv() as never,
    );
    expect(malformed.status).toBe(400);
    expect((await malformed.json() as Record<string, unknown>).error).toBe(
      "invalid_json",
    );

    const oversized = await worker.fetch(
      request(JSON.stringify({ value: "x".repeat(9000) })),
      makeEnv() as never,
    );
    expect(oversized.status).toBe(413);
    expect((await oversized.json() as Record<string, unknown>).error).toBe(
      "body_too_large",
    );

    const missing = await worker.fetch(
      request({ source: "classes" }),
      makeEnv() as never,
    );
    expect(missing.status).toBe(400);
    expect((await missing.json() as Record<string, unknown>).error).toBe(
      "missing_field",
    );
  });

  test.each([
    [
      "wrong owner UID",
      {
        uploadedAssetR2Key:
          "users/uid-2/onboarding/class_timetable/asset-1.jpg",
      },
      "invalid_object_key",
    ],
    [
      "wrong purpose for source",
      {
        source: "eating",
        uploadedAssetR2Key:
          "users/uid-1/onboarding/skin_care/asset-1.jpg",
      },
      "invalid_object_key",
    ],
    ["invalid source", { source: "profile" }, "invalid_source"],
    [
      "asset mismatch",
      { uploadedAssetId: "asset-2" },
      "asset_mismatch",
    ],
  ])("rejects %s before reading R2", async (_label, overrides, errorCode) => {
    const env = makeEnv();
    const response = await worker.fetch(
      request(extractionBody(overrides)),
      env as never,
    );
    const json = await response.json() as Record<string, unknown>;

    expect(response.status).toBe(400);
    expect(json.error).toBe(errorCode);
    expect(env.UPLOAD_BUCKET.get).not.toHaveBeenCalled();
  });

  test("malformed provider output returns no fabricated candidates", async () => {
    stubGemini(200, {
      candidates: [{ content: { parts: [{ text: "not-json" }] } }],
    });
    const response = await worker.fetch(
      request(extractionBody()),
      makeEnv() as never,
    );
    const json = await response.json() as {
      candidates: unknown[];
      warnings: string[];
    };

    expect(response.status).toBe(200);
    expect(json.candidates).toEqual([]);
    expect(json.warnings).toContain(
      "AI output could not be safely parsed. Review manually.",
    );
  });

  test("provider failure is safe and returns no fabricated schedule", async () => {
    stubGemini(503, {
      error: {
        message: "provider-secret=must-not-leak",
        status: "UNAVAILABLE",
      },
    });
    const response = await worker.fetch(
      request(extractionBody()),
      makeEnv() as never,
    );
    const text = await response.text();
    const json = JSON.parse(text) as {
      candidates: unknown[];
      warnings: string[];
    };

    expect(response.status).toBe(200);
    expect(json.candidates).toEqual([]);
    expect(json.warnings).toContain("provider_high_demand");
    expect(text).not.toContain("must-not-leak");
    expect(text).not.toContain("provider-secret");
  });

  test("disabled provider returns review-only output and never applies Routine items", async () => {
    const response = await worker.fetch(
      request(extractionBody()),
      makeEnv({
        AI_PROVIDER: "disabled",
        GEMINI_API_KEY: undefined,
      }) as never,
    );
    const text = await response.text();
    const json = JSON.parse(text) as {
      engine: string;
      candidates: Array<Record<string, unknown>>;
    };

    expect(response.status).toBe(200);
    expect(json.engine).toBe("disabled");
    expect(text).not.toContain("routineItems");
    expect(text).not.toContain("appliedRoutineItemIds");
  });

  test("unsupported method has a safe not-found response", async () => {
    const response = await worker.fetch(
      new Request(
        "https://routine-import-worker.test/v1/routine-import/extract",
      ),
      makeEnv() as never,
    );
    expect(response.status).toBe(404);
    expect((await response.json() as Record<string, unknown>).error).toBe(
      "not_found",
    );
  });
});
