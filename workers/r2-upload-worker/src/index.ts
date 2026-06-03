import { PutObjectCommand, S3Client } from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";
import { createRemoteJWKSet, jwtVerify } from "jose";

type Env = {
  FIREBASE_PROJECT_ID: string;
  R2_ACCOUNT_ID: string;
  R2_ACCESS_KEY_ID: string;
  R2_SECRET_ACCESS_KEY: string;
  R2_BUCKET_NAME: string;
  UPLOAD_BUCKET: R2Bucket;
  UPLOAD_URL_EXPIRES_SECONDS?: string;
  MAX_PROFILE_UPLOAD_BYTES?: string;
  MAX_ROUTINE_IMPORT_UPLOAD_BYTES?: string;
  ALLOWED_ORIGINS?: string;
};

type VerifiedUser = {
  uid: string;
};

type ObjectKeyInfo = {
  purpose: string;
  assetId: string;
  extension: string;
};

const PROFILE_PHOTO_MAX_BYTES = 5 * 1024 * 1024;
const ROUTINE_IMPORT_MAX_BYTES = 15 * 1024 * 1024;

const firebaseJwks = createRemoteJWKSet(
  new URL(
    "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com",
  ),
);

const routineImportPurposes = new Set([
  "class_timetable",
  "work_schedule",
  "eating_menu",
  "skin_care",
]);

const approvedPurposes = new Set([
  ...routineImportPurposes,
  "profile_photo",
]);

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: corsHeaders(request, env) });
    }

    try {
      const url = new URL(request.url);
      if (request.method === "GET" && url.pathname === "/health") {
        const config = validateWorkerConfig(env);
        return jsonResponse(request, env, {
          ok: true,
          service: "r2-upload-worker",
          bucket: config.bucketName,
          projectId: config.projectId,
        });
      }

      if (request.method === "POST" && url.pathname === "/v1/uploads/sign") {
        return handleSignUpload(request, env);
      }

      if (request.method === "POST" && url.pathname === "/v1/uploads/complete") {
        return handleCompleteUpload(request, env);
      }

      if (request.method === "POST" && url.pathname === "/v1/uploads/delete") {
        return handleDeleteUpload(request, env);
      }

      return jsonResponse(request, env, { error: "not_found" }, 404);
    } catch (error) {
      const httpError = error instanceof HttpError ? error : null;
      return jsonResponse(
        request,
        env,
        {
          error: httpError?.code ?? "internal_error",
          message: httpError?.message ?? "Upload worker error.",
        },
        httpError?.status ?? 500,
      );
    }
  },
};

async function handleSignUpload(request: Request, env: Env): Promise<Response> {
  const user = await requireVerifiedFirebaseUser(request, env);
  const body = await readSmallJson(request);
  const purpose = readString(body, "purpose");
  const sourceFeature = readString(body, "sourceFeature");
  const contentType = normalizedContentType(readString(body, "contentType"));
  const sizeBytes = readNumber(body, "sizeBytes");

  if (!approvedPurposes.has(purpose)) {
    throw new HttpError(400, "invalid_purpose", "Upload purpose is not allowed.");
  }
  if (sourceFeature !== "onboarding") {
    throw new HttpError(400, "invalid_source", "Only onboarding uploads are enabled in Phase 2A.");
  }
  if (!isAllowedContentTypeForPurpose(purpose, contentType)) {
    throw new HttpError(400, "invalid_content_type", contentTypeErrorMessage(purpose));
  }
  const maxBytes = maxUploadBytesForPurpose(env, purpose);
  if (!Number.isFinite(sizeBytes) || sizeBytes <= 0 || sizeBytes > maxBytes) {
    throw new HttpError(
      400,
      "invalid_size",
      sizeBytes > maxBytes ? uploadTooLargeMessage(purpose) : "Upload size is invalid.",
    );
  }

  const assetId = crypto.randomUUID();
  const objectKey = buildObjectKey(user.uid, purpose, assetId, contentType);
  const expiresIn = numberEnv(env.UPLOAD_URL_EXPIRES_SECONDS, 900);
  const uploadUrl = await getSignedUrl(
    r2Client(env),
    new PutObjectCommand({
      Bucket: requiredEnv(env.R2_BUCKET_NAME, "R2_BUCKET_NAME"),
      Key: objectKey,
      ContentType: contentType,
    }),
    { expiresIn },
  );

  return jsonResponse(request, env, {
    assetId,
    objectKey,
    uploadUrl,
    expiresAt: new Date(Date.now() + expiresIn * 1000).toISOString(),
  });
}

async function handleCompleteUpload(request: Request, env: Env): Promise<Response> {
  const user = await requireVerifiedFirebaseUser(request, env);
  const body = await readSmallJson(request);
  const assetId = safeSegment(readString(body, "assetId"), "assetId");
  const objectKey = readString(body, "objectKey");
  const sizeBytes = readNumber(body, "sizeBytes");

  const keyInfo = assertOwnedObjectKey(user.uid, objectKey);
  if (keyInfo.assetId !== assetId) {
    throw new HttpError(400, "asset_mismatch", "Object key does not match assetId.");
  }
  if (!Number.isFinite(sizeBytes) || sizeBytes <= 0) {
    throw new HttpError(400, "invalid_size", "Upload size is invalid.");
  }
  const maxBytes = maxUploadBytesForPurpose(env, keyInfo.purpose);
  if (sizeBytes > maxBytes) {
    throw new HttpError(400, "invalid_size", uploadTooLargeMessage(keyInfo.purpose));
  }

  const object = await requiredUploadBucket(env).head(objectKey);
  if (!object) {
    throw new HttpError(404, "object_not_found", "Uploaded object was not found.");
  }
  if (typeof object.size === "number" && object.size !== sizeBytes) {
    throw new HttpError(400, "size_mismatch", "Uploaded object size does not match.");
  }

  return jsonResponse(request, env, { ok: true, assetId, objectKey });
}

async function handleDeleteUpload(request: Request, env: Env): Promise<Response> {
  const user = await requireVerifiedFirebaseUser(request, env);
  const body = await readSmallJson(request);
  const objectKey = readString(body, "objectKey");
  assertOwnedObjectKey(user.uid, objectKey);

  await requiredUploadBucket(env).delete(objectKey);

  return jsonResponse(request, env, { ok: true, objectKey });
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

function r2Client(env: Env): S3Client {
  return new S3Client({
    region: "auto",
    endpoint: `https://${requiredEnv(env.R2_ACCOUNT_ID, "R2_ACCOUNT_ID")}.r2.cloudflarestorage.com`,
    credentials: {
      accessKeyId: requiredEnv(env.R2_ACCESS_KEY_ID, "R2_ACCESS_KEY_ID"),
      secretAccessKey: requiredEnv(env.R2_SECRET_ACCESS_KEY, "R2_SECRET_ACCESS_KEY"),
    },
  });
}

function buildObjectKey(
  uid: string,
  purpose: string,
  assetId: string,
  contentType: string,
): string {
  const safeUid = safeSegment(uid, "uid");
  const safePurpose = safeSegment(purpose, "purpose");
  const safeAssetId = safeSegment(assetId, "assetId");
  const extension = extensionForContentType(contentType);
  return `users/${safeUid}/onboarding/${safePurpose}/${safeAssetId}.${extension}`;
}

function assertOwnedObjectKey(uid: string, objectKey: string): ObjectKeyInfo {
  const safeUid = safeSegment(uid, "uid");
  if (
    objectKey.includes("..") ||
    objectKey.includes("\\") ||
    objectKey.includes("//")
  ) {
    throw new HttpError(400, "invalid_object_key", "Object key is not allowed.");
  }

  const parts = objectKey.split("/");
  if (
    parts.length !== 5 ||
    parts[0] !== "users" ||
    parts[1] !== safeUid ||
    parts[2] !== "onboarding" ||
    !approvedPurposes.has(parts[3])
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
  if (!isSafeExtensionForPurpose(parts[3], extension)) {
    throw new HttpError(400, "invalid_object_key", "Object key is not allowed.");
  }
  return { purpose: parts[3], assetId, extension };
}

async function readSmallJson(request: Request): Promise<Record<string, unknown>> {
  const contentLength = Number(request.headers.get("Content-Length") ?? "0");
  if (Number.isFinite(contentLength) && contentLength > 4096) {
    throw new HttpError(413, "body_too_large", "Request body is too large.");
  }
  const body = await request.json();
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

function readNumber(body: Record<string, unknown>, key: string): number {
  const value = body[key];
  if (typeof value !== "number") {
    throw new HttpError(400, "missing_field", `Missing ${key}.`);
  }
  return value;
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

function maxUploadBytesForPurpose(env: Env, purpose: string): number {
  if (purpose === "profile_photo") {
    return numberEnv(env.MAX_PROFILE_UPLOAD_BYTES, PROFILE_PHOTO_MAX_BYTES);
  }
  if (routineImportPurposes.has(purpose)) {
    return numberEnv(env.MAX_ROUTINE_IMPORT_UPLOAD_BYTES, ROUTINE_IMPORT_MAX_BYTES);
  }
  throw new HttpError(400, "invalid_purpose", "Upload purpose is not allowed.");
}

function uploadTooLargeMessage(purpose: string): string {
  return purpose === "profile_photo"
    ? "This photo is too large. Please upload a profile photo under 5 MB."
    : "This photo is too large. Please upload a photo under 15 MB.";
}

function contentTypeErrorMessage(purpose: string): string {
  return purpose === "profile_photo"
    ? "Please upload JPEG or PNG for profile photos."
    : "Please upload JPEG, PNG, or WEBP for now.";
}

function isAllowedContentTypeForPurpose(purpose: string, contentType: string): boolean {
  if (purpose === "profile_photo") {
    return contentType === "image/jpeg" || contentType === "image/png";
  }
  if (routineImportPurposes.has(purpose)) {
    return contentType === "image/jpeg" ||
      contentType === "image/png" ||
      contentType === "image/webp";
  }
  return false;
}

function normalizedContentType(value: string): string {
  const contentType = value.split(";")[0].trim().toLowerCase();
  return contentType === "image/jpg" ? "image/jpeg" : contentType;
}

function extensionForContentType(contentType: string): string {
  if (contentType === "image/png") return "png";
  if (contentType === "image/webp") return "webp";
  return "jpg";
}

function isSafeExtensionForPurpose(purpose: string, extension: string): boolean {
  if (extension !== "jpg" && extension !== "jpeg" && extension !== "png" && extension !== "webp") {
    return false;
  }
  if (purpose === "profile_photo") return extension !== "webp";
  return routineImportPurposes.has(purpose);
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

function validateWorkerConfig(env: Env): { projectId: string; bucketName: string } {
  const projectId = requiredEnv(env.FIREBASE_PROJECT_ID, "FIREBASE_PROJECT_ID");
  const bucketName = requiredEnv(env.R2_BUCKET_NAME, "R2_BUCKET_NAME");
  requiredEnv(env.R2_ACCOUNT_ID, "R2_ACCOUNT_ID");
  requiredEnv(env.R2_ACCESS_KEY_ID, "R2_ACCESS_KEY_ID");
  requiredEnv(env.R2_SECRET_ACCESS_KEY, "R2_SECRET_ACCESS_KEY");
  requiredUploadBucket(env);
  return { projectId, bucketName };
}

function numberEnv(value: string | undefined, fallback: number): number {
  const parsed = Number(value);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

function jsonResponse(
  request: Request,
  env: Env,
  body: Record<string, unknown>,
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
    .filter((item) => item.length > 0);
  const allowed =
    origin !== null &&
    (allowedOrigins.includes(origin) ||
      origin.startsWith("http://localhost:") ||
      origin.startsWith("http://127.0.0.1:"));

  if (!allowed) {
    return {};
  }
  return {
    "Access-Control-Allow-Origin": origin,
    "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
    "Access-Control-Allow-Headers": "Authorization,Content-Type",
    "Access-Control-Max-Age": "86400",
  };
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
