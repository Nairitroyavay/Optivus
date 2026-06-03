# Optivus Routine Import Worker

Cloudflare Worker for Phase 2D Routine Import AI extraction.

It never writes Routine items. It reads a verified user-owned R2 image, returns strict JSON review candidates, and Flutter still requires visual review and user acceptance before saving to Base Timeline.

## Setup

```bash
cd workers/routine-import-worker
npm install
```

No AI key goes into Flutter. Flutter only calls this Worker with a Firebase ID token.

## Deploy Modes

### Disabled mode

```toml
AI_PROVIDER = "disabled"
AI_MODEL = "gemini-2.5-flash"
```

Disabled mode needs no AI key. Use it to test Worker auth, R2 object-key checks, private R2 reads, `/health`, and safe fallback behavior. Extraction returns `engine: "disabled"` with a manual-review warning.

### Fake mode

```toml
AI_PROVIDER = "fake"
AI_MODEL = "gemini-2.5-flash"
```

Fake mode needs no AI key. Use it to test the Flutter AI review UI with deterministic candidates. Fake candidates still must be reviewed, edited, dragged, and accepted by the user before they can become Base Timeline items.

### Real AI mode

```toml
AI_PROVIDER = "gemini"
AI_MODEL = "gemini-2.5-flash"
```

Gemini mode requires a Gemini API key stored as a Worker secret:

```bash
wrangler secret put GEMINI_API_KEY
```

OpenAI-compatible mode remains available:

```toml
AI_PROVIDER = "openai"
AI_MODEL = "<model-name>"
```

OpenAI mode requires an OpenAI API key stored as a Worker secret:

```bash
wrangler secret put OPENAI_API_KEY
```

Real AI output still returns review candidates only. It never writes Routine items directly and must pass Worker validation, Flutter validation, visual timeline review, and user acceptance.

## Deploy

```bash
wrangler deploy
curl https://YOUR_WORKER_URL/health
```

Expected health response:

```json
{
  "ok": true,
  "service": "routine-import-worker",
  "projectId": "optivus-lifeos",
  "bucket": "optivus-uploads-dev",
  "aiProvider": "disabled"
}
```

## Required Bindings And Vars

The R2 bucket must be bound as `UPLOAD_BUCKET`.

Firebase project id must be `optivus-lifeos`.

`wrangler.toml` defaults:

```toml
name = "optivus-routine-import-worker-dev"
main = "src/index.ts"
compatibility_date = "2026-06-02"
compatibility_flags = ["nodejs_compat"]

[vars]
FIREBASE_PROJECT_ID = "optivus-lifeos"
R2_BUCKET_NAME = "optivus-uploads-dev"
MAX_IMAGE_BYTES = "15728640"
GEMINI_INLINE_MAX_IMAGE_BYTES = "11534336"
AI_PROVIDER = "disabled"
AI_MODEL = "gemini-2.5-flash"

[[r2_buckets]]
binding = "UPLOAD_BUCKET"
bucket_name = "optivus-uploads-dev"

[observability]
enabled = true
head_sampling_rate = 1
```

## Flutter Run

Run Flutter with both the upload Worker and routine-import Worker configured:

```bash
flutter run \
  --dart-define=OPTIVUS_BACKEND=firebase \
  --dart-define=OPTIVUS_UPLOAD_MODE=r2 \
  --dart-define=OPTIVUS_R2_UPLOAD_WORKER_URL=https://optivus-r2-upload-worker-dev.nairitstock.workers.dev \
  --dart-define=OPTIVUS_ROUTINE_IMPORT_AI_MODE=worker \
  --dart-define=OPTIVUS_ROUTINE_IMPORT_WORKER_URL=https://YOUR_ROUTINE_IMPORT_WORKER_URL
```

## Manual Curl Checks

Health:

```bash
curl https://YOUR_WORKER_URL/health
```

Missing auth rejects:

```bash
curl -i -X POST https://YOUR_WORKER_URL/v1/routine-import/extract \
  -H "Content-Type: application/json" \
  -d '{"reviewId":"review","source":"classes","uploadedAssetR2Key":"users/u/onboarding/class_timetable/a.jpg","sourceLabel":"Classes"}'
```

Extraction with Firebase ID token:

```bash
curl -X POST https://YOUR_WORKER_URL/v1/routine-import/extract \
  -H "Authorization: Bearer FIREBASE_ID_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "reviewId": "onboarding_classes_import_review",
    "source": "classes",
    "uploadedAssetId": "ASSET_ID",
    "uploadedAssetR2Key": "users/UID/onboarding/class_timetable/ASSET_ID.jpg",
    "uploadedAssetStatus": "uploaded",
    "sourceLabel": "Classes"
  }'
```

Expected disabled-provider result:

```json
{
  "engine": "disabled",
  "engineVersion": "phase2d-disabled",
  "warnings": ["AI provider is disabled."],
  "candidates": [
    {
      "needsManualReview": true,
      "hasFixedTime": false
    }
  ]
}
```

## Safety Checks

The Worker rejects:

- missing auth
- unverified email
- object keys outside `users/{uid}/onboarding/...`
- `..`, backslashes, double slashes
- unsafe image key extensions
- unknown source/purpose
- profile photo purpose
- missing R2 object
- non-JPEG/PNG/WEBP source object content types
- images larger than `MAX_IMAGE_BYTES`
- Gemini inline images larger than `GEMINI_INLINE_MAX_IMAGE_BYTES` return a warning instead of calling the provider
- malformed AI JSON
- AI payloads that include Routine items, applied Routine IDs, local file paths, or image bytes

Typecheck:

```bash
npm run typecheck
```

## Contract Checklist

Keep these checks passing before Phase 3:

- `/health` returns the configured Firebase project, bucket, and AI provider.
- Object-key validation rejects another uid.
- Object-key validation rejects `profile_photo` and any non-routine-import purpose.
- Source object content type rejects anything except JPEG, PNG, or WEBP.
- Disabled provider returns `engine: "disabled"` and `engineVersion: "phase2d-disabled"`.
- Fake provider returns strict JSON candidates with `engine: "fake"`.
- Real provider returns `engine: "aiVision"` and never bypasses review.
- Invalid AI JSON returns the warning `AI output could not be safely parsed. Review manually.`
- Candidate sanitization never exposes `routineItems`, `appliedRoutineItemIds`, `imageBytes`, `localPath`, `localFilePath`, or `localPreviewPath`.
- Flutter must still validate candidates and require visual review before converting accepted candidates into Routine items.
