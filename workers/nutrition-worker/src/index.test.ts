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
    ["Oatmeal with Almonds", "Chia pudding"],
    ["Idli sambar", "Coconut chutney"],
    ["Moong dal cheela", "Mint chutney"],
    ["Whole wheat toast", "Avocado spread"],
    ["Besan cheela", "Curd"],
    ["Paneer bhurji", "Roti"],
  ];
  const morningSnackDishes = [
    ["Apple slices", "Walnut butter"],
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
    ["Grilled Paneer", "Steamed asparagus", "Millet"],
    ["Chickpea curry", "Roti", "Kachumber"],
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
      aiModel: "gemini-test",
      aiFallbackModel: "gemini-test",
    });
  });

  test("health endpoint defaults to gemini-3.8-flash and gemini-3.7-flash when model env vars are absent", async () => {
    const response = await worker.fetch(
      new Request("https://nutrition-worker.test/health"),
      makeEnv({ AI_MODEL: undefined, AI_FALLBACK_MODEL: undefined }) as never,
    );
    const json = (await response.json()) as Record<string, unknown>;

    expect(response.status).toBe(200);
    expect(json).toMatchObject({
      ok: true,
      service: "nutrition-worker",
      projectId: "test-project",
      aiProvider: "gemini",
      aiModel: "gemini-3.8-flash",
      aiFallbackModel: "gemini-3.7-flash",
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

  test("repair loop: succeeds on attempt 2 when attempt 1 misses a meal slot", async () => {
    const invalidCandidates = buildWeeklyCandidates(3).filter(
      (c) => !(c.day === 7 && c.mealSlot === "dinner"),
    );
    const validCandidates = buildWeeklyCandidates(3);

    const prompts: string[] = [];
    let callCount = 0;
    vi.stubGlobal(
      "fetch",
      vi.fn(async (_url, init: any) => {
        callCount++;
        const body = JSON.parse(init.body);
        prompts.push(body.contents[0].parts[0].text);
        const candidates = callCount === 1 ? invalidCandidates : validCandidates;
        return new Response(
          JSON.stringify({
            candidates: [{ content: { parts: [{ text: JSON.stringify({ candidates }) }] } }],
          }),
          { status: 200, headers: { "Content-Type": "application/json" } },
        );
      }),
    );

    const response = await worker.fetch(
      request(validRequestBody({ mealsPerDay: 3 })),
      makeEnv() as never,
    );

    expect(response.status).toBe(200);
    const json = (await response.json()) as Record<string, unknown>;
    expect(json.candidates).toHaveLength(21);
    expect(callCount).toBe(2);
    // Second prompt should contain repair feedback about the missing dinner on day 7
    expect(prompts[1]).toContain("CRITICAL REPAIR INSTRUCTIONS:");
    expect(prompts[1]).toContain('day 7 slot "dinner"');
  });

  test("repair loop: succeeds on attempt 2 when attempt 1 has calorie mismatch", async () => {
    const invalidCandidates = buildWeeklyCandidates(3, (d, slot) => {
      if (d === 3 && slot === "breakfast") {
        return { caloriesEstimate: 200 };
      }
      return null;
    });
    const validCandidates = buildWeeklyCandidates(3);

    let callCount = 0;
    const prompts: string[] = [];
    vi.stubGlobal(
      "fetch",
      vi.fn(async (_url, init: any) => {
        callCount++;
        const body = JSON.parse(init.body);
        prompts.push(body.contents[0].parts[0].text);
        const candidates = callCount === 1 ? invalidCandidates : validCandidates;
        return new Response(
          JSON.stringify({
            candidates: [{ content: { parts: [{ text: JSON.stringify({ candidates }) }] } }],
          }),
          { status: 200, headers: { "Content-Type": "application/json" } },
        );
      }),
    );

    const response = await worker.fetch(
      request(validRequestBody({ mealsPerDay: 3, targetCalories: 2100 })),
      makeEnv() as never,
    );

    expect(response.status).toBe(200);
    const json = (await response.json()) as Record<string, unknown>;
    expect(json.candidates).toHaveLength(21);
    expect(callCount).toBe(2);
    expect(prompts[1]).toContain("CRITICAL REPAIR INSTRUCTIONS:");
    expect(prompts[1]).toContain("calorie sum was 1700 kcal");
  });

  test("repair loop: returns safe 500 when both attempt 1 and 2 fail validation", async () => {
    const invalidCandidates = buildWeeklyCandidates(3, (d, slot) => {
      if (d === 3 && slot === "breakfast") {
        return { caloriesEstimate: 200 };
      }
      return null;
    });

    let callCount = 0;
    vi.stubGlobal(
      "fetch",
      vi.fn(async () => {
        callCount++;
        return new Response(
          JSON.stringify({
            candidates: [{ content: { parts: [{ text: JSON.stringify({ candidates: invalidCandidates }) }] } }],
          }),
          { status: 200, headers: { "Content-Type": "application/json" } },
        );
      }),
    );

    const response = await worker.fetch(
      request(validRequestBody({ mealsPerDay: 3, targetCalories: 2100 })),
      makeEnv() as never,
    );

    expect(response.status).toBe(500);
    const json = (await response.json()) as Record<string, unknown>;
    expect(json.error).toBe("provider_target_mismatch");
    expect(json.message).toContain("deviated from target (2100)");
    expect(json).not.toHaveProperty("candidates");
    expect(callCount).toBe(2);
  });

  test("uses default gemini-3.8-flash primary and gemini-3.7-flash fallback when model env vars are absent", async () => {
    const fetchCalls: string[] = [];
    vi.stubGlobal(
      "fetch",
      vi.fn(async (url: string) => {
        fetchCalls.push(url);
        return new Response(
          JSON.stringify({
            candidates: [
              {
                content: {
                  parts: [
                    {
                      text: JSON.stringify({
                        candidates: buildWeeklyCandidates(3),
                      }),
                    },
                  ],
                },
              },
            ],
          }),
          { status: 200, headers: { "Content-Type": "application/json" } },
        );
      }),
    );

    const response = await worker.fetch(
      request(validRequestBody()),
      makeEnv({ AI_MODEL: undefined, AI_FALLBACK_MODEL: undefined }) as never,
    );
    expect(response.status).toBe(200);
    expect(fetchCalls.length).toBeGreaterThanOrEqual(1);
    expect(fetchCalls[0]).toContain("/models/gemini-3.8-flash:generateContent");
  });

  test("falls back to default gemini-3.7-flash when primary model fails without env vars", async () => {
    const fetchCalls: string[] = [];
    vi.stubGlobal(
      "fetch",
      vi.fn(async (url: string) => {
        fetchCalls.push(url);
        if (url.includes("gemini-3.8-flash")) {
          return new Response(JSON.stringify({ error: "server error" }), { status: 500 });
        }
        return new Response(
          JSON.stringify({
            candidates: [
              {
                content: {
                  parts: [
                    {
                      text: JSON.stringify({
                        candidates: buildWeeklyCandidates(3),
                      }),
                    },
                  ],
                },
              },
            ],
          }),
          { status: 200, headers: { "Content-Type": "application/json" } },
        );
      }),
    );

    const response = await worker.fetch(
      request(validRequestBody()),
      makeEnv({ AI_MODEL: undefined, AI_FALLBACK_MODEL: undefined }) as never,
    );
    expect(response.status).toBe(200);
    expect(fetchCalls.length).toBe(2);
    expect(fetchCalls[0]).toContain("/models/gemini-3.8-flash:generateContent");
    expect(fetchCalls[1]).toContain("/models/gemini-3.7-flash:generateContent");
  });

  test("structured output: Gemini request includes responseSchema and thinkingConfig with medium level on attempt 1", async () => {
    let capturedBody: any = null;
    vi.stubGlobal(
      "fetch",
      vi.fn(async (_url: string, init: any) => {
        capturedBody = JSON.parse(init.body);
        return new Response(
          JSON.stringify({
            candidates: [
              {
                content: {
                  parts: [
                    {
                      text: JSON.stringify({
                        candidates: buildWeeklyCandidates(3),
                      }),
                    },
                  ],
                },
              },
            ],
          }),
          { status: 200, headers: { "Content-Type": "application/json" } },
        );
      }),
    );

    const response = await worker.fetch(
      request(validRequestBody()),
      makeEnv() as never,
    );
    expect(response.status).toBe(200);
    expect(capturedBody).toBeDefined();
    expect(capturedBody.generationConfig).toBeDefined();
    expect(capturedBody.generationConfig.responseMimeType).toBe("application/json");
    expect(capturedBody.generationConfig.responseSchema).toBeDefined();
    expect(capturedBody.generationConfig.responseSchema.type).toBe("OBJECT");
    expect(capturedBody.generationConfig.responseSchema.properties.candidates.type).toBe("ARRAY");
    expect(capturedBody.generationConfig.thinkingConfig).toEqual({ thinkingLevel: "medium" });
  });

  test("semantic repair: uses thinkingLevel high on attempt 2 on primary model", async () => {
    const invalidCandidates = buildWeeklyCandidates(3).filter(
      (c) => !(c.day === 7 && c.mealSlot === "dinner"),
    );
    const validCandidates = buildWeeklyCandidates(3);
    const capturedBodies: any[] = [];

    vi.stubGlobal(
      "fetch",
      vi.fn(async (_url: string, init: any) => {
        capturedBodies.push(JSON.parse(init.body));
        const candidates = capturedBodies.length === 1 ? invalidCandidates : validCandidates;
        return new Response(
          JSON.stringify({
            candidates: [
              {
                content: {
                  parts: [
                    {
                      text: JSON.stringify({ candidates }),
                    },
                  ],
                },
              },
            ],
          }),
          { status: 200, headers: { "Content-Type": "application/json" } },
        );
      }),
    );

    const response = await worker.fetch(
      request(validRequestBody()),
      makeEnv() as never,
    );
    expect(response.status).toBe(200);
    expect(capturedBodies.length).toBe(2);
    expect(capturedBodies[0].generationConfig.thinkingConfig).toEqual({ thinkingLevel: "medium" });
    expect(capturedBodies[1].generationConfig.thinkingConfig).toEqual({ thinkingLevel: "high" });
  });

  test("structured output: items are summed server-side into meal estimates and formatted into portion steps", async () => {
    const structuredCandidates: Record<string, unknown>[] = [];
    const baseWeekly = buildWeeklyCandidates(3);
    for (const base of baseWeekly) {
      const mainDish = (base.steps as string[])[0];
      const sideDish = (base.steps as string[])[1] || "Side Salad";
      structuredCandidates.push({
        day: base.day,
        mealSlot: base.mealSlot,
        items: [
          { name: mainDish, quantity: 80, unit: "g", caloriesEstimate: 310, proteinEstimate: 11 },
          { name: sideDish, quantity: 2, unit: "tbsp", caloriesEstimate: Number(base.caloriesEstimate) - 310, proteinEstimate: Number(base.proteinEstimate) - 11 },
        ],
      });
    }

    stubProviderText(JSON.stringify({ candidates: structuredCandidates }));

    const response = await worker.fetch(
      request(validRequestBody({ mealsPerDay: 3, targetCalories: 2100 })),
      makeEnv() as never,
    );
    expect(response.status).toBe(200);
    const json = (await response.json()) as { candidates: Array<Record<string, unknown>> };
    expect(json.candidates).toHaveLength(21);
    const day1Breakfast = json.candidates[0];
    expect(day1Breakfast.steps).toEqual([
      `${(baseWeekly[0].steps as string[])[0]} — 80 g`,
      `${(baseWeekly[0].steps as string[])[1]} — 2 tbsp`,
    ]);
    expect(day1Breakfast.caloriesEstimate).toBe(600);
    expect(day1Breakfast.proteinEstimate).toBe(20);
    expect(day1Breakfast.items).toBeDefined();
  });

  test("dietary validation: vegetarian rejects meat and poultry", async () => {
    const candidatesWithMeat = buildWeeklyCandidates(3, (d, slot) => {
      if (d === 1 && slot === "lunch") {
        return { steps: ["Grilled Chicken Breast", "Steamed Broccoli"] };
      }
      return null;
    });

    stubProviderText(JSON.stringify({ candidates: candidatesWithMeat }));

    const response = await worker.fetch(
      request(validRequestBody({ foodType: "vegetarian" })),
      makeEnv() as never,
    );
    expect(response.status).toBe(500);
    const json = (await response.json()) as Record<string, unknown>;
    expect(json.error).toBe("provider_diet_violation");
    expect(json.message).toContain("chicken");
  });

  test("dietary validation: vegetarian rejects eggs (eggetarian allows them)", async () => {
    const candidatesWithEgg = buildWeeklyCandidates(3, (d, slot) => {
      if (d === 1 && slot === "breakfast") {
        return { steps: ["Boiled egg", "Whole wheat toast"] };
      }
      return null;
    });

    // In vegetarian mode -> rejected
    stubProviderText(JSON.stringify({ candidates: candidatesWithEgg }));
    const vegResponse = await worker.fetch(
      request(validRequestBody({ foodType: "vegetarian" })),
      makeEnv() as never,
    );
    expect(vegResponse.status).toBe(500);
    expect(((await vegResponse.json()) as Record<string, unknown>).error).toBe("provider_diet_violation");

    // In eggetarian mode -> accepted
    stubProviderText(JSON.stringify({ candidates: candidatesWithEgg }));
    const eggetResponse = await worker.fetch(
      request(validRequestBody({ foodType: "eggetarian" })),
      makeEnv() as never,
    );
    expect(eggetResponse.status).toBe(200);
  });

  test("dietary validation: vegan rejects dairy and eggs", async () => {
    const candidatesWithDairy = buildWeeklyCandidates(3, (d, slot) => {
      if (d === 1 && slot === "lunch") {
        return { steps: ["Paneer Curry", "Brown rice"] };
      }
      return {
        steps: [
          `Tofu Dish Day ${d} ${slot}`,
          `Steamed Veggies ${d}`,
          `Quinoa ${slot}`,
        ],
        caloriesEstimate: slot === "breakfast" ? 600 : 750,
        proteinEstimate: slot === "breakfast" ? 20 : 30,
      };
    });

    stubProviderText(JSON.stringify({ candidates: candidatesWithDairy }));
    const response = await worker.fetch(
      request(validRequestBody({ foodType: "vegan" })),
      makeEnv() as never,
    );
    expect(response.status).toBe(500);
    const json = (await response.json()) as Record<string, unknown>;
    expect(json.error).toBe("provider_diet_violation");
    expect(json.message).toContain("dairy");
  });

  test("dietary validation: false-positive protection allows eggplant, chickpeas, and sweet potato", async () => {
    const candidatesWithVegetables = buildWeeklyCandidates(3, (d, slot) => {
      if (d === 1 && slot === "lunch") {
        return { steps: ["Chickpea Curry", "Eggplant Bharta", "Steamed Rice"] };
      }
      return null;
    });

    stubProviderText(JSON.stringify({ candidates: candidatesWithVegetables }));
    const response = await worker.fetch(
      request(validRequestBody({ foodType: "vegetarian" })),
      makeEnv() as never,
    );
    expect(response.status).toBe(200);
  });

  test("dietary validation: vegan allows plant-based milks and nut butters", async () => {
    const candidatesWithPlantBased = buildWeeklyCandidates(3, (d, slot) => {
      if (d === 1 && slot === "breakfast") {
        return { steps: ["Oatmeal with Almond Milk", "Peanut Butter Toast"] };
      }
      return {
        steps: [
          `Tofu Sauté Day ${d} ${slot}`,
          `Brown Rice ${d}`,
          `Greens ${slot}`,
        ],
        caloriesEstimate: slot === "breakfast" ? 600 : 750,
        proteinEstimate: slot === "breakfast" ? 20 : 30,
      };
    });

    stubProviderText(JSON.stringify({ candidates: candidatesWithPlantBased }));
    const response = await worker.fetch(
      request(validRequestBody({ foodType: "vegan" })),
      makeEnv() as never,
    );
    expect(response.status).toBe(200);
  });

  test("dietary validation: repair loop recovers from diet violation on attempt 2", async () => {
    const invalidCandidates = buildWeeklyCandidates(3, (d, slot) => {
      if (d === 1 && slot === "lunch") {
        return { steps: ["Grilled Salmon", "Steamed Rice"] };
      }
      return null;
    });
    const validCandidates = buildWeeklyCandidates(3, (d, slot) => {
      if (d === 1 && slot === "lunch") {
        return { steps: ["Paneer Curry", "Brown Rice"] };
      }
      return null;
    });

    let callCount = 0;
    const prompts: string[] = [];
    vi.stubGlobal(
      "fetch",
      vi.fn(async (_url: string, init: any) => {
        callCount++;
        const body = JSON.parse(init.body);
        prompts.push(body.contents[0].parts[0].text);
        const candidates = callCount === 1 ? invalidCandidates : validCandidates;
        return new Response(
          JSON.stringify({
            candidates: [{ content: { parts: [{ text: JSON.stringify({ candidates }) }] } }],
          }),
          { status: 200, headers: { "Content-Type": "application/json" } },
        );
      }),
    );

    const response = await worker.fetch(
      request(validRequestBody({ foodType: "vegetarian" })),
      makeEnv() as never,
    );

    expect(response.status).toBe(200);
    expect(callCount).toBe(2);
    expect(prompts[1]).toContain("CRITICAL REPAIR INSTRUCTIONS:");
    expect(prompts[1]).toContain("Diet violation detected");
    expect(prompts[1]).toContain("Grilled Salmon");
  });

  test("foodsToAvoid: user-specified avoided ingredients are rejected and trigger repair", async () => {
    const candidatesWithPeanuts = buildWeeklyCandidates(3, (d, slot) => {
      if (d === 1 && slot === "breakfast") {
        return { steps: ["Peanut Butter Toast", "Banana Slices"] };
      }
      return null;
    });

    stubProviderText(JSON.stringify({ candidates: candidatesWithPeanuts }));
    const response = await worker.fetch(
      request(validRequestBody({ foodsToAvoid: "peanuts, mushrooms" })),
      makeEnv() as never,
    );

    expect(response.status).toBe(500);
    const json = (await response.json()) as Record<string, unknown>;
    expect(json.error).toBe("provider_diet_violation");
    expect(json.message).toContain("Contains avoided ingredient \"peanuts\"");
  });

  test("personalization: exerciseLevel, lifeRole, country, and foodsToAvoid are passed in prompt", async () => {
    let capturedPrompt = "";
    vi.stubGlobal(
      "fetch",
      vi.fn(async (_url: string, init: any) => {
        const body = JSON.parse(init.body);
        capturedPrompt = body.contents[0].parts[0].text;
        return new Response(
          JSON.stringify({
            candidates: [{ content: { parts: [{ text: JSON.stringify({ candidates: buildWeeklyCandidates(3) }) }] } }],
          }),
          { status: 200, headers: { "Content-Type": "application/json" } },
        );
      }),
    );

    const response = await worker.fetch(
      request(validRequestBody({
        exerciseLevel: "high_intensity",
        lifeRole: "software_engineer",
        country: "India",
        foodsToAvoid: "shellfish, pork",
      })),
      makeEnv() as never,
    );

    expect(response.status).toBe(200);
    expect(capturedPrompt).toContain("- Exercise Level: high_intensity");
    expect(capturedPrompt).toContain("- Life Role: software_engineer");
    expect(capturedPrompt).toContain("- Country / Region: India");
    expect(capturedPrompt).toContain("- Foods to Avoid: shellfish, pork");
  });

  test("429 quota exceeded: does NOT bounce to secondary model and returns provider_quota_exceeded", async () => {
    let fetchCount = 0;
    vi.stubGlobal(
      "fetch",
      vi.fn(async () => {
        fetchCount++;
        return new Response(
          JSON.stringify({ error: { code: 429, message: "RESOURCE_EXHAUSTED" } }),
          { status: 429, headers: { "Content-Type": "application/json" } },
        );
      }),
    );

    const response = await worker.fetch(
      request(validRequestBody()),
      makeEnv({ AI_FALLBACK_MODEL: "gemini-3.7-flash" }) as never,
    );

    expect(response.status).toBe(429);
    const json = (await response.json()) as Record<string, unknown>;
    expect(json.error).toBe("provider_quota_exceeded");
    expect(fetchCount).toBe(1); // Crucial: must NOT bounce to fallback on 429
  });

  test("observability: responses include requestId and health endpoint returns version", async () => {
    stubProviderText(JSON.stringify({ candidates: buildWeeklyCandidates(3) }));
    const genResponse = await worker.fetch(
      request(validRequestBody(), {
        Authorization: "Bearer valid-token",
        "Content-Type": "application/json",
        "x-request-id": "client-req-12345",
      }),
      makeEnv() as never,
    );

    expect(genResponse.status).toBe(200);
    expect(genResponse.headers.get("x-request-id")).toBe("client-req-12345");
    const genJson = (await genResponse.json()) as Record<string, unknown>;
    expect(genJson.requestId).toBe("client-req-12345");

    const healthResponse = await worker.fetch(
      new Request("https://nutrition-worker.test/health"),
      makeEnv() as never,
    );
    const healthJson = (await healthResponse.json()) as Record<string, unknown>;
    expect(healthJson.version).toBe("0.2.0");
  });
});

