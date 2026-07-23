import { beforeEach, describe, expect, test, vi } from "vitest";

vi.mock("jose", () => ({
  createRemoteJWKSet: vi.fn(() => ({})),
  jwtVerify: vi.fn(),
}));

import { jwtVerify } from "jose";
import worker from "./index";

function makeEnv(overrides: Record<string, unknown> = {}) {
  return {
    FIREBASE_PROJECT_ID: "test-project",
    AI_PROVIDER: "gemini",
    AI_MODEL: "gemini-test",
    AI_FALLBACK_MODEL: "gemini-test",
    GEMINI_API_KEY: "gemini-key",
    ALLOWED_ORIGINS: "https://staging.example.test",
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
  return new Request("https://coach-worker.test/v1/coach/reply", {
    method: "POST",
    headers,
    body: typeof body === "string" ? body : JSON.stringify(body),
  });
}

function stubProvider(
  responseText: string,
  prompts: string[] = [],
): void {
  vi.stubGlobal(
    "fetch",
    vi.fn(async (_url: string, init?: RequestInit) => {
      const body = JSON.parse(String(init?.body ?? "{}"));
      prompts.push(body.contents?.[0]?.parts?.[0]?.text ?? "");
      return new Response(
        JSON.stringify({
          candidates: [{ content: { parts: [{ text: responseText }] } }],
        }),
        { status: 200, headers: { "Content-Type": "application/json" } },
      );
    }),
  );
}

describe("Coach Worker request boundary", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    vi.unstubAllGlobals();
    vi.mocked(jwtVerify).mockResolvedValue({
      payload: { sub: "uid-1", email_verified: true },
    } as never);
  });

  test("health endpoint returns service metadata", async () => {
    const response = await worker.fetch(
      new Request("https://coach-worker.test/health"),
      makeEnv() as never,
    );
    const json = await response.json() as Record<string, unknown>;

    expect(response.status).toBe(200);
    expect(json).toMatchObject({
      ok: true,
      service: "coach-worker",
      projectId: "test-project",
      aiProvider: "gemini",
    });
  });

  test("CORS echoes only an explicitly allowed origin", async () => {
    const allowed = await worker.fetch(
      new Request("https://coach-worker.test/health", {
        headers: { Origin: "https://staging.example.test" },
      }),
      makeEnv() as never,
    );
    const rejected = await worker.fetch(
      new Request("https://coach-worker.test/health", {
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

  test("missing and malformed Authorization are rejected", async () => {
    for (const authorization of [undefined, "Basic token", "Bearer   "]) {
      const headers: Record<string, string> = {
        "Content-Type": "application/json",
      };
      if (authorization) headers.Authorization = authorization;
      const response = await worker.fetch(
        request({ message: "Help me focus." }, headers),
        makeEnv() as never,
      );
      expect(response.status).toBe(401);
      expect((await response.json() as Record<string, unknown>).error).toBe(
        "unauthorized",
      );
    }
    expect(jwtVerify).not.toHaveBeenCalled();
  });

  test("invalid or expired token is a safe 401", async () => {
    vi.mocked(jwtVerify).mockRejectedValue(
      new Error("expired verifier internal detail"),
    );
    const response = await worker.fetch(
      request({ message: "Help me focus." }),
      makeEnv() as never,
    );
    const text = await response.text();

    expect(response.status).toBe(401);
    expect(JSON.parse(text).error).toBe("unauthorized");
    expect(text).not.toContain("internal detail");
  });

  test("malformed JSON, non-object JSON, and malformed messages are rejected", async () => {
    for (const body of ["{", "[]", JSON.stringify({ message: 42 })]) {
      const response = await worker.fetch(
        request(body),
        makeEnv() as never,
      );
      const json = await response.json() as Record<string, unknown>;
      expect(response.status).toBe(400);
      expect(["invalid_json", "invalid_coach_request"]).toContain(json.error);
    }
  });

  test("oversized request is rejected using actual body bytes", async () => {
    const response = await worker.fetch(
      request(JSON.stringify({ message: "x".repeat(9000) })),
      makeEnv() as never,
    );

    expect(response.status).toBe(413);
    expect((await response.json() as Record<string, unknown>).error).toBe(
      "payload_too_large",
    );
  });

  test("private context is excluded unless each context permission is explicit", async () => {
    const prompts: string[] = [];
    stubProvider(JSON.stringify({
      reply: "Choose one small next action.",
      cards: [],
      warnings: [],
    }), prompts);

    const response = await worker.fetch(
      request({
        message: "Help me plan.",
        userContext: "private-profile-context",
        recentSessionContext: "private-session-context",
        contextPermissions: {
          userContext: true,
          recentSessionContext: false,
        },
      }),
      makeEnv() as never,
    );

    expect(response.status).toBe(200);
    expect(prompts).toHaveLength(1);
    expect(prompts[0]).toContain("private-profile-context");
    expect(prompts[0]).not.toContain("private-session-context");
    expect(prompts[0]).not.toContain("valid-token");
    expect(prompts[0]).not.toContain("gemini-key");
  });

  test("successful provider response is bounded and sanitized", async () => {
    stubProvider(JSON.stringify({
      reply: `  ${"Focus on today. ".repeat(400)}  `,
      cards: Array.from({ length: 12 }, (_, index) => ({ index })),
      warnings: Array.from({ length: 12 }, (_, index) => `warning-${index}`),
    }));
    const response = await worker.fetch(
      request({ message: "Help me focus." }),
      makeEnv() as never,
    );
    const json = await response.json() as {
      reply: string;
      cards: unknown[];
      warnings: string[];
    };

    expect(response.status).toBe(200);
    expect(json.reply.length).toBeLessThanOrEqual(4000);
    expect(json.cards).toHaveLength(8);
    expect(json.warnings).toHaveLength(8);
  });

  test("invalid provider response returns no fabricated coach reply", async () => {
    stubProvider(JSON.stringify({ cards: [], warnings: [] }));
    const response = await worker.fetch(
      request({ message: "Help me focus." }),
      makeEnv() as never,
    );
    const json = await response.json() as Record<string, unknown>;

    expect(response.status).toBe(502);
    expect(json.error).toBe("provider_invalid_response");
    expect(json).not.toHaveProperty("reply");
  });

  test("safe provider failure leaks neither provider details nor tokens", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn(async () =>
        new Response(
          JSON.stringify({
            error: {
              message: "gemini-key and valid-token must-not-leak",
            },
          }),
          { status: 503, headers: { "Content-Type": "application/json" } },
        )
      ),
    );
    const response = await worker.fetch(
      request({ message: "Help me focus." }),
      makeEnv() as never,
    );
    const text = await response.text();
    const json = JSON.parse(text) as Record<string, unknown>;

    expect(response.status).toBe(503);
    expect(json.error).toBe("provider_request_failed");
    expect(json).not.toHaveProperty("reply");
    expect(text).not.toContain("gemini-key");
    expect(text).not.toContain("valid-token");
    expect(text).not.toContain("must-not-leak");
  });

  test("unsupported method returns a safe not-found response", async () => {
    const response = await worker.fetch(
      new Request("https://coach-worker.test/v1/coach/reply"),
      makeEnv() as never,
    );

    expect(response.status).toBe(404);
    expect((await response.json() as Record<string, unknown>).error).toBe(
      "not_found",
    );
  });
});
