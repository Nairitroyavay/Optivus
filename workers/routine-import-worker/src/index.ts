import { createRemoteJWKSet, jwtVerify } from "jose";

type Env = {
  FIREBASE_PROJECT_ID: string;
  R2_BUCKET_NAME: string;
  MAX_IMAGE_BYTES?: string;
  GEMINI_INLINE_MAX_IMAGE_BYTES?: string;
  AI_PROVIDER?: string;
  AI_MODEL?: string;
  AI_FALLBACK_MODEL?: string;
  OPENAI_API_KEY?: string;
  GEMINI_API_KEY?: string;
  ALLOWED_ORIGINS?: string;
  UPLOAD_BUCKET: R2Bucket;
};

type RoutineImportReviewSource = "classes" | "work" | "eating" | "skinCare";
type RoutineImportCandidateType =
  | "block"
  | "flexibleTask"
  | "checklistStep"
  | "note"
  | "unknown";
type ConfidenceLabel = "high" | "medium" | "low";
type ExtractionEngine =
  | "disabled"
  | "fake"
  | "gemini"
  | "openai"
  | "aiVision"
  | "aiText";

type RoutineImportExtractionResponse = {
  id: string;
  uid: string;
  source: RoutineImportReviewSource;
  engine: ExtractionEngine;
  engineVersion: string;
  sourceAssetId?: string;
  sourceR2Key?: string;
  rawText?: string;
  candidates: RoutineImportCandidate[];
  warnings: string[];
  createdAt: string;
};

type RoutineImportCandidate = {
  id: string;
  title: string;
  candidateType: RoutineImportCandidateType;
  startMinute: number;
  endMinute: number;
  hasFixedTime: boolean;
  suggestedStartMinute?: number;
  suggestedEndMinute?: number;
  repeatDays: number[];
  blockType: string;
  category: string;
  hardBlock: boolean;
  selected: boolean;
  needsManualReview: boolean;
  confidenceScore?: number;
  confidenceLabel?: ConfidenceLabel;
  validationIssues: string[];
  sourceAssetId?: string;
  sourceR2Key?: string;
  sourceTextSnippet?: string;
  sourcePageIndex?: number;
  sourceImageIndex?: number;
  sourceRowLabel?: string;
  sourceColumnLabel?: string;
  sourceBoundingBox?: Record<string, unknown>;
  extractionEngine: string;
  extractionVersion?: string;
  location?: string;
  notes?: string;
  mealCategory?: string;
  steps: string[];
};

type ExtractArgs = {
  uid: string;
  reviewId: string;
  source: RoutineImportReviewSource;
  sourceLabel: string;
  imageBytes: ArrayBuffer;
  contentType: string;
  objectKey: string;
  uploadedAssetId?: string;
};

type VerifiedUser = {
  uid: string;
};

const SOURCE_IMAGE_MAX_BYTES = 15 * 1024 * 1024;
const GEMINI_INLINE_MAX_IMAGE_BYTES = 11 * 1024 * 1024;
const DEFAULT_GEMINI_MODEL = "gemini-2.5-flash";
const INLINE_IMAGE_TOO_LARGE_WARNING =
  "This photo is saved, but it is too large for AI extraction. Please upload a sharper photo under 11 MB or use manual review.";
const HARD_TO_READ_WARNING =
  "This photo is hard to read. Retake a sharper image or review manually.";

interface AiRoutineExtractor {
  extract(args: ExtractArgs): Promise<RoutineImportExtractionResponse>;
}

const firebaseJwks = createRemoteJWKSet(
  new URL(
    "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com",
  ),
);

const sourcePurpose: Record<RoutineImportReviewSource, string> = {
  classes: "class_timetable",
  work: "work_schedule",
  eating: "eating_menu",
  skinCare: "skin_care",
};

const sourceCategory: Record<RoutineImportReviewSource, string> = {
  classes: "classBlock",
  work: "job",
  eating: "eating",
  skinCare: "skinCare",
};

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: corsHeaders(request, env) });
    }

    try {
      const url = new URL(request.url);
      if (request.method === "GET" && url.pathname === "/health") {
        const projectId = requiredEnv(env.FIREBASE_PROJECT_ID, "FIREBASE_PROJECT_ID");
        const bucket = requiredEnv(env.R2_BUCKET_NAME, "R2_BUCKET_NAME");
        return jsonResponse(request, env, {
          ok: true,
          service: "routine-import-worker",
          projectId,
          bucket,
          aiProvider: aiProviderName(env),
        });
      }

      if (request.method === "POST" && url.pathname === "/v1/routine-import/extract") {
        return handleExtract(request, env);
      }

      return jsonResponse(request, env, { error: "not_found" }, 404);
    } catch (error) {
      const httpError = error instanceof HttpError ? error : null;
      return jsonResponse(
        request,
        env,
        {
          error: httpError?.code ?? "internal_error",
          message: httpError?.message ?? "Routine import worker error.",
        },
        httpError?.status ?? 500,
      );
    }
  },
};

async function handleExtract(request: Request, env: Env): Promise<Response> {
  const user = await requireVerifiedFirebaseUser(request, env);
  const body = await readSmallJson(request);
  const reviewId = readString(body, "reviewId");
  const source = readSource(body, "source");
  const sourceLabel = readOptionalString(body, "sourceLabel") ?? labelForSource(source);
  const uploadedAssetId = readOptionalString(body, "uploadedAssetId");
  const uploadedAssetR2Key = readString(body, "uploadedAssetR2Key");

  assertOwnedRoutineImportObjectKey({
    uid: user.uid,
    source,
    objectKey: uploadedAssetR2Key,
    uploadedAssetId,
  });

  const object = await requiredUploadBucket(env).get(uploadedAssetR2Key);
  if (!object) {
    throw new HttpError(404, "source_image_not_found", "Uploaded source image was not found.");
  }

  const maxBytes = sourceImageMaxBytes(env);
  if (typeof object.size === "number" && object.size > maxBytes) {
    throw new HttpError(413, "image_too_large", "This photo is too large. Please upload a photo under 15 MB.");
  }

  const contentType = object.httpMetadata?.contentType ?? "image/jpeg";
  if (!isAllowedSourceContentType(contentType)) {
    throw new HttpError(
      400,
      "invalid_source_content_type",
      "Please upload JPEG, PNG, or WEBP for now.",
    );
  }

  const normalizedSourceContentType = normalizedContentType(contentType);
  if (
    aiProviderName(env) === "gemini" &&
    typeof object.size === "number" &&
    object.size > geminiInlineMaxImageBytes(env, maxBytes)
  ) {
    const raw = inlineImageTooLargeFallback(
      {
        uid: user.uid,
        reviewId,
        source,
        sourceLabel,
        imageBytes: new ArrayBuffer(0),
        contentType: normalizedSourceContentType,
        objectKey: uploadedAssetR2Key,
        uploadedAssetId,
      },
      "gemini",
      env.AI_MODEL?.trim() || DEFAULT_GEMINI_MODEL,
    );
    return jsonResponse(
      request,
      env,
      sanitizeExtractionResponse(raw, {
        uid: user.uid,
        source,
        objectKey: uploadedAssetR2Key,
        uploadedAssetId,
      }),
    );
  }

  const imageBytes = await object.arrayBuffer();
  if (imageBytes.byteLength > maxBytes) {
    throw new HttpError(413, "image_too_large", "This photo is too large. Please upload a photo under 15 MB.");
  }
  if (
    aiProviderName(env) === "gemini" &&
    imageBytes.byteLength > geminiInlineMaxImageBytes(env, maxBytes)
  ) {
    const raw = inlineImageTooLargeFallback(
      {
        uid: user.uid,
        reviewId,
        source,
        sourceLabel,
        imageBytes,
        contentType: normalizedSourceContentType,
        objectKey: uploadedAssetR2Key,
        uploadedAssetId,
      },
      "gemini",
      env.AI_MODEL?.trim() || DEFAULT_GEMINI_MODEL,
    );
    return jsonResponse(
      request,
      env,
      sanitizeExtractionResponse(raw, {
        uid: user.uid,
        source,
        objectKey: uploadedAssetR2Key,
        uploadedAssetId,
      }),
    );
  }

  const extractor = extractorFor(env);
  const raw = await extractor.extract({
    uid: user.uid,
    reviewId,
    source,
    sourceLabel,
    imageBytes,
    contentType: normalizedSourceContentType,
    objectKey: uploadedAssetR2Key,
    uploadedAssetId,
  });
  const sanitized = sanitizeExtractionResponse(raw, {
    uid: user.uid,
    source,
    objectKey: uploadedAssetR2Key,
    uploadedAssetId,
  });

  return jsonResponse(request, env, sanitized);
}

class DisabledAiRoutineExtractor implements AiRoutineExtractor {
  async extract(args: ExtractArgs): Promise<RoutineImportExtractionResponse> {
    return fallbackResponse({
      args,
      engine: "disabled",
      engineVersion: "phase2d-disabled",
      warning: "AI provider is disabled.",
      candidates: [
        manualReviewCandidate(
          args,
          "ai_disabled_manual_review",
          `${args.sourceLabel} photo needs manual review`,
          "disabled",
          "phase2d-disabled",
        ),
      ],
    });
  }
}

class FakeAiRoutineExtractor implements AiRoutineExtractor {
  async extract(args: ExtractArgs): Promise<RoutineImportExtractionResponse> {
    const base = baseResponse(args, "fake", "phase2d-fake");
    return {
      ...base,
      rawText: `Fake AI extraction for ${args.sourceLabel}.`,
      warnings: ["Fake AI extraction result. Review manually before saving."],
      candidates: fakeCandidates(args),
    };
  }
}

class VisionAiRoutineExtractor implements AiRoutineExtractor {
  private readonly apiKey: string;
  private readonly model: string;
  private readonly fallbackModel?: string;

  constructor(apiKey: string, model: string, fallbackModel?: string) {
    this.apiKey = apiKey;
    this.model = model;
    this.fallbackModel = fallbackModel;
  }

  async extract(args: ExtractArgs): Promise<RoutineImportExtractionResponse> {
    const primary = await this.extractWithModel(args, this.model);
    return maybeRunFallbackModel({
      args,
      primary,
      primaryModel: this.model,
      fallbackModel: this.fallbackModel,
      runFallback: (model) => this.extractWithModel(args, model),
    });
  }

  private async extractWithModel(
    args: ExtractArgs,
    model: string,
  ): Promise<RoutineImportExtractionResponse> {
    const prompt = buildRoutineImportPrompt(args.source, "openai");
    const imageDataUrl = `data:${args.contentType};base64,${arrayBufferToBase64(args.imageBytes)}`;
    try {
      const response = await fetch("https://api.openai.com/v1/responses", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${this.apiKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          model,
          input: [
            {
              role: "user",
              content: [
                { type: "input_text", text: prompt },
                { type: "input_image", image_url: imageDataUrl },
              ],
            },
          ],
        }),
      });

      if (!response.ok) {
        return providerFallback(args, "openai", model, "AI provider could not process the image.");
      }

      let providerBody: unknown;
      try {
        providerBody = await response.json();
      } catch {
        return providerFallback(args, "openai", model, "AI provider returned invalid JSON.");
      }

      const text = readProviderText(providerBody);
      let parsed = parseAiJsonText(text);
      if (!parsed) {
        parsed = await this.repairAiJsonText(text, args, model);
      }
      if (!parsed) {
        return unsafeAiOutputFallback(args, "openai", model);
      }

      const validation = validateExtractionShape(parsed);
      if (!validation.ok) {
        return unsafeAiOutputFallback(args, "openai", model);
      }

      return coerceExtractionResponse(parsed, args, "openai", model);
    } catch {
      return providerFallback(args, "openai", model, "AI provider is unavailable. Try again later.");
    }
  }

  private async repairAiJsonText(
    text: string,
    args: ExtractArgs,
    model: string,
  ): Promise<unknown | null> {
    if (!text.trim()) return null;
    try {
      const response = await fetch("https://api.openai.com/v1/responses", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${this.apiKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          model,
          input: [
            {
              role: "user",
              content: [
                {
                  type: "input_text",
                  text: buildJsonRepairPrompt(args.source, text),
                },
              ],
            },
          ],
        }),
      });
      if (!response.ok) return null;
      const providerBody = await response.json();
      return parseAiJsonText(readProviderText(providerBody));
    } catch {
      return null;
    }
  }
}

class GeminiAiRoutineExtractor implements AiRoutineExtractor {
  private readonly apiKey: string;
  private readonly model: string;
  private readonly inlineMaxBytes: number;
  private readonly fallbackModel?: string;

  constructor(
    apiKey: string,
    model: string,
    inlineMaxBytes: number,
    fallbackModel?: string,
  ) {
    this.apiKey = apiKey;
    this.model = model;
    this.inlineMaxBytes = inlineMaxBytes;
    this.fallbackModel = fallbackModel;
  }

  async extract(args: ExtractArgs): Promise<RoutineImportExtractionResponse> {
    const primary = await this.extractWithModel(args, this.model);
    return maybeRunFallbackModel({
      args,
      primary,
      primaryModel: this.model,
      fallbackModel: this.fallbackModel,
      runFallback: (model) => this.extractWithModel(args, model),
    });
  }

  private async extractWithModel(
    args: ExtractArgs,
    configuredModel: string,
  ): Promise<RoutineImportExtractionResponse> {
    if (args.imageBytes.byteLength > this.inlineMaxBytes) {
      return inlineImageTooLargeFallback(args, "gemini", configuredModel);
    }

    const prompt = buildRoutineImportPrompt(args.source, "gemini");
    const model = configuredModel.replace(/^models\//, "");
    try {
      const response = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent`,
        {
          method: "POST",
          headers: {
            "x-goog-api-key": this.apiKey,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            contents: [
              {
                parts: [
                  {
                    inlineData: {
                      mimeType: args.contentType,
                      data: arrayBufferToBase64(args.imageBytes),
                    },
                  },
                  { text: prompt },
                ],
              },
            ],
            generationConfig: {
              responseMimeType: "application/json",
              temperature: 0,
            },
          }),
        },
      );

      if (!response.ok) {
        return providerFallback(args, "gemini", configuredModel, "AI provider could not process the image.");
      }

      let providerBody: unknown;
      try {
        providerBody = await response.json();
      } catch {
        return providerFallback(args, "gemini", configuredModel, "AI provider returned invalid JSON.");
      }

      const parsed = parseAiJsonText(readProviderText(providerBody));
      if (!parsed) {
        return unsafeAiOutputFallback(args, "gemini", configuredModel);
      }

      const validation = validateExtractionShape(parsed);
      if (!validation.ok) {
        return unsafeAiOutputFallback(args, "gemini", configuredModel);
      }

      return coerceExtractionResponse(parsed, args, "gemini", configuredModel);
    } catch {
      return providerFallback(args, "gemini", configuredModel, "AI provider is unavailable. Try again later.");
    }
  }
}

function extractorFor(env: Env): AiRoutineExtractor {
  const provider = aiProviderName(env);
  if (provider === "fake") return new FakeAiRoutineExtractor();
  const fallbackModel = aiFallbackModel(env);
  if (provider === "gemini" && env.GEMINI_API_KEY?.trim()) {
    return new GeminiAiRoutineExtractor(
      env.GEMINI_API_KEY.trim(),
      env.AI_MODEL?.trim() || DEFAULT_GEMINI_MODEL,
      geminiInlineMaxImageBytes(env, sourceImageMaxBytes(env)),
      fallbackModel,
    );
  }
  if (
    (provider === "openai" || provider === "vision" || provider === "aiVision") &&
    env.OPENAI_API_KEY?.trim() &&
    env.AI_MODEL?.trim()
  ) {
    return new VisionAiRoutineExtractor(
      env.OPENAI_API_KEY.trim(),
      env.AI_MODEL.trim(),
      fallbackModel,
    );
  }
  return new DisabledAiRoutineExtractor();
}

function aiProviderName(env: Env): string {
  return (env.AI_PROVIDER ?? "disabled").trim() || "disabled";
}

function aiFallbackModel(env: Env): string | undefined {
  const value = env.AI_FALLBACK_MODEL?.trim();
  return value && value !== env.AI_MODEL?.trim() ? value : undefined;
}

function buildRoutineImportPrompt(
  source: RoutineImportReviewSource,
  engine: ExtractionEngine = "aiVision",
): string {
  const sourceRules = {
    classes:
      "Extract subjects/classes/labs/tutorials. Use hard blocks by default. Preserve room/location if visible. If only period numbers exist and exact times are missing, create flexible/unplaced low-confidence candidates.",
    work:
      "Extract only clearly timed work/business responsibility blocks from the image: Office Work, Work, Shift, Client Calls, Meeting, meetings, Project Work, Team Sync, Training Session, Commute, Lunch Break / Break, Freelance Project, freelance/side-work, Business Hours. Preserve the visible title and time. Use hard_block for fixed timed blocks. Use category job. Do not ignore blocks just because they are not named exactly Work. Do not import personal habit blocks like Gym/Exercise, Study/Reading, Online Course, Reading, Rest Day/No Work, or personal habits as job candidates. For weekly grid images, days are columns and times are rows. Convert each visible timed cell into one candidate with repeatDays matching the day column. Treat all clearly timed work schedule items as fixed work/business blocks unless source text clearly says rest day/no work. Use flexible tasks only for to-dos without a visible time.",
    eating:
      "Extract meal windows as blocks. Preserve breakfast/lunch/dinner/snack mealCategory. Dishes should usually go into notes or steps, not separate timeline blocks.",
    skinCare:
      "Extract morning/night routine windows as blocks if visible. Product sequences should become steps/checklist. If no time is visible, create unplaced checklist/flexible candidates.",
  } satisfies Record<RoutineImportReviewSource, string>;

  return [
    "You extract routine candidates from a user-uploaded image for Optivus.",
    "Return only strict JSON. No markdown. No prose outside JSON. Do not use TOON. Do not create RoutineItem objects.",
    "",
    "Accuracy principle: never invent exact time/day if unclear. Use hasFixedTime=false and needsManualReview=true when unsure.",
    "The goal is a user-approved review draft, not direct Routine writes and not 100% raw AI accuracy.",
    "",
    "Stage 1 read:",
    "- Read small text carefully.",
    "- Preserve table rows and columns.",
    "- Preserve row labels, column labels, day labels, and time labels exactly.",
    "- Do not guess missing values.",
    "- Do not invent unclear values.",
    "",
    "Stage 2 normalize:",
    "- Convert days to Monday=1, Tuesday=2, Wednesday=3, Thursday=4, Friday=5, Saturday=6, Sunday=7.",
    "- Convert clear times to minutes from midnight.",
    "- Use hasFixedTime=false if no clear time.",
    "- If uncertain, set needsManualReview=true.",
    "- If text is unclear, use low confidence.",
    "- Add confidenceScore 0..1 and confidenceLabel high/medium/low.",
    "",
    "Stage 3 validate:",
    "- Add validationIssues for missing title/day, unclear time, duplicate row, impossible time, low confidence, ambiguous abbreviation, or language uncertainty.",
    "- For blurry/unclear content, confidenceLabel must be low.",
    "- Add warnings for blurry image, dark image, rotated image, text too small, partial/cropped sheet, wrong source type, multiple sheets mixed, handwriting unreadable, or image too large for inline AI processing.",
    `- If the photo is too hard to read, return an empty candidates array and include this warning: ${HARD_TO_READ_WARNING}`,
    "- Keep sourceTextSnippet for every candidate.",
    "- Keep sourceRowLabel/sourceColumnLabel for table-like content.",
    "",
    `Source-specific rules: ${sourceRules[source]}`,
    "",
    "Required JSON shape:",
    JSON.stringify({
      id: "string",
      uid: "string",
      source,
      engine,
      engineVersion: "string",
      sourceAssetId: "string",
      sourceR2Key: "string",
      rawText: "string",
      candidates: [
        {
          id: "string",
          title: "string",
          candidateType: "block|flexibleTask|checklistStep|note|unknown",
          startMinute: 0,
          endMinute: 0,
          hasFixedTime: false,
          suggestedStartMinute: 0,
          suggestedEndMinute: 0,
          repeatDays: [1],
          blockType: "hard_block|soft_block|flexible_task",
          category: "classBlock|job|eating|skinCare|fixed|habit|health",
          hardBlock: false,
          selected: true,
          needsManualReview: true,
          confidenceScore: 0.4,
          confidenceLabel: "low",
          validationIssues: ["unclear time"],
          sourceTextSnippet: "visible source text",
          sourceRowLabel: "row label",
          sourceColumnLabel: "column label",
          sourceBoundingBox: {},
          extractionEngine: engine,
          extractionVersion: "phase2d",
          location: "room/location if visible",
          notes: "safe note",
          mealCategory: "Breakfast/Lunch/Dinner/Snack",
          steps: ["step"],
        },
      ],
      warnings: ["warning"],
      createdAt: new Date().toISOString(),
    }),
  ].join("\n");
}

function buildJsonRepairPrompt(
  source: RoutineImportReviewSource,
  unsafeText: string,
): string {
  return [
    "Repair the following routine import extraction output into strict JSON only.",
    "Return no markdown and no prose outside JSON.",
    "Do not add facts, times, days, candidates, source images, local paths, image bytes, Routine items, or applied IDs.",
    "If a value is unclear, keep it unclear and use needsManualReview=true with low confidence.",
    `The source must be one of classes, work, eating, skinCare. Current source: ${source}.`,
    "Required root keys: id, uid, source, engine, engineVersion, sourceAssetId, sourceR2Key, rawText, candidates, warnings, createdAt.",
    "Required candidate keys: id, title, candidateType, startMinute, endMinute, hasFixedTime, repeatDays, blockType, category, hardBlock, selected, needsManualReview, validationIssues, extractionEngine, steps.",
    "",
    "Unsafe output to repair:",
    unsafeText.slice(0, 12000),
  ].join("\n");
}

function fakeCandidates(args: ExtractArgs): RoutineImportCandidate[] {
  const common = (
    id: string,
    title: string,
    startMinute: number,
    endMinute: number,
    repeatDays: number[],
    blockType: string,
    category: string,
    hardBlock: boolean,
    snippet: string,
  ): RoutineImportCandidate => ({
    id,
    title,
    candidateType: "block",
    startMinute,
    endMinute,
    hasFixedTime: true,
    repeatDays,
    blockType,
    category,
    hardBlock,
    selected: true,
    needsManualReview: true,
    confidenceScore: 0.78,
    confidenceLabel: "medium",
    validationIssues: [],
    sourceAssetId: args.uploadedAssetId,
    sourceR2Key: args.objectKey,
    sourceTextSnippet: snippet,
    sourceImageIndex: 0,
    sourceRowLabel: repeatDays.length === 1 ? dayLabel(repeatDays[0]) : "Weekdays",
    sourceColumnLabel: "Time",
    extractionEngine: "fake",
    extractionVersion: "phase2d",
    notes: "Fake extraction candidate. Confirm details before saving.",
    steps: [],
  });

  switch (args.source) {
    case "classes":
      return [
        common("ai_class_math", "Math class", 540, 600, [1, 3, 5], "hard_block", "classBlock", true, "MON/WED/FRI 9:00 Math"),
        unclearCandidate({
          args,
          id: "ai_class_unclear_period",
          title: "Unclear class period",
          category: "classBlock",
          snippet: "Period 4 - Physics",
        }),
      ];
    case "work":
      return [
        common("ai_work_shift", "Work shift", 540, 1020, [1, 2, 3, 4, 5], "hard_block", "job", true, "Mon-Fri 9 AM - 5 PM shift"),
      ];
    case "eating":
      return [
        {
          ...common("ai_lunch_window", "Lunch", 780, 810, [1, 2, 3, 4, 5, 6, 7], "soft_block", "eating", false, "Lunch 1:00 PM"),
          mealCategory: "Lunch",
          steps: ["Rice", "Dal"],
        },
      ];
    case "skinCare":
      return [
        {
          ...unclearCandidate({
            args,
            id: "ai_skin_care_steps",
            title: "Morning skin care routine",
            category: "skinCare",
            snippet: "Cleanser > Serum > Sunscreen",
          }),
          candidateType: "checklistStep",
          steps: ["Cleanser", "Serum", "Sunscreen"],
        },
      ];
  }
}

function manualReviewCandidate(
  args: ExtractArgs,
  id: string,
  title: string,
  engine: ExtractionEngine,
  engineVersion: string,
): RoutineImportCandidate {
  return unclearCandidate({
    args,
    id,
    title,
    category: sourceCategory[args.source],
    snippet: "AI provider is disabled.",
    engine,
    engineVersion,
  });
}

function unclearCandidate({
  args,
  id,
  title,
  category,
  snippet,
  engine = "fake",
  engineVersion = "phase2d",
}: {
  args: ExtractArgs;
  id: string;
  title: string;
  category: string;
  snippet: string;
  engine?: ExtractionEngine;
  engineVersion?: string;
}): RoutineImportCandidate {
  return {
    id,
    title,
    candidateType: "flexibleTask",
    startMinute: 540,
    endMinute: 600,
    hasFixedTime: false,
    suggestedStartMinute: 540,
    suggestedEndMinute: 600,
    repeatDays: [],
    blockType: "flexible_task",
    category,
    hardBlock: false,
    selected: false,
    needsManualReview: true,
    confidenceScore: 0.25,
    confidenceLabel: "low",
    validationIssues: ["Unclear time in source image."],
    sourceAssetId: args.uploadedAssetId,
    sourceR2Key: args.objectKey,
    sourceTextSnippet: snippet,
    sourceImageIndex: 0,
    extractionEngine: engine,
    extractionVersion: engineVersion,
    notes: "Assign a time if this should become routine.",
    steps: [],
  };
}

function sanitizeExtractionResponse(
  response: RoutineImportExtractionResponse,
  args: {
    uid: string;
    source: RoutineImportReviewSource;
    objectKey: string;
    uploadedAssetId?: string;
  },
): RoutineImportExtractionResponse {
  const engine = safeEngine(response.engine);
  return {
    id: safeText(response.id, `extract-${crypto.randomUUID()}`, 128),
    uid: args.uid,
    source: args.source,
    engine,
    engineVersion: safeText(response.engineVersion, "phase2d", 64),
    sourceAssetId: args.uploadedAssetId,
    sourceR2Key: args.objectKey,
    rawText: optionalText(response.rawText, 6000),
    candidates: response.candidates.map((candidate, index) =>
      sanitizeCandidate(candidate, {
        index,
        engine,
        engineVersion: safeText(response.engineVersion, "phase2d", 64),
        source: args.source,
        objectKey: args.objectKey,
        uploadedAssetId: args.uploadedAssetId,
      }),
    ),
    warnings: stringList(response.warnings, 12, 180),
    createdAt: validIsoDate(response.createdAt) ? response.createdAt : new Date().toISOString(),
  };
}

function sanitizeCandidate(
  candidate: RoutineImportCandidate,
  args: {
    index: number;
    engine: ExtractionEngine;
    engineVersion: string;
    source: RoutineImportReviewSource;
    objectKey: string;
    uploadedAssetId?: string;
  },
): RoutineImportCandidate {
  const validationIssues = stringList(candidate.validationIssues, 8, 140);
  let startMinute = clampInt(candidate.startMinute, 0, 1440);
  let endMinute = clampInt(candidate.endMinute, 0, 1440);
  let hasFixedTime = candidate.hasFixedTime === true;
  if (endMinute <= startMinute) {
    hasFixedTime = false;
    if (!validationIssues.includes("Time is unclear or invalid.")) {
      validationIssues.push("Time is unclear or invalid.");
    }
  }
  if (!hasFixedTime) {
    startMinute = clampInt(candidate.suggestedStartMinute ?? startMinute, 0, 1430);
    endMinute = clampInt(candidate.suggestedEndMinute ?? Math.max(startMinute + 10, endMinute), 1, 1440);
    if (endMinute <= startMinute) endMinute = Math.min(startMinute + 10, 1440);
  }

  const candidateType = safeCandidateType(candidate.candidateType);
  const confidenceScore = clampNumber(candidate.confidenceScore ?? 0.35, 0, 1);
  const confidenceLabel = validationIssues.length > 0
    ? "low"
    : safeConfidenceLabel(candidate.confidenceLabel, confidenceScore);

  return {
    id: safeId(candidate.id, `candidate_${args.index + 1}`),
    title: safeText(candidate.title, `${labelForSource(args.source)} candidate`, 120),
    candidateType,
    startMinute,
    endMinute,
    hasFixedTime,
    suggestedStartMinute: optionalMinute(candidate.suggestedStartMinute),
    suggestedEndMinute: optionalMinute(candidate.suggestedEndMinute),
    repeatDays: safeRepeatDays(candidate.repeatDays),
    blockType: safeBlockType(candidate.blockType, args.source, hasFixedTime),
    category: safeCategory(candidate.category, args.source),
    hardBlock: candidate.hardBlock === true && hasFixedTime,
    selected: hasFixedTime ? candidate.selected !== false : false,
    needsManualReview:
      candidate.needsManualReview === true ||
      confidenceLabel === "low" ||
      validationIssues.length > 0 ||
      candidateType === "unknown",
    confidenceScore,
    confidenceLabel,
    validationIssues,
    sourceAssetId: args.uploadedAssetId,
    sourceR2Key: args.objectKey,
    sourceTextSnippet: optionalText(candidate.sourceTextSnippet, 500),
    sourcePageIndex: optionalNonNegativeInt(candidate.sourcePageIndex),
    sourceImageIndex: optionalNonNegativeInt(candidate.sourceImageIndex),
    sourceRowLabel: optionalText(candidate.sourceRowLabel, 80),
    sourceColumnLabel: optionalText(candidate.sourceColumnLabel, 80),
    sourceBoundingBox: plainRecord(candidate.sourceBoundingBox),
    extractionEngine: args.engine,
    extractionVersion: args.engineVersion,
    location: optionalText(candidate.location, 120),
    notes: optionalText(candidate.notes, 800),
    mealCategory: optionalText(candidate.mealCategory, 80),
    steps: stringList(candidate.steps, 16, 120),
  };
}

function coerceExtractionResponse(
  value: unknown,
  args: ExtractArgs,
  engine: ExtractionEngine,
  engineVersion: string,
): RoutineImportExtractionResponse {
  const body = record(value);
  const candidates = Array.isArray(body.candidates)
    ? body.candidates.map((item) => coerceCandidate(item))
    : [];
  return {
    id: textValue(body.id) ?? `ai-${args.reviewId}`,
    uid: args.uid,
    source: args.source,
    engine,
    engineVersion,
    sourceAssetId: args.uploadedAssetId,
    sourceR2Key: args.objectKey,
    rawText: textValue(body.rawText),
    candidates,
    warnings: Array.isArray(body.warnings) ? body.warnings.filter(isString) : [],
    createdAt: textValue(body.createdAt) ?? new Date().toISOString(),
  };
}

function coerceCandidate(value: unknown): RoutineImportCandidate {
  const body = record(value);
  return {
    id: textValue(body.id) ?? crypto.randomUUID(),
    title: textValue(body.title) ?? "",
    candidateType: safeCandidateType(textValue(body.candidateType)),
    startMinute: numberValue(body.startMinute) ?? 0,
    endMinute: numberValue(body.endMinute) ?? 0,
    hasFixedTime: body.hasFixedTime === true,
    suggestedStartMinute: numberValue(body.suggestedStartMinute),
    suggestedEndMinute: numberValue(body.suggestedEndMinute),
    repeatDays: Array.isArray(body.repeatDays) ? body.repeatDays.filter(isNumber) : [],
    blockType: textValue(body.blockType) ?? "soft_block",
    category: textValue(body.category) ?? "fixed",
    hardBlock: body.hardBlock === true,
    selected: body.selected !== false,
    needsManualReview: body.needsManualReview === true,
    confidenceScore: numberValue(body.confidenceScore),
    confidenceLabel: safeConfidenceLabel(textValue(body.confidenceLabel), numberValue(body.confidenceScore) ?? 0),
    validationIssues: Array.isArray(body.validationIssues)
      ? body.validationIssues.filter(isString)
      : [],
    sourceTextSnippet: textValue(body.sourceTextSnippet),
    sourcePageIndex: numberValue(body.sourcePageIndex),
    sourceImageIndex: numberValue(body.sourceImageIndex),
    sourceRowLabel: textValue(body.sourceRowLabel),
    sourceColumnLabel: textValue(body.sourceColumnLabel),
    sourceBoundingBox: plainRecord(body.sourceBoundingBox),
    extractionEngine: textValue(body.extractionEngine) ?? "aiVision",
    extractionVersion: textValue(body.extractionVersion),
    location: textValue(body.location),
    notes: textValue(body.notes),
    mealCategory: textValue(body.mealCategory),
    steps: Array.isArray(body.steps) ? body.steps.filter(isString) : [],
  };
}

function baseResponse(
  args: ExtractArgs,
  engine: ExtractionEngine,
  engineVersion: string,
): RoutineImportExtractionResponse {
  return {
    id: `${engine}-${args.reviewId}`,
    uid: args.uid,
    source: args.source,
    engine,
    engineVersion,
    sourceAssetId: args.uploadedAssetId,
    sourceR2Key: args.objectKey,
    candidates: [],
    warnings: [],
    createdAt: new Date().toISOString(),
  };
}

function fallbackResponse(
  options: {
    args: ExtractArgs;
    engine: ExtractionEngine;
    engineVersion: string;
    warning: string;
    candidates?: RoutineImportCandidate[];
  },
): RoutineImportExtractionResponse {
  const { args, engine, engineVersion, warning, candidates = [] } = options;
  return {
    ...baseResponse(args, engine, engineVersion),
    candidates,
    warnings: [warning],
  };
}

function providerFallback(
  args: ExtractArgs,
  engine: ExtractionEngine,
  engineVersion: string,
  warning: string,
): RoutineImportExtractionResponse {
  return fallbackResponse({
    args,
    engine,
    engineVersion,
    warning,
  });
}

function inlineImageTooLargeFallback(
  args: ExtractArgs,
  engine: ExtractionEngine,
  engineVersion: string,
): RoutineImportExtractionResponse {
  return {
    ...baseResponse(args, engine, engineVersion),
    warnings: [
      INLINE_IMAGE_TOO_LARGE_WARNING,
      "image too large for inline AI processing",
    ],
  };
}

function unsafeAiOutputFallback(
  args: ExtractArgs,
  engine: ExtractionEngine,
  engineVersion: string,
): RoutineImportExtractionResponse {
  return providerFallback(
    args,
    engine,
    engineVersion,
    "AI output could not be safely parsed. Review manually.",
  );
}

async function maybeRunFallbackModel(options: {
  args: ExtractArgs;
  primary: RoutineImportExtractionResponse;
  primaryModel: string;
  fallbackModel?: string;
  runFallback: (model: string) => Promise<RoutineImportExtractionResponse>;
}): Promise<RoutineImportExtractionResponse> {
  const fallbackModel = options.fallbackModel?.trim();
  if (!fallbackModel || fallbackModel === options.primaryModel.trim()) {
    return options.primary;
  }
  if (!shouldRunFallback(options.primary, options.args)) {
    return options.primary;
  }

  try {
    const fallback = await options.runFallback(fallbackModel);
    if (fallbackModelFailed(fallback)) {
      return withMergedWarnings(options.primary, [
        "AI fallback model could not improve extraction.",
      ]);
    }
    return withMergedWarnings(fallback, [
      "AI fallback model used after low-confidence primary extraction.",
    ]);
  } catch {
    return withMergedWarnings(options.primary, [
      "AI fallback model could not improve extraction.",
    ]);
  }
}

function shouldRunFallback(
  result: RoutineImportExtractionResponse,
  args: ExtractArgs,
): boolean {
  if (result.engine === "disabled" || result.engine === "fake") return false;
  if (result.candidates.length === 0) return true;
  if (averageConfidence(result.candidates) < 0.72) return true;
  if (lowConfidenceRatio(result.candidates) > 0.5) return true;
  if (result.warnings.some(isSeriousImageWarning)) return true;
  if (result.warnings.some(isJsonParseFailureWarning)) return true;
  if (
    (args.source === "classes" || args.source === "work") &&
    !result.candidates.some(hasTimedBlock)
  ) {
    return true;
  }
  return false;
}

function averageConfidence(candidates: RoutineImportCandidate[]): number {
  if (candidates.length === 0) return 0;
  const total = candidates.reduce((sum, candidate) => {
    if (typeof candidate.confidenceScore === "number") {
      return sum + clampNumber(candidate.confidenceScore, 0, 1);
    }
    return sum + confidenceFromLabel(candidate.confidenceLabel);
  }, 0);
  return total / candidates.length;
}

function lowConfidenceRatio(candidates: RoutineImportCandidate[]): number {
  if (candidates.length === 0) return 1;
  const lowCount = candidates.filter((candidate) => {
    if (candidate.confidenceLabel === "low") return true;
    if (typeof candidate.confidenceScore === "number") {
      return candidate.confidenceScore < 0.52;
    }
    return false;
  }).length;
  return lowCount / candidates.length;
}

function confidenceFromLabel(label: ConfidenceLabel | undefined): number {
  if (label === "high") return 0.9;
  if (label === "medium") return 0.65;
  return 0.35;
}

function hasTimedBlock(candidate: RoutineImportCandidate): boolean {
  return candidate.hasFixedTime === true &&
    candidate.candidateType === "block" &&
    candidate.startMinute >= 0 &&
    candidate.endMinute > candidate.startMinute &&
    candidate.endMinute <= 24 * 60;
}

function isSeriousImageWarning(warning: string): boolean {
  const text = warning.toLowerCase();
  return text.includes("hard to read") ||
    text.includes("blurry") ||
    text.includes("dark image") ||
    text.includes("rotated") ||
    text.includes("too small") ||
    text.includes("cropped") ||
    text.includes("partial") ||
    text.includes("unreadable") ||
    text.includes("wrong source") ||
    text.includes("multiple sheets") ||
    text.includes("image too large");
}

function isJsonParseFailureWarning(warning: string): boolean {
  const text = warning.toLowerCase();
  return text.includes("could not be safely parsed") ||
    text.includes("invalid json");
}

function fallbackModelFailed(result: RoutineImportExtractionResponse): boolean {
  if (result.candidates.length > 0) return false;
  return result.warnings.some((warning) => {
    const text = warning.toLowerCase();
    return text.includes("unavailable") ||
      text.includes("could not process") ||
      text.includes("returned invalid json") ||
      text.includes("could not be safely parsed");
  });
}

function withMergedWarnings(
  result: RoutineImportExtractionResponse,
  warnings: string[],
): RoutineImportExtractionResponse {
  return {
    ...result,
    warnings: [...new Set([...result.warnings, ...warnings])],
  };
}

async function requireVerifiedFirebaseUser(request: Request, env: Env): Promise<VerifiedUser> {
  const authorization = request.headers.get("Authorization") ?? "";
  const token = authorization.match(/^Bearer\s+(.+)$/i)?.[1];
  if (!token) {
    throw new HttpError(401, "missing_auth", "Missing Firebase ID token.");
  }

  const projectId = requiredEnv(env.FIREBASE_PROJECT_ID, "FIREBASE_PROJECT_ID");
  const result = await jwtVerify(token, firebaseJwks, {
    audience: projectId,
    issuer: `https://securetoken.google.com/${projectId}`,
  });
  const uid = result.payload.sub;
  if (!uid) {
    throw new HttpError(401, "invalid_auth", "Firebase ID token has no uid.");
  }
  if (result.payload.email_verified !== true) {
    throw new HttpError(403, "email_unverified", "Email verification is required.");
  }
  return { uid };
}

function assertOwnedRoutineImportObjectKey(args: {
  uid: string;
  source: RoutineImportReviewSource;
  objectKey: string;
  uploadedAssetId?: string;
}): void {
  const safeUid = safeSegment(args.uid, "uid");
  if (
    args.objectKey.includes("..") ||
    args.objectKey.includes("\\") ||
    args.objectKey.includes("//")
  ) {
    throw new HttpError(400, "invalid_object_key", "Object key is not allowed.");
  }

  const parts = args.objectKey.split("/");
  const allowedPurposes = classWorkScheduleSwapPurposes(args.source);
  if (
    parts.length !== 5 ||
    parts[0] !== "users" ||
    parts[1] !== safeUid ||
    parts[2] !== "onboarding" ||
    !allowedPurposes.has(parts[3])
  ) {
    throw new HttpError(400, "invalid_object_key", "Object key is not allowed.");
  }

  const fileName = parts[4];
  const lastDot = fileName.lastIndexOf(".");
  if (lastDot <= 0 || lastDot === fileName.length - 1) {
    throw new HttpError(400, "invalid_object_key", "Object key is not allowed.");
  }
  const assetId = fileName.slice(0, lastDot);
  const extension = fileName.slice(lastDot + 1).toLowerCase();
  if (!isSafeSegment(assetId)) {
    throw new HttpError(400, "invalid_object_key", "Object key is not allowed.");
  }
  if (
    extension !== "jpg" &&
    extension !== "jpeg" &&
    extension !== "png" &&
    extension !== "webp"
  ) {
    throw new HttpError(400, "invalid_object_key", "Object key is not allowed.");
  }
  if (args.uploadedAssetId && args.uploadedAssetId !== assetId) {
    throw new HttpError(400, "asset_mismatch", "Object key does not match uploaded asset.");
  }
}

function classWorkScheduleSwapPurposes(source: RoutineImportReviewSource): Set<string> {
  const purpose = sourcePurpose[source];
  if (source === "classes" || source === "work") {
    // Student + Working can swap mislabeled class/work thumbnails after upload.
    return new Set([sourcePurpose.classes, sourcePurpose.work]);
  }
  return new Set([purpose]);
}

async function readSmallJson(request: Request): Promise<Record<string, unknown>> {
  const contentLength = Number(request.headers.get("Content-Length") ?? "0");
  if (Number.isFinite(contentLength) && contentLength > 8192) {
    throw new HttpError(413, "body_too_large", "Request body is too large.");
  }
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    throw new HttpError(400, "invalid_json", "Expected a JSON object.");
  }
  if (body === null || typeof body !== "object" || Array.isArray(body)) {
    throw new HttpError(400, "invalid_json", "Expected a JSON object.");
  }
  return body as Record<string, unknown>;
}

function readString(body: Record<string, unknown>, key: string): string {
  const value = body[key];
  if (typeof value !== "string" || value.trim() === "") {
    throw new HttpError(400, "missing_field", `Missing ${key}.`);
  }
  return value.trim();
}

function readOptionalString(body: Record<string, unknown>, key: string): string | undefined {
  const value = body[key];
  return typeof value === "string" && value.trim() !== "" ? value.trim() : undefined;
}

function readSource(body: Record<string, unknown>, key: string): RoutineImportReviewSource {
  const value = readString(body, key);
  if (value === "classes" || value === "work" || value === "eating" || value === "skinCare") {
    return value;
  }
  throw new HttpError(400, "invalid_source", "Routine import source is not allowed.");
}

function safeSegment(value: string, label: string): string {
  const trimmed = value.trim();
  if (!isSafeSegment(trimmed)) {
    throw new HttpError(400, "unsafe_segment", `${label} is not safe for an object key.`);
  }
  return trimmed;
}

function isSafeSegment(value: string): boolean {
  return (
    /^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$/.test(value) &&
    !value.includes("..") &&
    !value.includes("/") &&
    !value.includes("\\")
  );
}

function requiredEnv(value: string | undefined, key: string): string {
  if (!value || value.trim() === "") {
    throw new HttpError(500, "missing_env", `${key} is not configured.`);
  }
  return value.trim();
}

function requiredUploadBucket(env: Env): R2Bucket {
  if (!env.UPLOAD_BUCKET) {
    throw new HttpError(500, "missing_env", "UPLOAD_BUCKET is not configured.");
  }
  return env.UPLOAD_BUCKET;
}

function numberEnv(value: string | undefined, fallback: number): number {
  const parsed = Number(value);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

function sourceImageMaxBytes(env: Env): number {
  return numberEnv(env.MAX_IMAGE_BYTES, SOURCE_IMAGE_MAX_BYTES);
}

function geminiInlineMaxImageBytes(env: Env, sourceMaxBytes: number): number {
  const configured = numberEnv(
    env.GEMINI_INLINE_MAX_IMAGE_BYTES,
    GEMINI_INLINE_MAX_IMAGE_BYTES,
  );
  return Math.min(configured, Math.max(1, sourceMaxBytes - 1));
}

function jsonResponse(
  request: Request,
  env: Env,
  body: unknown,
  status = 200,
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      ...corsHeaders(request, env),
    },
  });
}

function corsHeaders(request: Request, env: Env): HeadersInit {
  const origin = request.headers.get("Origin");
  const allowedOrigins = (env.ALLOWED_ORIGINS ?? "")
    .split(",")
    .map((item) => item.trim())
    .filter((item) => item !== "");
  const allowOrigin =
    origin && allowedOrigins.includes(origin)
      ? origin
      : allowedOrigins.length === 0
        ? "*"
        : allowedOrigins[0];
  return {
    "Access-Control-Allow-Origin": allowOrigin,
    "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
    "Access-Control-Allow-Headers": "Authorization,Content-Type",
  };
}

function arrayBufferToBase64(buffer: ArrayBuffer): string {
  const bytes = new Uint8Array(buffer);
  let binary = "";
  const chunkSize = 0x8000;
  for (let i = 0; i < bytes.length; i += chunkSize) {
    const chunk = bytes.subarray(i, i + chunkSize);
    binary += String.fromCharCode(...chunk);
  }
  return btoa(binary);
}

function readProviderText(value: unknown): string {
  const body = record(value);
  const outputText = textValue(body.output_text);
  if (outputText) return outputText;

  const geminiCandidates = Array.isArray(body.candidates) ? body.candidates : [];
  for (const candidate of geminiCandidates) {
    const candidateRecord = record(candidate);
    const contentRecord = record(candidateRecord.content);
    const parts = Array.isArray(contentRecord.parts) ? contentRecord.parts : [];
    for (const part of parts) {
      const text = textValue(record(part).text);
      if (text) return text;
    }
  }

  const output = Array.isArray(body.output) ? body.output : [];
  for (const item of output) {
    const itemRecord = record(item);
    const content = Array.isArray(itemRecord.content) ? itemRecord.content : [];
    for (const contentItem of content) {
      const contentRecord = record(contentItem);
      const text = textValue(contentRecord.text);
      if (text) return text;
    }
  }
  return "";
}

function parseAiJsonText(text: string): unknown | null {
  const trimmed = text.trim();
  if (!trimmed) return null;
  const withoutFence = trimmed
    .replace(/^```(?:json)?\s*/i, "")
    .replace(/\s*```$/i, "")
    .trim();
  try {
    return JSON.parse(withoutFence);
  } catch {
    return null;
  }
}

function validateExtractionShape(value: unknown): {
  ok: boolean;
  issues: string[];
} {
  const issues: string[] = [];
  collectForbiddenFieldIssues(value, "$", issues);

  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    issues.push("Root must be an object.");
    return { ok: false, issues };
  }

  const body = value as Record<string, unknown>;
  if (!isRoutineImportSource(body.source)) {
    issues.push("source is invalid.");
  }
  if (!Array.isArray(body.candidates)) {
    issues.push("candidates must be an array.");
  } else {
    body.candidates.forEach((candidate, index) => {
      if (candidate === null || typeof candidate !== "object" || Array.isArray(candidate)) {
        issues.push(`candidates[${index}] must be an object.`);
        return;
      }
      const candidateBody = candidate as Record<string, unknown>;
      if (typeof candidateBody.id !== "string" || candidateBody.id.trim() === "") {
        issues.push(`candidates[${index}].id is missing.`);
      }
      if (typeof candidateBody.title !== "string" || candidateBody.title.trim() === "") {
        issues.push(`candidates[${index}].title is missing.`);
      }
      if (!isCandidateType(candidateBody.candidateType)) {
        issues.push(`candidates[${index}].candidateType is invalid.`);
      }
      if (
        candidateBody.repeatDays !== undefined &&
        !Array.isArray(candidateBody.repeatDays)
      ) {
        issues.push(`candidates[${index}].repeatDays must be an array.`);
      }
      if (candidateBody.hasFixedTime === true) {
        if (!isNumber(candidateBody.startMinute)) {
          issues.push(`candidates[${index}].startMinute must be a number.`);
        }
        if (!isNumber(candidateBody.endMinute)) {
          issues.push(`candidates[${index}].endMinute must be a number.`);
        }
      }
    });
  }

  return { ok: issues.length === 0, issues };
}

function collectForbiddenFieldIssues(
  value: unknown,
  path: string,
  issues: string[],
): void {
  if (value === null || typeof value !== "object") return;
  if (Array.isArray(value)) {
    value.forEach((item, index) => collectForbiddenFieldIssues(item, `${path}[${index}]`, issues));
    return;
  }
  for (const [key, nested] of Object.entries(value as Record<string, unknown>)) {
    if (isForbiddenOutputField(key)) {
      issues.push(`${path}.${key} is not allowed.`);
    }
    collectForbiddenFieldIssues(nested, `${path}.${key}`, issues);
  }
}

function isForbiddenOutputField(key: string): boolean {
  return key === "routineItems" ||
    key === "appliedRoutineItemIds" ||
    key === "imageBytes" ||
    key === "localPath" ||
    key === "localFilePath" ||
    key === "localPreviewPath";
}

function isRoutineImportSource(value: unknown): value is RoutineImportReviewSource {
  return value === "classes" || value === "work" || value === "eating" || value === "skinCare";
}

function isCandidateType(value: unknown): value is RoutineImportCandidateType {
  return value === "block" ||
    value === "flexibleTask" ||
    value === "checklistStep" ||
    value === "note" ||
    value === "unknown";
}

function isAllowedSourceContentType(value: string): boolean {
  const contentType = normalizedContentType(value);
  return contentType === "image/jpeg" ||
    contentType === "image/png" ||
    contentType === "image/webp";
}

function normalizedContentType(value: string): string {
  const contentType = value.split(";")[0].trim().toLowerCase();
  return contentType === "image/jpg" ? "image/jpeg" : contentType;
}

function safeEngine(value: unknown): ExtractionEngine {
  return value === "gemini" ||
    value === "openai" ||
    value === "aiVision" ||
    value === "aiText" ||
    value === "fake" ||
    value === "disabled"
    ? value
    : "fake";
}

function safeCandidateType(value: unknown): RoutineImportCandidateType {
  return value === "block" ||
    value === "flexibleTask" ||
    value === "checklistStep" ||
    value === "note" ||
    value === "unknown"
    ? value
    : "unknown";
}

function safeConfidenceLabel(value: unknown, score: number): ConfidenceLabel {
  if (value === "high" || value === "medium" || value === "low") return value;
  if (score >= 0.82) return "high";
  if (score >= 0.52) return "medium";
  return "low";
}

function safeBlockType(value: unknown, source: RoutineImportReviewSource, hasFixedTime: boolean): string {
  if (value === "hard_block" || value === "soft_block" || value === "flexible_task") return value;
  if (!hasFixedTime) return "flexible_task";
  return source === "classes" || source === "work" ? "hard_block" : "soft_block";
}

function safeCategory(value: unknown, source: RoutineImportReviewSource): string {
  const allowed = new Set(["classBlock", "class_block", "classes", "job", "work", "eating", "skinCare", "skin_care", "fixed", "habit", "health"]);
  if (typeof value === "string" && allowed.has(value)) {
    if (value === "class_block" || value === "classes") return "classBlock";
    if (value === "work") return "job";
    if (value === "skin_care") return "skinCare";
    return value;
  }
  return sourceCategory[source];
}

function safeRepeatDays(value: number[]): number[] {
  return [
    ...new Set(
      value
        .filter((day) => Number.isFinite(day) && day >= 1 && day <= 7)
        .map((day) => Math.floor(day)),
    ),
  ].sort((a, b) => a - b);
}

function stringList(value: unknown, maxItems: number, maxLength: number): string[] {
  if (!Array.isArray(value)) return [];
  return value
    .filter(isString)
    .map((item) => safeText(item, "", maxLength))
    .filter((item) => item !== "")
    .slice(0, maxItems);
}

function safeId(value: unknown, fallback: string): string {
  const text = safeText(value, fallback, 96).replace(/[^A-Za-z0-9_-]+/g, "_");
  return text === "" ? fallback : text;
}

function safeText(value: unknown, fallback: string, maxLength: number): string {
  const text = typeof value === "string" ? value.trim() : fallback;
  return text.length > maxLength ? text.slice(0, maxLength) : text;
}

function optionalText(value: unknown, maxLength: number): string | undefined {
  if (typeof value !== "string" || value.trim() === "") return undefined;
  return safeText(value, "", maxLength);
}

function optionalMinute(value: unknown): number | undefined {
  return typeof value === "number" && Number.isFinite(value)
    ? clampInt(value, 0, 1440)
    : undefined;
}

function optionalNonNegativeInt(value: unknown): number | undefined {
  return typeof value === "number" && Number.isFinite(value) && value >= 0
    ? Math.floor(value)
    : undefined;
}

function clampInt(value: number, min: number, max: number): number {
  if (!Number.isFinite(value)) return min;
  return Math.max(min, Math.min(max, Math.round(value)));
}

function clampNumber(value: number, min: number, max: number): number {
  if (!Number.isFinite(value)) return min;
  return Math.max(min, Math.min(max, value));
}

function plainRecord(value: unknown): Record<string, unknown> | undefined {
  if (value === null || typeof value !== "object" || Array.isArray(value)) return undefined;
  return { ...(value as Record<string, unknown>) };
}

function record(value: unknown): Record<string, unknown> {
  return value !== null && typeof value === "object" && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : {};
}

function textValue(value: unknown): string | undefined {
  return typeof value === "string" ? value : undefined;
}

function numberValue(value: unknown): number | undefined {
  return typeof value === "number" && Number.isFinite(value) ? value : undefined;
}

function isString(value: unknown): value is string {
  return typeof value === "string";
}

function isNumber(value: unknown): value is number {
  return typeof value === "number" && Number.isFinite(value);
}

function validIsoDate(value: string): boolean {
  return !Number.isNaN(Date.parse(value));
}

function labelForSource(source: RoutineImportReviewSource): string {
  return {
    classes: "Classes",
    work: "Job / Work / Business",
    eating: "Eating",
    skinCare: "Skin Care",
  }[source];
}

function dayLabel(day: number): string {
  return ["", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"][day] ?? "Unknown day";
}

class HttpError extends Error {
  readonly status: number;
  readonly code: string;

  constructor(status: number, code: string, message: string) {
    super(message);
    this.status = status;
    this.code = code;
  }
}
