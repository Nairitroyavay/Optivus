# Phase 3 staging Worker runbook

Status: **locally prepared, deployment blocked**.

This runbook is limited to Phase 3 staging. Production deployment is not
authorized. None of the commands below may be run until the Phase 3
authorization record contains every exact staging target and says
`YES FOR STAGING ONLY`.

## Authorization gate

The repository currently has no approved value for any of these fields:

| Required field | Current status |
| --- | --- |
| Staging Firebase project ID | Required |
| Cloudflare account/target | Required |
| Staging R2 bucket | Required |
| R2 Upload Worker name | Required |
| Routine Import Worker name | Required |
| Nutrition Worker name | Required |
| Skin Care Worker name | Required |
| Coach Worker name | Required |
| Allowed staging origins | Required |
| Staging deploy authorization | Unresolved (`YES FOR STAGING ONLY / NO`) |
| Production deploy authorization | **NO** |

Each checked-in `staging` environment therefore uses:

- a Worker name ending in `staging-pending-authorization`;
- `required-approved-*` resource placeholders;
- `https://staging-origin.invalid` as a non-routable origin placeholder.

Those values are intentional deployment blockers, not real targets. Replace
them only with targets copied from the approved authorization record. Do not
reuse the checked-in development Worker names, development R2 bucket, or a
production resource.

## Secret boundary

Only secret names are declared in configuration:

- `GEMINI_API_KEY` for AI Workers;
- `R2_ACCESS_KEY_ID` and `R2_SECRET_ACCESS_KEY` for R2 Upload.

Never put values in source, Dart defines, documentation, screenshots, command
arguments, or chat. After authorization, provision values interactively with
the Cloudflare dashboard or the relevant command from the Worker directory:

```sh
npx wrangler secret put GEMINI_API_KEY --env staging
npx wrangler secret put R2_ACCESS_KEY_ID --env staging
npx wrangler secret put R2_SECRET_ACCESS_KEY --env staging
```

Run only the command applicable to that Worker. Verify secret *names* through
Cloudflare without printing values.

## Local checks

These commands do not deploy:

```sh
npm run typecheck
npm test
npx wrangler types /tmp/optivus-staging-env.d.ts \
  --env staging \
  --include-runtime=false
npx wrangler deploy --env staging --dry-run \
  --outdir /tmp/optivus-staging-dry-run
```

The dry run is structurally valid while placeholders remain, but that is not
deployment readiness. Before an authorized deployment, search the selected
Worker configuration and stop if any of these remain:

```text
pending-authorization
required-approved-
staging-origin.invalid
```

## Authorized deployment sequence

After every target is exact and the record explicitly says
`YES FOR STAGING ONLY`:

1. Record `git rev-parse HEAD` and the dirty-tree state.
2. Re-run that Worker's typecheck, tests, generated environment types, and dry
   run.
3. Confirm its required secret names are provisioned.
4. Deploy only that Worker with `npx wrangler deploy --env staging`.
5. Record the exact deployment/version ID and returned staging URL.
6. Test health, unauthenticated rejection, invalid-token rejection, one
   authenticated synthetic success, and one safe failure.
7. Record the result before moving to the next Worker.

Required order:

1. R2 Upload
2. Routine Import
3. Nutrition
4. Skin Care
5. Coach

Do not continue to the next Worker when the current Worker has a failed smoke
test or unresolved S0/S1 defect.

## Version evidence and rollback

Record version/deployment information immediately after each deploy:

```sh
npx wrangler versions list --env staging
npx wrangler deployments list --env staging
```

If an authorized staging deployment must be rolled back, use the recorded
known-good version from that same staging Worker:

```sh
npx wrangler rollback <KNOWN_GOOD_VERSION_ID> --env staging
```

Re-run the full smoke set after rollback and document both version IDs.
Production rollback or deployment is outside this authorization.
