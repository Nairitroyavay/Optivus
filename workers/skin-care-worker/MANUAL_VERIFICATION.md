# Manual Verification

Skin-care Worker image validation:

1. Store an owned R2 object under `users/<uid>/onboarding/skin_care/<asset>.heic`
   with `httpMetadata.contentType` set to `image/heic`.
2. POST `/v1/skin-care/products/analyze` with that object key in
   `productPhotos`.
3. Expect HTTP `415` with JSON:
   `{"error":"unsupported_content_type","message":"This photo format is not supported. Please upload JPEG, PNG, or WEBP."}`.
4. Repeat with `/v1/skin-care/routine/generate` using the same key as
   `facePhotoR2Key`; expect the same `415` JSON error.
5. Repeat both paths with `image/jpeg`, `image/png`, and `image/webp` objects
   under 15 MB; they should pass validation and continue to the AI provider.
