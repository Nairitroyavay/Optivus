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

function validRequestBody(overrides: Record<string, unknown> = {}) {
  return {
    bodyGoal: "maintain",
    eatingMode: "india",
    foodType: "mixed",
    mealsPerDay: 3,
    targetCalories: 2100,
    breakfastMinute: 480,
    lunchMinute: 780,
    dinnerMinute: 1230,
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
    "https://nutrition-worker.test/v1/eating/generate-routine",
    {
      method: "POST",
      headers,
      body: typeof body === "string" ? body : JSON.stringify(body),
    },
  );
}

function validCandidate(overrides: Record<string, unknown> = {}) {
  return {
    title: "Breakfast",
    startMinute: 480,
    endMinute: 510,
    repeatDays: [1, 2, 3, 4, 5, 6, 7],
    mealCategory: "breakfast",
    steps: ["Vegetable poha", "Plain yogurt"],
    blockType: "soft_block",
    candidateType: "block",
    confidenceScore: 0.95,
    ...overrides,
  };
}

function stubProviderText(text: string): void {
  vi.stubGlobal(
    "fetch",
    vi.fn(async () =>
      new Response(
        JSON.stringify({
          candidates: [{ content: { parts: [{ text }] } }],
        }),
        { status: 200, headers: { "Content-Type": "application/json" } },
      )
    ),
  );
}

describe("Nutrition Worker request boundary", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    vi.unstubAllGlobals();
    vi.mocked(jwtVerify).mockResolvedValue({
      payload: { sub: "uid-1", email_verified: true },
    } as never);
  });

  test("health endpoint returns service metadata", async () => {
    const response = await worker.fetch(
      new Request("https://nutrition-worker.test/health"),
      makeEnv() as never,
    );
    const json = await response.json() as Record<string, unknown>;

    expect(response.status).toBe(200);
    expect(json).toMatchObject({
      ok: true,
      service: "nutrition-worker",
      projectId: "test-project",
      aiProvider: "gemini",
    });
  });

  test("CORS echoes only an explicitly allowed origin", async () => {
    const allowed = await worker.fetch(
      new Request("https://nutrition-worker.test/health", {
        headers: { Origin: "https://staging.example.test" },
      }),
      makeEnv() as never,
    );
    const rejected = await worker.fetch(
      new Request("https://nutrition-worker.test/health", {
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
        request(validRequestBody(), headers),
        makeEnv() as never,
      );
      expect(response.status).toBe(401);
      expect((await response.json() as Record<string, unknown>).error).toBe(
        "unauthorized",
      );
    }
    expect(jwtVerify).not.toHaveBeenCalled();
  });

  test("invalid or expired Firebase token is a safe 401", async () => {
    vi.mocked(jwtVerify).mockRejectedValue(
      new Error("expired verifier internals"),
    );
    const response = await worker.fetch(
      request(validRequestBody()),
      makeEnv() as never,
    );
    const text = await response.text();

    expect(response.status).toBe(401);
    expect(JSON.parse(text).error).toBe("unauthorized");
    expect(text).not.toContain("verifier internals");
  });

  test("malformed JSON and non-object JSON are rejected", async () => {
    for (const body of ["{", "null", "[]"]) {
      const response = await worker.fetch(
        request(body),
        makeEnv() as never,
      );
      expect(response.status).toBe(400);
      expect((await response.json() as Record<string, unknown>).error).toBe(
        "invalid_json",
      );
    }
  });

  test("missing required nutrition fields are rejected", async () => {
    const response = await worker.fetch(
      request(validRequestBody({ bodyGoal: "" })),
      makeEnv() as never,
    );
    const json = await response.json() as Record<string, unknown>;

    expect(response.status).toBe(400);
    expect(json.error).toBe("invalid_eating_request");
  });

  test("oversized JSON is rejected using actual body bytes", async () => {
    const response = await worker.fetch(
      request(JSON.stringify({ value: "x".repeat(9000) })),
      makeEnv() as never,
    );

    expect(response.status).toBe(413);
    expect((await response.json() as Record<string, unknown>).error).toBe(
      "payload_too_large",
    );
  });

  test("successful output is validated, owner-scoped, and allow-listed", async () => {
    stubProviderText(JSON.stringify({
      candidates: [
        validCandidate({
          mealSlot: "breakfast",
          providerDebug: "must-not-be-returned",
          apiToken: "must-not-be-returned",
        }),
        validCandidate({
          mealSlot: "lunch",
          title: "Lunch",
          mealCategory: "lunch",
          steps: ["Rice", "Dal"],
        }),
        validCandidate({
          mealSlot: "dinner",
          title: "Dinner",
          mealCategory: "dinner",
          steps: ["Roti", "Curry"],
        }),
      ],
    }));
    const response = await worker.fetch(
      request(validRequestBody()),
      makeEnv() as never,
    );
    const text = await response.text();
    const json = JSON.parse(text) as {
      uid: string;
      candidates: Array<Record<string, unknown>>;
    };

    expect(response.status).toBe(200);
    expect(json.uid).toBe("uid-1");
    expect(json.candidates).toHaveLength(3);
    expect(json.candidates[0]).toMatchObject({
      title: "Breakfast",
      mealCategory: "breakfast",
      startMinute: 480,
      endMinute: 510,
      candidateType: "block",
      blockType: "soft_block",
    });
    expect(text).not.toContain("providerDebug");
    expect(text).not.toContain("apiToken");
    expect(text).not.toContain("must-not-be-returned");
  });

  test("five requested meal slots are returned once with canonical title and time", async () => {
    stubProviderText(JSON.stringify({
      candidates: [
        validCandidate({ mealSlot: "breakfast", title: "Breakfast", mealCategory: "breakfast", startMinute: 100 }),
        validCandidate({ mealSlot: "morning_snack", title: "Breakfast", mealCategory: "snack", startMinute: 200 }),
        validCandidate({ mealSlot: "lunch", title: "Lunch", mealCategory: "lunch", startMinute: 300 }),
        validCandidate({ mealSlot: "afternoon_snack", title: "Snack", mealCategory: "snack", startMinute: 400 }),
        validCandidate({ mealSlot: "dinner", title: "Dinner", mealCategory: "dinner", startMinute: 500 }),
      ],
    }));
    const response = await worker.fetch(
      request(validRequestBody({
        mealsPerDay: 5,
        breakfastMinute: 480,
        extraSnackMinute: 660,
        lunchMinute: 780,
        snackMinute: 1020,
        dinnerMinute: 1230,
      })),
      makeEnv() as never,
    );
    const json = await response.json() as { candidates: Array<Record<string, unknown>> };

    expect(response.status).toBe(200);
    expect(json.candidates.map((candidate) => candidate.mealSlot)).toEqual([
      "breakfast",
      "morning_snack",
      "lunch",
      "afternoon_snack",
      "dinner",
    ]);
    expect(json.candidates.map((candidate) => candidate.title)).toEqual([
      "Breakfast",
      "Morning Snack",
      "Lunch",
      "Snack",
      "Dinner",
    ]);
    expect(json.candidates.map((candidate) => candidate.startMinute)).toEqual([
      480,
      660,
      780,
      1020,
      1230,
    ]);
  });

  test("duplicate meal slot is a contract failure", async () => {
    stubProviderText(JSON.stringify({
      candidates: [
        validCandidate({ mealSlot: "breakfast" }),
        validCandidate({ mealSlot: "breakfast" }),
        validCandidate({ mealSlot: "lunch", mealCategory: "lunch" }),
        validCandidate({ mealSlot: "dinner", mealCategory: "dinner" }),
      ],
    }));
    const response = await worker.fetch(
      request(validRequestBody()),
      makeEnv() as never,
    );
    const json = await response.json() as Record<string, unknown>;

    expect(response.status).toBe(500);
    expect(json.error).toBe("provider_duplicate_meal_slot");
  });

  test("missing meal slot is a contract failure", async () => {
    stubProviderText(JSON.stringify({
      candidates: [
        validCandidate({ mealSlot: "breakfast" }),
        validCandidate({ mealSlot: "lunch", mealCategory: "lunch" }),
      ],
    }));
    const response = await worker.fetch(
      request(validRequestBody()),
      makeEnv() as never,
    );
    const json = await response.json() as Record<string, unknown>;

    expect(response.status).toBe(500);
    expect(json.error).toBe("provider_missing_meal_slot");
  });

  test("invalid generated plan returns an error with no fake meal plan", async () => {
    stubProviderText(JSON.stringify({
      candidates: [
        validCandidate({
          endMinute: 400,
          repeatDays: [],
          steps: ["Breakfast", "Food"],
        }),
      ],
    }));
    const response = await worker.fetch(
      request(validRequestBody()),
      makeEnv() as never,
    );
    const text = await response.text();
    const json = JSON.parse(text) as Record<string, unknown>;

    expect(response.status).toBe(500);
    expect(json.error).toBe("provider_empty_candidates");
    expect(json).not.toHaveProperty("candidates");
    expect(text).not.toContain("Vegetable poha");
  });

  test("safe provider failure returns no fabricated plan or internal detail", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn(async () =>
        new Response(
          JSON.stringify({
            error: { message: "provider-secret=must-not-leak" },
          }),
          { status: 503, headers: { "Content-Type": "application/json" } },
        )
      ),
    );
    const response = await worker.fetch(
      request(validRequestBody()),
      makeEnv() as never,
    );
    const text = await response.text();
    const json = JSON.parse(text) as Record<string, unknown>;

    expect(response.status).toBe(503);
    expect(json.error).toBe("provider_high_demand");
    expect(json).not.toHaveProperty("candidates");
    expect(text).not.toContain("must-not-leak");
    expect(text).not.toContain("provider-secret");
  });

  test("invalid provider JSON maps to a safe error", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn(async () =>
        new Response("{", {
          status: 200,
          headers: { "Content-Type": "application/json" },
        })
      ),
    );
    const response = await worker.fetch(
      request(validRequestBody()),
      makeEnv() as never,
    );
    const json = await response.json() as Record<string, unknown>;

    expect(response.status).toBe(500);
    expect(json.error).toBe("provider_invalid_json");
    expect(json).not.toHaveProperty("candidates");
  });

  test("unsupported method returns a safe not-found response", async () => {
    const response = await worker.fetch(
      new Request(
        "https://nutrition-worker.test/v1/eating/generate-routine",
      ),
      makeEnv() as never,
    );

    expect(response.status).toBe(404);
    expect((await response.json() as Record<string, unknown>).error).toBe(
      "not_found",
    );
  });
});
