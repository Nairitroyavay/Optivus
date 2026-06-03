# Optivus Routine Import Worker

Cloudflare Worker for Phase 2D Routine Import AI extraction.

It never writes Routine items. It reads a verified user-owned R2 image, returns strict JSON review candidates, and Flutter still requires visual review and user acceptance before saving to Base Timeline.

## Setup

```bash
cd workers/routine-import-worker
npm install
```

AI provider secrets are only needed when `AI_PROVIDER` uses a real provider such as OpenAI:

```bash
wrangler secret put OPENAI_API_KEY
```

`AI_PROVIDER=disabled` deploys without any AI key.

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

[vars]
FIREBASE_PROJECT_ID = "optivus-lifeos"
R2_BUCKET_NAME = "optivus-uploads-dev"
MAX_IMAGE_BYTES = "1048576"
AI_PROVIDER = "disabled"
AI_MODEL = ""

[[r2_buckets]]
binding = "UPLOAD_BUCKET"
bucket_name = "optivus-uploads-dev"
```

No AI key goes into Flutter.

## Flutter Run

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
  "engine": "fake",
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
- non-jpg keys
- unknown source/purpose
- profile photo purpose
- missing R2 object
- images larger than `MAX_IMAGE_BYTES`

Typecheck:

```bash
npm run typecheck
```
