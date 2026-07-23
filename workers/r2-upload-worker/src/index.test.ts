import { beforeEach, describe, expect, test, vi } from "vitest";

vi.mock("jose", () => ({
  createRemoteJWKSet: vi.fn(() => ({})),
  jwtVerify: vi.fn(),
}));

vi.mock("@aws-sdk/client-s3", () => ({
  PutObjectCommand: class {
    constructor(readonly input: unknown) {}
  },
  S3Client: class {
    constructor(readonly config: unknown) {}
  },
}));

vi.mock("@aws-sdk/s3-request-presigner", () => ({
  getSignedUrl: vi.fn(),
}));

import { getSignedUrl } from "@aws-sdk/s3-request-presigner";
import { jwtVerify } from "jose";
import worker from "./index";

const verifiedPayload = {
  payload: { sub: "uid-1", email_verified: true },
};

function makeEnv() {
  return {
    FIREBASE_PROJECT_ID: "test-project",
    R2_ACCOUNT_ID: "test-account",
    R2_ACCESS_KEY_ID: "test-access-key",
    R2_SECRET_ACCESS_KEY: "test-secret-key",
    R2_BUCKET_NAME: "test-staging-bucket",
    UPLOAD_URL_EXPIRES_SECONDS: "900",
    MAX_PROFILE_UPLOAD_BYTES: String(5 * 1024 * 1024),
    MAX_ROUTINE_IMPORT_UPLOAD_BYTES: String(15 * 1024 * 1024),
    ALLOWED_ORIGINS: "https://staging.example.test",
    UPLOAD_BUCKET: {
      head: vi.fn(async () => ({
        size: 128,
        httpMetadata: { contentType: "image/jpeg" },
      })),
      delete: vi.fn(async () => undefined),
    },
  };
}

function request(
  path: string,
  body: unknown,
  headers: HeadersInit = {
    Authorization: "Bearer valid-token",
    "Content-Type": "application/json",
  },
): Request {
  return new Request(`https://r2-upload-worker.test${path}`, {
    method: "POST",
    headers,
    body: typeof body === "string" ? body : JSON.stringify(body),
  });
}

function signBody(overrides: Record<string, unknown> = {}) {
  return {
    purpose: "skin_care",
    sourceFeature: "onboarding",
    contentType: "image/jpeg",
    sizeBytes: 128,
    ...overrides,
  };
}

describe("R2 Upload Worker request boundary", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    vi.mocked(jwtVerify).mockResolvedValue(verifiedPayload as never);
    vi.mocked(getSignedUrl).mockResolvedValue(
      "https://signed-upload.example.test/object",
    );
  });

  test("health endpoint returns configured staging-safe metadata", async () => {
    const response = await worker.fetch(
      new Request("https://r2-upload-worker.test/health"),
      makeEnv() as never,
    );
    const json = await response.json() as Record<string, unknown>;

    expect(response.status).toBe(200);
    expect(json).toMatchObject({
      ok: true,
      service: "r2-upload-worker",
      bucket: "test-staging-bucket",
      projectId: "test-project",
    });
  });

  test("CORS echoes only an explicitly allowed origin", async () => {
    const allowed = await worker.fetch(
      new Request("https://r2-upload-worker.test/health", {
        headers: { Origin: "https://staging.example.test" },
      }),
      makeEnv() as never,
    );
    const rejected = await worker.fetch(
      new Request("https://r2-upload-worker.test/health", {
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

  test("signing rejects missing and malformed Authorization headers", async () => {
    for (const authorization of [undefined, "Basic token", "Bearer   "]) {
      const headers: Record<string, string> = {
        "Content-Type": "application/json",
      };
      if (authorization) headers.Authorization = authorization;
      const response = await worker.fetch(
        request("/v1/uploads/sign", signBody(), headers),
        makeEnv() as never,
      );
      const json = await response.json() as Record<string, unknown>;

      expect(response.status).toBe(401);
      expect(json.error).toBe("missing_auth");
    }
    expect(jwtVerify).not.toHaveBeenCalled();
  });

  test("invalid or expired JWT is a safe 401", async () => {
    vi.mocked(jwtVerify).mockRejectedValue(
      new Error("expired token with internal verifier details"),
    );

    const response = await worker.fetch(
      request("/v1/uploads/sign", signBody()),
      makeEnv() as never,
    );
    const text = await response.text();

    expect(response.status).toBe(401);
    expect(JSON.parse(text).error).toBe("invalid_auth");
    expect(text).not.toContain("expired token");
    expect(text).not.toContain("verifier details");
  });

  test("signing creates an owner-scoped object key", async () => {
    const response = await worker.fetch(
      request("/v1/uploads/sign", signBody()),
      makeEnv() as never,
    );
    const json = await response.json() as Record<string, unknown>;

    expect(response.status).toBe(200);
    expect(json.objectKey).toMatch(
      /^users\/uid-1\/onboarding\/skin_care\/[A-Za-z0-9._-]+\.jpg$/,
    );
    expect(json.uploadUrl).toBe(
      "https://signed-upload.example.test/object",
    );
  });

  test.each([
    ["invalid content type", { contentType: "application/pdf" }, "invalid_content_type"],
    ["zero size", { sizeBytes: 0 }, "invalid_size"],
    [
      "oversized image",
      { sizeBytes: 15 * 1024 * 1024 + 1 },
      "invalid_size",
    ],
  ])("signing rejects %s", async (_label, overrides, errorCode) => {
    const response = await worker.fetch(
      request("/v1/uploads/sign", signBody(overrides)),
      makeEnv() as never,
    );
    const json = await response.json() as Record<string, unknown>;

    expect(response.status).toBe(400);
    expect(json.error).toBe(errorCode);
    expect(getSignedUrl).not.toHaveBeenCalled();
  });

  test("complete verifies ownership, asset id, size, and R2 metadata", async () => {
    const env = makeEnv();
    const response = await worker.fetch(
      request("/v1/uploads/complete", {
        assetId: "asset-1",
        objectKey:
          "users/uid-1/onboarding/skin_care/asset-1.jpg",
        sizeBytes: 128,
      }),
      env as never,
    );
    const json = await response.json() as Record<string, unknown>;

    expect(response.status).toBe(200);
    expect(json.ok).toBe(true);
    expect(env.UPLOAD_BUCKET.head).toHaveBeenCalledWith(
      "users/uid-1/onboarding/skin_care/asset-1.jpg",
    );
  });

  test.each(["/v1/uploads/complete", "/v1/uploads/delete"])(
    "%s rejects a cross-user object key before touching R2",
    async (path) => {
      const env = makeEnv();
      const response = await worker.fetch(
        request(path, {
          assetId: "asset-1",
          objectKey:
            "users/uid-2/onboarding/skin_care/asset-1.jpg",
          sizeBytes: 128,
        }),
        env as never,
      );
      const json = await response.json() as Record<string, unknown>;

      expect(response.status).toBe(400);
      expect(json.error).toBe("invalid_object_key");
      expect(env.UPLOAD_BUCKET.head).not.toHaveBeenCalled();
      expect(env.UPLOAD_BUCKET.delete).not.toHaveBeenCalled();
    },
  );

  test("delete removes only an owned object key", async () => {
    const env = makeEnv();
    const objectKey =
      "users/uid-1/onboarding/skin_care/asset-1.jpg";
    const response = await worker.fetch(
      request("/v1/uploads/delete", { objectKey }),
      env as never,
    );

    expect(response.status).toBe(200);
    expect(env.UPLOAD_BUCKET.delete).toHaveBeenCalledWith(objectKey);
  });

  test("malformed JSON and oversized bodies fail safely", async () => {
    const malformed = await worker.fetch(
      request("/v1/uploads/sign", "{"),
      makeEnv() as never,
    );
    expect(malformed.status).toBe(400);
    expect((await malformed.json() as Record<string, unknown>).error).toBe(
      "invalid_json",
    );

    const oversized = await worker.fetch(
      request("/v1/uploads/sign", JSON.stringify({ value: "x".repeat(5000) })),
      makeEnv() as never,
    );
    expect(oversized.status).toBe(413);
    expect((await oversized.json() as Record<string, unknown>).error).toBe(
      "body_too_large",
    );
  });

  test("unsupported method and internal signing failure do not expose details", async () => {
    const unsupported = await worker.fetch(
      new Request("https://r2-upload-worker.test/v1/uploads/sign"),
      makeEnv() as never,
    );
    expect(unsupported.status).toBe(404);

    vi.mocked(getSignedUrl).mockRejectedValue(
      new Error("R2_SECRET_ACCESS_KEY=must-not-leak"),
    );
    const failed = await worker.fetch(
      request("/v1/uploads/sign", signBody()),
      makeEnv() as never,
    );
    const text = await failed.text();
    expect(failed.status).toBe(500);
    expect(text).toContain("Upload worker error.");
    expect(text).not.toContain("must-not-leak");
    expect(text).not.toContain("R2_SECRET_ACCESS_KEY");
  });
});
