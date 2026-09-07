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

function buildWeeklyCandidates(
  mealsPerDay = 3,
  overrides?: (day: number, slot: string) => Record<string, unknown> | null,
) {
  const candidates: Record<string, unknown>[] = [];
  const breakfastDishes = [
    ["Vegetable poha", "Plain curd"],
    ["Oatmeal with Almonds", "Boiled egg"],
    ["Idli sambar", "Coconut chutney"],
    ["Moong dal cheela", "Mint chutney"],
    ["Whole wheat toast", "Scrambled eggs"],
    ["Besan cheela", "Curd"],
    ["Paneer bhurji", "Roti"],
  ];
  const morningSnackDishes = [
    ["Apple slices", "Peanut butter"],
    ["Mixed nuts", "Green tea"],
    ["Roasted makhana", "Almonds"],
    ["Fruit salad", "Walnuts"],
    ["Sprouted moong", "Lemon juice"],
    ["Greek yogurt", "Chia seeds"],
    ["Boiled chana", "Chaat masala"],
  ];
  const lunchDishes = [
    ["Brown rice", "Dal tadka", "Spinach sabzi"],
    ["Quinoa bowl", "Chickpea curry"],
    ["Chapati", "Rajma curry", "Cucumber salad"],
    ["Brown rice", "Paneer curry", "Salad"],
    ["Millet roti", "Mixed dal", "Bhindi"],
    ["Vegetable pulao", "Raita"],
    ["Roti", "Soya chunk curry", "Salad"],
  ];
  const afternoonSnackDishes = [
    ["Roasted chana", "Buttermilk"],
    ["Carrot sticks", "Hummus"],
    ["Pistachios", "Herbal tea"],
    ["Sprouts chaat", "Pomegranate"],
    ["Dry fruits", "Coconut water"],
    ["Cucumber slices", "Guacamole"],
    ["Boiled corn", "Lime"],
  ];
  const dinnerDishes = [
    ["Whole wheat roti", "Methi paneer", "Tomato soup"],
    ["Lentil soup", "Steamed broccoli", "Tofu stir fry"],
    ["Multigrain roti", "Palak dal", "Salad"],
    ["Grilled fish", "Steamed asparagus", "Millet"],
    ["Egg curry", "Roti", "Kachumber"],
    ["Mushroom curry", "Whole wheat roti"],
    ["Mixed vegetable stew", "Brown rice"],
  ];

  for (let d = 1; d <= 7; d++) {
    const dayIdx = d - 1;
    if (mealsPerDay === 3) {
      candidates.push({
        day: d,
        repeatDays: [d],
        mealSlot: "breakfast",
        title: "Breakfast",
        mealCategory: "breakfast",
        startMinute: 480,
        endMinute: 510,
        steps: breakfastDishes[dayIdx],
        caloriesEstimate: 600,
        proteinEstimate: 20,
        blockType: "soft_block",
        candidateType: "block",
        ...(overrides?.(d, "breakfast") ?? {}),
      });
      candidates.push({
        day: d,
        repeatDays: [d],
        mealSlot: "lunch",
        title: "Lunch",
        mealCategory: "lunch",
        startMinute: 780,
        endMinute: 825,
        steps: lunchDishes[dayIdx],
        caloriesEstimate: 800,
        proteinEstimate: 30,
        blockType: "soft_block",
        candidateType: "block",
        ...(overrides?.(d, "lunch") ?? {}),
      });
      candidates.push({
        day: d,
        repeatDays: [d],
        mealSlot: "dinner",
        title: "Dinner",
        mealCategory: "dinner",
        startMinute: 1230,
        endMinute: 1275,
        steps: dinnerDishes[dayIdx],
        caloriesEstimate: 700,
        proteinEstimate: 25,
        blockType: "soft_block",
        candidateType: "block",
        ...(overrides?.(d, "dinner") ?? {}),
      });
    } else if (mealsPerDay === 4) {
      candidates.push({
        day: d,
        repeatDays: [d],
        mealSlot: "breakfast",
        title: "Breakfast",
        mealCategory: "breakfast",
        startMinute: 480,
        endMinute: 510,
        steps: breakfastDishes[dayIdx],
        caloriesEstimate: 550,
        proteinEstimate: 20,
        blockType: "soft_block",
        candidateType: "block",
        ...(overrides?.(d, "breakfast") ?? {}),
      });
      candidates.push({
        day: d,
        repeatDays: [d],
        mealSlot: "lunch",
        title: "Lunch",
        mealCategory: "lunch",
        startMinute: 780,
        endMinute: 825,
        steps: lunchDishes[dayIdx],
        caloriesEstimate: 750,
        proteinEstimate: 25,
        blockType: "soft_block",
        candidateType: "block",
        ...(overrides?.(d, "lunch") ?? {}),
      });
      candidates.push({
        day: d,
        repeatDays: [d],
        mealSlot: "afternoon_snack",
        title: "Snack",
        mealCategory: "snack",
        startMinute: 1020,
        endMinute: 1040,
        steps: afternoonSnackDishes[dayIdx],
        caloriesEstimate: 200,
        proteinEstimate: 10,
        blockType: "soft_block",
        candidateType: "block",
        ...(overrides?.(d, "afternoon_snack") ?? {}),
      });
      candidates.push({
        day: d,
        repeatDays: [d],
        mealSlot: "dinner",
        title: "Dinner",
        mealCategory: "dinner",
        startMinute: 1230,
        endMinute: 1275,
        steps: dinnerDishes[dayIdx],
        caloriesEstimate: 600,
        proteinEstimate: 20,
        blockType: "soft_block",
        candidateType: "block",
        ...(overrides?.(d, "dinner") ?? {}),
      });
    } else if (mealsPerDay === 5) {
      candidates.push({
        day: d,
        repeatDays: [d],
        mealSlot: "breakfast",
        title: "Breakfast",
        mealCategory: "breakfast",
        startMinute: 480,
        endMinute: 510,
        steps: breakfastDishes[dayIdx],
        caloriesEstimate: 500,
        proteinEstimate: 20,
        blockType: "soft_block",
        candidateType: "block",
        ...(overrides?.(d, "breakfast") ?? {}),
      });
      candidates.push({
        day: d,
        repeatDays: [d],
        mealSlot: "morning_snack",
        title: "Morning Snack",
        mealCategory: "snack",
        startMinute: 660,
        endMinute: 680,
        steps: morningSnackDishes[dayIdx],
        caloriesEstimate: 200,
        proteinEstimate: 8,
        blockType: "soft_block",
        candidateType: "block",
        ...(overrides?.(d, "morning_snack") ?? {}),
      });
      candidates.push({
        day: d,
        repeatDays: [d],
        mealSlot: "lunch",
        title: "Lunch",
        mealCategory: "lunch",
        startMinute: 780,
        endMinute: 825,
        steps: lunchDishes[dayIdx],
        caloriesEstimate: 650,
        proteinEstimate: 25,
        blockType: "soft_block",
        candidateType: "block",
        ...(overrides?.(d, "lunch") ?? {}),
      });
      candidates.push({
        day: d,
        repeatDays: [d],
        mealSlot: "afternoon_snack",
        title: "Snack",
        mealCategory: "snack",
        startMinute: 1020,
        endMinute: 1040,
        steps: afternoonSnackDishes[dayIdx],
        caloriesEstimate: 200,
        proteinEstimate: 8,
        blockType: "soft_block",
        candidateType: "block",
        ...(overrides?.(d, "afternoon_snack") ?? {}),
      });
      candidates.push({
        day: d,
        repeatDays: [d],
        mealSlot: "dinner",
        title: "Dinner",
        mealCategory: "dinner",
        startMinute: 1230,
        endMinute: 1275,
        steps: dinnerDishes[dayIdx],
        caloriesEstimate: 550,
        proteinEstimate: 20,
        blockType: "soft_block",
        candidateType: "block",
        ...(overrides?.(d, "dinner") ?? {}),
      });
    }
  }
  return candidates;
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
    const json = (await response.json()) as Record<string, unknown>;

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
      expect(((await response.json()) as Record<string, unknown>).error).toBe(
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
      expect(((await response.json()) as Record<string, unknown>).error).toBe(
        "invalid_json",
      );
    }
  });

  test("missing required nutrition fields are rejected", async () => {
    const response = await worker.fetch(
      request(validRequestBody({ bodyGoal: "" })),
      makeEnv() as never,
    );
    const json = (await response.json()) as Record<string, unknown>;

    expect(response.status).toBe(400);
    expect(json.error).toBe("invalid_eating_request");
  });

  test("oversized JSON is rejected using actual body bytes", async () => {
    const response = await worker.fetch(
      request(JSON.stringify({ value: "x".repeat(9000) })),
      makeEnv() as never,
    );

    expect(response.status).toBe(413);
    expect(((await response.json()) as Record<string, unknown>).error).toBe(
      "payload_too_large",
    );
  });

  test("successful 3-meal plan produces exactly 21 candidates with canonical IDs and nutrition", async () => {
    stubProviderText(
      JSON.stringify({
        candidates: buildWeeklyCandidates(3),
      }),
    );
    const response = await worker.fetch(
      request(validRequestBody({ mealsPerDay: 3 })),
      makeEnv() as never,
    );
    const text = await response.text();
    const json = JSON.parse(text) as {
      uid: string;
      candidates: Array<Record<string, unknown>>;
    };

    expect(response.status).toBe(200);
    expect(json.uid).toBe("uid-1");
    expect(json.candidates).toHaveLength(21);
    expect(json.candidates[0]).toMatchObject({
      id: "meal_breakfast_d1",
      day: 1,
      mealSlot: "breakfast",
      title: "Breakfast",
      mealCategory: "breakfast",
      startMinute: 480,
      endMinute: 510,
      repeatDays: [1],
      caloriesEstimate: 600,
      proteinEstimate: 20,
      candidateType: "block",
      blockType: "soft_block",
    });
    expect(json.candidates[20]).toMatchObject({
      id: "meal_dinner_d7",
      day: 7,
      mealSlot: "dinner",
      title: "Dinner",
      repeatDays: [7],
    });
  });

  test("successful 4-meal plan produces exactly 28 candidates with snack", async () => {
    stubProviderText(
      JSON.stringify({
        candidates: buildWeeklyCandidates(4),
      }),
    );
    const response = await worker.fetch(
      request(
        validRequestBody({
          mealsPerDay: 4,
          snackMinute: 1020,
        }),
      ),
      makeEnv() as never,
    );
    const json = (await response.json()) as {
      candidates: Array<Record<string, unknown>>;
    };

    expect(response.status).toBe(200);
    expect(json.candidates).toHaveLength(28);
    const day1Slots = json.candidates
      .slice(0, 4)
      .map((c) => c.mealSlot);
    expect(day1Slots).toEqual([
      "breakfast",
      "lunch",
      "afternoon_snack",
      "dinner",
    ]);
  });

  test("successful 5-meal plan produces exactly 35 candidates with morning and afternoon snacks", async () => {
    stubProviderText(
      JSON.stringify({
        candidates: buildWeeklyCandidates(5),
      }),
    );
    const response = await worker.fetch(
      request(
        validRequestBody({
          mealsPerDay: 5,
          extraSnackMinute: 660,
          snackMinute: 1020,
        }),
      ),
      makeEnv() as never,
    );
    const json = (await response.json()) as {
      candidates: Array<Record<string, unknown>>;
    };

    expect(response.status).toBe(200);
    expect(json.candidates).toHaveLength(35);
    const day1Slots = json.candidates
      .slice(0, 5)
      .map((c) => c.mealSlot);
    expect(day1Slots).toEqual([
      "breakfast",
      "morning_snack",
      "lunch",
      "afternoon_snack",
      "dinner",
    ]);
  });

  test("missing meal slot on any day throws provider_incomplete_week", async () => {
    const candidates = buildWeeklyCandidates(3).filter(
      (c) => !(c.day === 7 && c.mealSlot === "dinner"),
    );
    stubProviderText(JSON.stringify({ candidates }));
    const response = await worker.fetch(
      request(validRequestBody({ mealsPerDay: 3 })),
      makeEnv() as never,
    );
    const json = (await response.json()) as Record<string, unknown>;

    expect(response.status).toBe(500);
    expect(json.error).toBe("provider_incomplete_week");
  });

  test("duplicate meal slot on same day throws provider_duplicate_meal_slot", async () => {
    const candidates = buildWeeklyCandidates(3);
    candidates.push({
      day: 1,
      repeatDays: [1],
      mealSlot: "breakfast",
      title: "Breakfast",
      mealCategory: "breakfast",
      startMinute: 480,
      endMinute: 510,
      steps: ["Egg sandwich", "Milk"],
      caloriesEstimate: 500,
      proteinEstimate: 20,
    });
    stubProviderText(JSON.stringify({ candidates }));
    const response = await worker.fetch(
      request(validRequestBody({ mealsPerDay: 3 })),
      makeEnv() as never,
    );
    const json = (await response.json()) as Record<string, unknown>;

    expect(response.status).toBe(500);
    expect(json.error).toBe("provider_duplicate_meal_slot");
  });

  test("daily calories deviating significantly (>15%) from target throws provider_target_mismatch", async () => {
    const candidates = buildWeeklyCandidates(3, (d, slot) => {
      if (d === 3 && slot === "breakfast") {
        return { caloriesEstimate: 200 }; // Day 3 total = 200 + 800 + 700 = 1700 kcal (target: 2100 => min 1785)
      }
      return null;
    });
    stubProviderText(JSON.stringify({ candidates }));
    const response = await worker.fetch(
      request(validRequestBody({ mealsPerDay: 3, targetCalories: 2100 })),
      makeEnv() as never,
    );
    const json = (await response.json()) as Record<string, unknown>;

    expect(response.status).toBe(500);
    expect(json.error).toBe("provider_target_mismatch");
  });

  test("daily calories within ±15% pass successfully", async () => {
    const candidates = buildWeeklyCandidates(3, (d, slot) => {
      if (d === 3 && slot === "breakfast") {
        return { caloriesEstimate: 285 }; // Day 3 total = 285 + 800 + 700 = 1785 kcal (exact 85% of 2100)
      }
      return null;
    });
    stubProviderText(JSON.stringify({ candidates }));
    const response = await worker.fetch(
      request(validRequestBody({ mealsPerDay: 3, targetCalories: 2100 })),
      makeEnv() as never,
    );
    expect(response.status).toBe(200);
  });

  test("daily protein deviating significantly (>20%) from target throws provider_target_mismatch", async () => {
    const candidates = buildWeeklyCandidates(3, (d, slot) => {
      if (d === 4 && slot === "lunch") {
        return { proteinEstimate: 15 }; // Day 4 total protein = 20 + 15 + 25 = 60g (target: 90g => min 72g)
      }
      return null;
    });
    stubProviderText(JSON.stringify({ candidates }));
    const response = await worker.fetch(
      request(
        validRequestBody({
          mealsPerDay: 3,
          targetCalories: 2100,
          proteinTarget: 90,
        }),
      ),
      makeEnv() as never,
    );
    const json = (await response.json()) as Record<string, unknown>;

    expect(response.status).toBe(500);
    expect(json.error).toBe("provider_target_mismatch");
  });

  test("daily protein within ±20% passes successfully", async () => {
    const candidates = buildWeeklyCandidates(3, (d, slot) => {
      if (d === 4 && slot === "lunch") {
        return { proteinEstimate: 30 }; // Day 4 total protein = 20 + 30 + 25 = 75g (target: 90g => range [72g, 108g])
      }
      return null;
    });
    stubProviderText(JSON.stringify({ candidates }));
    const response = await worker.fetch(
      request(
        validRequestBody({
          mealsPerDay: 3,
          targetCalories: 2100,
          proteinTarget: 90,
        }),
      ),
      makeEnv() as never,
    );
    expect(response.status).toBe(200);
  });

  test("duplicate entire day menu across days throws provider_insufficient_diversity", async () => {
    // Day 1 and Day 2 have identical menus, remaining days 3-7 differ
    const candidates = buildWeeklyCandidates(3, (d, slot) => {
      if (d === 2) {
        if (slot === "breakfast") return { steps: ["Vegetable poha", "Plain curd"] };
        if (slot === "lunch") return { steps: ["Brown rice", "Dal tadka", "Spinach sabzi"] };
        if (slot === "dinner") return { steps: ["Whole wheat roti", "Methi paneer", "Tomato soup"] };
      }
      return null;
    });
    stubProviderText(JSON.stringify({ candidates }));
    const response = await worker.fetch(
      request(validRequestBody({ mealsPerDay: 3 })),
      makeEnv() as never,
    );
    const json = (await response.json()) as Record<string, unknown>;

    expect(response.status).toBe(500);
    expect(json.error).toBe("provider_insufficient_diversity");
  });

  test("duplicate breakfast across two days throws provider_insufficient_diversity even if daily menus differ", async () => {
    // Day 1 and Day 3 have identical breakfast, but different lunch and dinner
    const candidates = buildWeeklyCandidates(3, (d, slot) => {
      if (d === 3 && slot === "breakfast") {
        return { steps: ["Vegetable poha", "Plain curd"] }; // Same as Day 1
      }
      return null;
    });
    stubProviderText(JSON.stringify({ candidates }));
    const response = await worker.fetch(
      request(validRequestBody({ mealsPerDay: 3 })),
      makeEnv() as never,
    );
    const json = (await response.json()) as Record<string, unknown>;

    expect(response.status).toBe(500);
    expect(json.error).toBe("provider_insufficient_diversity");
  });

  test("ordering or whitespace differences do not bypass duplicate detection", async () => {
    // Day 1 has ["Vegetable poha", "Plain curd"], Day 4 has [" plain curd ", "vegetable POHA"]
    const candidates = buildWeeklyCandidates(3, (d, slot) => {
      if (d === 4 && slot === "breakfast") {
        return { steps: [" plain curd ", "vegetable POHA "] };
      }
      return null;
    });
    stubProviderText(JSON.stringify({ candidates }));
    const response = await worker.fetch(
      request(validRequestBody({ mealsPerDay: 3 })),
      makeEnv() as never,
    );
    const json = (await response.json()) as Record<string, unknown>;

    expect(response.status).toBe(500);
    expect(json.error).toBe("provider_insufficient_diversity");
  });

  test("invalid mealsPerDay outside 3-5 is rejected with 400", async () => {
    const response = await worker.fetch(
      request(validRequestBody({ mealsPerDay: 6 })),
      makeEnv() as never,
    );
    expect(response.status).toBe(400);
    const json = (await response.json()) as Record<string, unknown>;
    expect(json.error).toBe("invalid_eating_request");
  });

  test("candidate with proteinEstimate 0 is rejected", async () => {
    const candidates = buildWeeklyCandidates(3, (d, slot) => {
      if (d === 1 && slot === "breakfast") {
        return { proteinEstimate: 0 };
      }
      return null;
    });
    stubProviderText(JSON.stringify({ candidates }));
    const response = await worker.fetch(
      request(validRequestBody({ mealsPerDay: 3 })),
      makeEnv() as never,
    );
    expect(response.status).toBe(500);
    const json = (await response.json()) as Record<string, unknown>;
    expect(json.error).toBe("provider_incomplete_week");
  });

  test("invalid candidate with generic dishes or missing day is rejected with no fake fallback", async () => {
    stubProviderText(
      JSON.stringify({
        candidates: [
          {
            day: 1,
            mealSlot: "breakfast",
            title: "Breakfast",
            mealCategory: "breakfast",
            startMinute: 480,
            endMinute: 510,
            steps: ["Meal", "Food"],
          },
        ],
      }),
    );
    const response = await worker.fetch(
      request(validRequestBody()),
      makeEnv() as never,
    );
    const text = await response.text();
    const json = JSON.parse(text) as Record<string, unknown>;

    expect(response.status).toBe(500);
    expect(json.error).toBe("provider_empty_candidates");
    expect(json).not.toHaveProperty("candidates");
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

  test("mealTimes parameter provides morning and afternoon snack start times correctly", async () => {
    let capturedPrompt = "";
    vi.stubGlobal(
      "fetch",
      vi.fn(async (url, init: any) => {
        const body = JSON.parse(init.body);
        capturedPrompt = body.contents[0].parts[0].text;
        return new Response(
          JSON.stringify({
            candidates: [{
              content: {
                parts: [{
                  text: JSON.stringify({
                    candidates: buildWeeklyCandidates(5),
                  }),
                }],
              },
            }],
          }),
          { status: 200, headers: { "Content-Type": "application/json" } },
        );
      }),
    );

    const body = validRequestBody({
      mealsPerDay: 5,
      mealTimes: {
        breakfast: 480,
        morning_snack: 650,
        lunch: 780,
        afternoon_snack: 1010,
        dinner: 1230,
      },
    });

    const response = await worker.fetch(
      request(body),
      makeEnv() as never,
    );

    expect(response.status).toBe(200);
    expect(capturedPrompt).toContain("- morning_snack: title \"Morning Snack\", mealCategory \"snack\", startMinute 650");
    expect(capturedPrompt).toContain("- afternoon_snack: title \"Snack\", mealCategory \"snack\", startMinute 1010");
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
