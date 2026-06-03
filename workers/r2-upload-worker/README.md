# Optivus R2 Upload Worker

Phase 2A scaffold for onboarding image uploads. Flutter asks this Worker for a short-lived R2 presigned `PUT` URL, uploads prepared image bytes directly to R2, then stores upload metadata in Firestore.

## Endpoints

- `GET /health`
- `POST /v1/uploads/sign`
- `POST /v1/uploads/complete`
- `POST /v1/uploads/delete`

`/v1/uploads/sign` requires `Authorization: Bearer <Firebase ID token>`.

## Verification

This scaffold verifies Firebase ID tokens as JWTs using Google secure token JWKS:

- issuer: `https://securetoken.google.com/optivus-lifeos`
- audience: `optivus-lifeos`
- `email_verified` must be `true`

No Firebase Functions are used.

## Upload Rules

- source feature: `onboarding`
- purposes: `class_timetable`, `work_schedule`, `eating_menu`, `skin_care`, `profile_photo`
- profile content types: `image/jpeg`, `image/png`
- routine import content types: `image/jpeg`, `image/png`, `image/webp`
- profile max size: `5242880` bytes
- routine import max size: `15728640` bytes
- object key: `users/{uid}/onboarding/{purpose}/{assetId}.{jpg|png|webp}`

R2 presigned URLs work with the S3 API domain, not custom domains. The Worker signs against `https://<R2_ACCOUNT_ID>.r2.cloudflarestorage.com`.

## Manual Configuration

Required non-secret vars are configured in `wrangler.toml`:

```text
FIREBASE_PROJECT_ID=optivus-lifeos
R2_BUCKET_NAME=optivus-uploads-dev
R2_ACCOUNT_ID=<account id>
UPLOAD_URL_EXPIRES_SECONDS=900
MAX_PROFILE_UPLOAD_BYTES=5242880
MAX_ROUTINE_IMPORT_UPLOAD_BYTES=15728640
ALLOWED_ORIGINS=
```

Required R2 bucket binding:

```toml
[[r2_buckets]]
binding = "UPLOAD_BUCKET"
bucket_name = "optivus-uploads-dev"
```

Required secrets:

```bash
wrangler secret put R2_ACCESS_KEY_ID
wrangler secret put R2_SECRET_ACCESS_KEY
```

Do not put `R2_ACCESS_KEY_ID` or `R2_SECRET_ACCESS_KEY` in `wrangler.toml` or Flutter.

## Deploy

```bash
npm install
npm run typecheck
wrangler deploy
```

## Test Health

```bash
curl https://YOUR_WORKER_URL/health
```

Flutter R2 mode:

```bash
flutter run \
  --dart-define=OPTIVUS_BACKEND=firebase \
  --dart-define=OPTIVUS_UPLOAD_MODE=r2 \
  --dart-define=OPTIVUS_R2_UPLOAD_WORKER_URL=https://YOUR_WORKER_URL
```
