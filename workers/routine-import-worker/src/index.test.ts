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
      "unknown source feature",
      {
        uploadedAssetR2Key:
          "users/uid-1/profile/class_timetable/asset-1.jpg",
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
    [
      "malformed path with ..",
      {
        uploadedAssetR2Key:
          "users/uid-1/../class_timetable/asset-1.jpg",
      },
      "invalid_object_key",
    ],
    [
      "malformed path with backslash",
      {
        uploadedAssetR2Key:
          "users/uid-1\\onboarding/class_timetable/asset-1.jpg",
      },
      "invalid_object_key",
    ],
    [
      "malformed path with double slash",
      {
        uploadedAssetR2Key:
          "users/uid-1//class_timetable/asset-1.jpg",
      },
      "invalid_object_key",
    ],
    [
      "routine_base_timeline wrong owner UID",
      {
        uploadedAssetId: "asset-bt-1",
        uploadedAssetR2Key:
          "users/other-uid/routine_base_timeline/class_timetable/asset-bt-1.jpg",
      },
      "invalid_object_key",
    ],
    [
      "routine_base_timeline wrong purpose for classes",
      {
        source: "classes",
        uploadedAssetId: "asset-bt-1",
        uploadedAssetR2Key:
          "users/uid-1/routine_base_timeline/eating_menu/asset-bt-1.jpg",
      },
      "invalid_object_key",
    ],
    [
      "routine_base_timeline asset ID mismatch",
      {
        uploadedAssetId: "different-id",
        uploadedAssetR2Key:
          "users/uid-1/routine_base_timeline/class_timetable/asset-bt-1.jpg",
      },
      "asset_mismatch",
    ],
    [
      "routine_base_timeline malformed path with ..",
      {
        uploadedAssetId: "asset-bt-1",
        uploadedAssetR2Key:
          "users/uid-1/routine_base_timeline/../class_timetable/asset-bt-1.jpg",
      },
      "invalid_object_key",
    ],
    [
      "routine_base_timeline rejected for eating source",
      {
        source: "eating",
        uploadedAssetId: "asset-bt-1",
        uploadedAssetR2Key:
          "users/uid-1/routine_base_timeline/eating_plan/asset-bt-1.jpg",
      },
      "invalid_object_key",
    ],
    [
      "routine_base_timeline rejected for skincare source",
      {
        source: "skinCare",
        uploadedAssetId: "asset-bt-1",
        uploadedAssetR2Key:
          "users/uid-1/routine_base_timeline/skin_care/asset-bt-1.jpg",
      },
      "invalid_object_key",
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

  test("accepts routine_base_timeline class photo and extracts candidates", async () => {
    const btObjectKey = "users/uid-1/routine_base_timeline/class_timetable/asset-bt-1.jpg";
    stubGemini(200, {
      candidates: [
        {
          content: {
            parts: [
              {
                text: JSON.stringify({
                  id: "ext-1",
                  uid: "uid-1",
                  source: "classes",
                  engine: "gemini",
                  engineVersion: "phase2d",
                  sourceAssetId: "asset-bt-1",
                  sourceR2Key: btObjectKey,
                  candidates: [
                    {
                      id: "c1",
                      title: "Data Structures",
                      candidateType: "block",
                      startMinute: 480,
                      endMinute: 540,
                      hasFixedTime: true,
                      repeatDays: [1, 3],
                      blockType: "hard_block",
                      category: "classBlock",
                      hardBlock: true,
                      selected: true,
                      needsManualReview: false,
                      confidenceScore: 0.9,
                      confidenceLabel: "high",
                      validationIssues: [],
                      courseCode: "CS201",
                      classType: "Lecture",
                      instructor: "Prof. Sharma",
                      sectionLabel: "Batch A",
                      location: "Room C25-B-301",
                      notes: "Bring laptop",
                      steps: [],
                    },
                  ],
                  warnings: [],
                  createdAt: new Date().toISOString(),
                }),
              },
            ],
          },
        },
      ],
    });

    const env = makeEnv();
    const response = await worker.fetch(
      request({
        reviewId: "review-bt-1",
        source: "classes",
        uploadedAssetId: "asset-bt-1",
        uploadedAssetR2Key: btObjectKey,
        sourceLabel: "Classes",
      }),
      env as never,
    );

    expect(response.status).toBe(200);
    expect(env.UPLOAD_BUCKET.get).toHaveBeenCalledWith(btObjectKey);
    const json = await response.json() as {
      candidates: Array<Record<string, unknown>>;
      source: string;
      sourceR2Key: string;
    };
    expect(json.source).toBe("classes");
    expect(json.sourceR2Key).toBe(btObjectKey);
    expect(json.candidates.length).toBe(1);
    const candidate = json.candidates[0];
    expect(candidate.title).toBe("Data Structures");
    expect(candidate.courseCode).toBe("CS201");
    expect(candidate.classType).toBe("Lecture");
    expect(candidate.instructor).toBe("Prof. Sharma");
    expect(candidate.sectionLabel).toBe("Batch A");
    expect(candidate.location).toBe("Room C25-B-301");
    expect(candidate.notes).toBe("Bring laptop");
  });

  test("fake extractor preserves structured class metadata", async () => {
    const env = makeEnv({ AI_PROVIDER: "fake" });
    const response = await worker.fetch(
      request(extractionBody()),
      env as never,
    );
    expect(response.status).toBe(200);
    const json = await response.json() as {
      candidates: Array<Record<string, unknown>>;
    };
    expect(json.candidates.length).toBeGreaterThan(0);
    const mathClass = json.candidates.find((c) => c.id === "ai_class_math");
    expect(mathClass).toBeDefined();
    expect(mathClass!.courseCode).toBe("MATH101");
    expect(mathClass!.classType).toBe("Lecture");
    expect(mathClass!.instructor).toBe("Prof. Sharma");
    expect(mathClass!.sectionLabel).toBe("Sec A");
    expect(mathClass!.location).toBe("Hall B-12");
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

  test("accepts routine_base_timeline work photo and extracts candidates with normalized work metadata", async () => {
    const btWorkObjectKey = "users/uid-1/routine_base_timeline/work_schedule/asset-work-1.jpg";
    stubGemini(200, {
      candidates: [
        {
          content: {
            parts: [
              {
                text: JSON.stringify({
                  id: "ext-work-1",
                  uid: "uid-1",
                  source: "work",
                  engine: "gemini",
                  engineVersion: "phase2d",
                  sourceAssetId: "asset-work-1",
                  sourceR2Key: btWorkObjectKey,
                  candidates: [
                    {
                      id: "w1",
                      title: "Product Engineering",
                      candidateType: "block",
                      startMinute: 540,
                      endMinute: 1020,
                      hasFixedTime: true,
                      repeatDays: [1, 2, 3, 4, 5],
                      blockType: "hard_block",
                      category: "workBlock",
                      hardBlock: true,
                      selected: true,
                      needsManualReview: false,
                      confidenceScore: 0.95,
                      confidenceLabel: "high",
                      validationIssues: [],
                      organization: "Acme Corp",
                      role: "Staff Engineer",
                      workContextType: "employment",
                      workMode: "in-person",
                      workBlockKind: "team sync",
                      department: "Core Platform",
                      location: "Floor 4, Pod B",
                      steps: [],
                    },
                    {
                      id: "w2",
                      title: "Consulting Session",
                      candidateType: "block",
                      startMinute: 1080,
                      endMinute: 1140,
                      hasFixedTime: true,
                      repeatDays: [2, 4],
                      blockType: "hard_block",
                      category: "workBlock",
                      hardBlock: true,
                      selected: true,
                      needsManualReview: false,
                      confidenceScore: 0.85,
                      confidenceLabel: "medium",
                      validationIssues: [],
                      organization: "Self",
                      role: "Advisor",
                      workContextType: "unsupported_context_garbage",
                      workMode: "invalid_alien_mode",
                      workBlockKind: "lunch break",
                      steps: [],
                    },
                  ],
                  warnings: [],
                  createdAt: new Date().toISOString(),
                }),
              },
            ],
          },
        },
      ],
    });

    const env = makeEnv();
    const response = await worker.fetch(
      request({
        reviewId: "review-bt-work-1",
        source: "work",
        uploadedAssetId: "asset-work-1",
        uploadedAssetR2Key: btWorkObjectKey,
        sourceLabel: "Work Schedule",
      }),
      env as never,
    );

    expect(response.status).toBe(200);
    expect(env.UPLOAD_BUCKET.get).toHaveBeenCalledWith(btWorkObjectKey);
    const json = await response.json() as {
      candidates: Array<Record<string, unknown>>;
      source: string;
      sourceR2Key: string;
    };
    expect(json.source).toBe("work");
    expect(json.sourceR2Key).toBe(btWorkObjectKey);
    expect(json.candidates.length).toBe(2);

    const c1 = json.candidates[0];
    expect(c1.title).toBe("Product Engineering");
    expect(c1.workOrganization).toBe("Acme Corp");
    expect(c1.workRole).toBe("Staff Engineer");
    // Aliases normalized properly
    expect(c1.workContextType).toBe("job");
    expect(c1.workMode).toBe("in_person");
    expect(c1.workBlockKind).toBe("team_sync");
    expect(c1.workDepartmentOrProject).toBe("Core Platform");
    expect(c1.location).toBe("Floor 4, Pod B");

    const c2 = json.candidates[1];
    expect(c2.title).toBe("Consulting Session");
    // Unsupported enums dropped to undefined (not retained as garbage)
    expect(c2.workContextType).toBeUndefined();
    expect(c2.workMode).toBeUndefined();
    // Normalization of 'lunch break' to 'break'
    expect(c2.workBlockKind).toBe("break");
  });

  test("preserves canonical work enums and ensures anti-hallucination undefined defaults for minimal schedule", async () => {
    const btWorkObjectKey = "users/uid-1/routine_base_timeline/work_schedule/asset-work-2.jpg";
    stubGemini(200, {
      candidates: [
        {
          content: {
            parts: [
              {
                text: JSON.stringify({
                  id: "ext-work-2",
                  uid: "uid-1",
                  source: "work",
                  engine: "gemini",
                  engineVersion: "phase2d",
                  sourceAssetId: "asset-work-2",
                  sourceR2Key: btWorkObjectKey,
                  candidates: [
                    {
                      id: "w-canonical-1",
                      title: "Platform Foundation",
                      candidateType: "block",
                      startMinute: 600,
                      endMinute: 720,
                      hasFixedTime: true,
                      repeatDays: [1, 3, 5],
                      blockType: "hard_block",
                      category: "workBlock",
                      hardBlock: true,
                      selected: true,
                      confidenceScore: 0.9,
                      confidenceLabel: "high",
                      workContextType: "startup",
                      workMode: "field",
                      workBlockKind: "project_work",
                      steps: [],
                    },
                    {
                      id: "w-canonical-2",
                      title: "Operations Oversight",
                      candidateType: "block",
                      startMinute: 780,
                      endMinute: 960,
                      hasFixedTime: true,
                      repeatDays: [2, 4],
                      blockType: "hard_block",
                      category: "workBlock",
                      hardBlock: true,
                      selected: true,
                      confidenceScore: 0.88,
                      confidenceLabel: "high",
                      workMode: "mixed",
                      workBlockKind: "business_hours",
                      steps: [],
                    },
                    {
                      id: "w-minimal-3",
                      title: "Shift",
                      candidateType: "block",
                      startMinute: 540,
                      endMinute: 1020,
                      hasFixedTime: true,
                      repeatDays: [1, 2, 3, 4, 5],
                      blockType: "hard_block",
                      category: "workBlock",
                      hardBlock: true,
                      selected: true,
                      confidenceScore: 0.8,
                      confidenceLabel: "high",
                      steps: [],
                    },
                  ],
                  warnings: [],
                  createdAt: new Date().toISOString(),
                }),
              },
            ],
          },
        },
      ],
    });

    const env = makeEnv();
    const response = await worker.fetch(
      request({
        reviewId: "review-bt-work-2",
        source: "work",
        uploadedAssetId: "asset-work-2",
        uploadedAssetR2Key: btWorkObjectKey,
        sourceLabel: "Work Schedule",
      }),
      env as never,
    );

    expect(response.status).toBe(200);
    const json = await response.json() as {
      candidates: Array<Record<string, unknown>>;
    };
    expect(json.candidates.length).toBe(3);

    // Canonical enums survive exactly
    const c1 = json.candidates[0];
    expect(c1.workContextType).toBe("startup");
    expect(c1.workMode).toBe("field");
    expect(c1.workBlockKind).toBe("project_work");

    const c2 = json.candidates[1];
    expect(c2.workMode).toBe("mixed");
    expect(c2.workBlockKind).toBe("business_hours");

    // Minimal schedule must NOT hallucinate role, org, mode, or block kind
    const c3 = json.candidates[2];
    expect(c3.title).toBe("Shift");
    expect(c3.workOrganization).toBeUndefined();
    expect(c3.workRole).toBeUndefined();
    expect(c3.workDepartmentOrProject).toBeUndefined();
    expect(c3.workMode).toBeUndefined();
    expect(c3.workBlockKind).toBeUndefined();
    expect(c3.workContextType).toBeUndefined();
  });
});
