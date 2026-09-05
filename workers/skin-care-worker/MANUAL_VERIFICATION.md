# Manual Verification

Use authenticated requests and owned, exact object identities.

1. Upload one JPEG, PNG, or WEBP product photo at
   `users/<uid>/onboarding/skin_products/<assetId>.<ext>` and POST its key as
   the single `productPhotos` entry to `/v1/skin-care/products/analyze`.
2. Use an owned `skin_face` object for the face-photo recommendation request.
   The final selected-product routine request must omit `facePhotoR2Key`.
3. Verify JPEG/PNG/WEBP objects within the configured size limit proceed to AI.
   Oversized objects must fail before their bytes are loaded into memory.
4. Verify unsupported content types are rejected, including HEIC. Modern uploads
   do not accept HEIC or the legacy `skin_care` path.
5. Verify another UID, a mismatched asset ID, extra path segments, and multiple
   product photos are rejected.

Legacy `users/<uid>/onboarding/skin_care/<assetId>.<ext>` references have explicit
read/delete-only migration compatibility. They are not modern upload targets.
A matching legacy reference can satisfy only the established active Step 7 slot;
a current modern upload takes priority.
