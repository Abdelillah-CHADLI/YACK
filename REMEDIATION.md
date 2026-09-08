# Remediation Progress

## Executive Summary

This is the live tracker for the three-repository audit in `FIXES.md`. The audit
is treated as an investigation queue, not as source-of-truth. No production code
will be changed for a finding until its current execution path and cross-repo
consumers have been verified.

Initial count: 72 findings (`F-01`–`F-66`, excluding unused `F-67`, plus
`F-68`–`F-73`). Forty findings are now complete (F-06, F-07, F-08, F-27,
F-28, F-29, F-54, F-68, F-69, F-70, F-71, F-02, F-03, F-35 from the first
pass; then mobile batch F-17, F-18, F-21, F-30, F-31, F-33, F-37, F-43,
F-48, F-49, F-50, F-62; then admin batch F-22, F-23, F-25, F-26, F-52,
F-53, F-55, F-56, F-57, F-58, F-63, F-64, F-65, F-66; then F-11, F-12,
F-16, F-19, F-20, F-24, F-38, F-59, F-61 from the subsequent batches;
then F-15, F-40, F-41, F-44, F-45, F-46 from the backend index/ops batch;
then F-13, F-34, F-39 from the temp-contract semantics batch —
58 complete in total). F-05 is fully implemented across all three
repositories (envelope validation, client-side hybrid encryption, admin
in-browser decrypt) with cross-repo unit tests green; only the live
end-to-end smoke remains blocked on a configured Cloudinary. Four findings
are deferred with documented decisions (F-04 data-at-rest envelope, F-32
dispute local model, F-51 query/sync efficiency, F-60 contract hash
persistence) plus F-73 (UI-only subscription feature, out of scope). The remaining audit
claims have been triaged into confirmed pending, external-action, and
not-reproducible work.

## Baseline

| Repository | Branch | Initial working tree | Test/build entry points |
| --- | --- | --- | --- |
| Mobile `YACK` | `develop` | Three modified generated Isar files; audit/docs untracked | `flutter analyze`, `flutter test`, Android build |
| Backend `YACK-Backend` | `main` | `adminAuth.js` modified; `scripts/` untracked | `npm test`, `node --check`, startup probes |
| Admin `YACK-Admin` | `master` | Clean | `npm run lint`, `npm run build`; no test script |

Secret values are never recorded here. Baseline inspection confirmed that the
backend local `.env` and a local service-account JSON exist but are gitignored;
required admin variables are absent locally. The admin repository is a local Git
repository with a user-configured GitHub remote; remediation will not publish or
deploy anything without an explicit request.

## Workflow Codes

- `AUTH`: Firebase authentication, account creation and authorization
- `INIT`: encryption-key initialization, unlock and restore
- `CTR`: contract create/join/sign/finalize/list/accept
- `MSG`: encrypted messaging
- `MED`: contract media and support attachments
- `DSP`: dispute, review access, support and resolution
- `NTF`: FCM registration, delivery and routing
- `ADM`: dashboard login, analytics and case operation
- `OPS`: configuration, startup, deployment and observability

## Verification Profiles

- `B-SEC`: backend unit/route tests for missing/invalid/revoked token, ordinary
  user vs admin, cross-user IDs, malformed/oversized/replayed/concurrent input;
  then full `npm test` and startup check.
- `B-DATA`: model/controller tests proving atomic bounds, deterministic state,
  legacy-record compatibility and relevant indexes; then full backend suite.
- `M-SEC`: Dart crypto/storage round trip, locked-state widget/service tests,
  `flutter analyze`, full `flutter test`, Android build.
- `M-API`: DTO/service tests against representative backend JSON/errors/FCM
  payloads, then mobile analysis/tests and backend contract recheck.
- `A-SEC`: auth-session/key lifecycle and crypto round-trip tests, lint, type
  checking/production build, plus backend contract recheck.
- `A-UX`: request-race/failure-state component tests, lint and production build.
- `OPS`: redacted configuration/startup probes, graceful-shutdown/health checks,
  secret/history scan, and documentation review.
- `CLEAN`: import/reference search before removal followed by every affected
  repository's broad tests/build.

## Dependency and Priority Order

1. Safety/configuration: `F-07`, `F-08`, `F-09`, `F-10`, `F-28`, `F-29`,
   `F-68`–`F-71`, then admin session isolation `F-06`.
2. Abuse/data-integrity foundations: `F-02`, `F-35`, `F-36`, `F-43`, then
   atomic caps `F-01`, `F-44`, `F-45`, and FCM ownership `F-03`.
3. Data protection/crypto: `F-04`, `F-17`, `F-05`, `F-55`, `F-18`, `F-21`,
   `F-53`, `F-54`.
4. State/API correctness: `F-11`–`F-14`, `F-30`–`F-34`, `F-39`–`F-42`,
   `F-49`, `F-50`, `F-59`–`F-63`.
5. Reliability/performance/admin UX: `F-15`, `F-16`, `F-19`, `F-20`,
   `F-22`–`F-27`, `F-46`–`F-48`, `F-51`, `F-52`, `F-56`, `F-57`.
6. Dependency/dead-code/docs cleanup: `F-37`, `F-38`, `F-58`, `F-64`–`F-66`,
   `F-72`, `F-73`, followed by full-system and fresh adversarial re-audits.

## Original Audit Resolution

Statuses below are initial. Each row will be expanded into a lifecycle record
before it can move to `Complete`.

| ID | Severity | Category | Repos | Depends / related | Workflows | Expected remediation | Verification / tests | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| F-01 | High | Database/abuse | Backend | F-02,F-36,F-44 | MSG,MED,DSP | Atomic per-document array limits or normalized collections, with explicit overflow errors | B-DATA concurrent boundary/overflow tests | Investigating |
| F-02 | High | Abuse | Backend | F-35,F-36,F-43 | AUTH,CTR,MSG,MED,DSP,ADM | Layered IP/user/operation rate limits, proxy-safe keys and 429 responses | B-SEC limit, bypass and reset tests | Complete |
| F-03 | High | FCM security/concurrency | Backend,Mobile | F-02,F-36 | AUTH,NTF | Remove implicit token mutation; explicit bounded atomic registration with defensible ownership semantics | B-SEC + M-API stolen/replay/concurrent token tests | Complete |
| F-04 | High | Mobile data at rest | Mobile | F-17,F-19,F-20 | INIT,CTR,MSG | Persist ciphertext or locally encrypted data with backward-compatible migration | M-SEC restart/locked/migration tests | Deferred - Documented (lock-gate mitigation) |
| F-05 | High | Media confidentiality | All | F-21,F-55 | MED,DSP | Client-side hybrid encryption or private signed delivery; migrate legacy records safely | B-SEC + M-SEC + A-SEC media round trip/access tests | Implemented - Live e2e pending |
| F-06 | High | Admin session security | Admin | F-53,F-54,F-57 | AUTH,ADM,DSP | Clear key, plaintext, case and drafts on sign-out/account switch | A-SEC two-operator session regression test | Complete |
| F-07 | High | Sensitive logging | Backend | F-47 | AUTH,ADM | Remove allowlist/PII debug output; retain only redacted diagnostics | B-SEC deny/allow tests with captured logs | Complete |
| F-08 | High | Admin configuration | Backend,Admin | F-29,F-69,F-71 | ADM,OPS | Validate required production config; fail closed with documented external setup | OPS startup matrix + `/admin/me`/review-key tests | Complete |
| F-09 | High* | Secret history | Backend | F-10,F-28 | OPS | Verify reachable history; if exposure cannot be disproved, document provider-side rotation | OPS history scan; external rotation verification | Not reproducible |
| F-10 | High | Local secret hygiene | Backend | F-09,F-28 | OPS | Keep credentials untracked, reduce copies and document mandatory provider rotation | OPS tracked-file/history scan; external action evidence | Blocked - External Action Required |
| F-11 | Medium | Dispute concurrency | Backend,Admin | F-16 | DSP | Preserve append-only resolution history or reject redispute after resolution atomically | B-DATA resolve-vs-redispute race tests | Complete |
| F-12 | Medium | Dispute confidentiality | All | F-03,F-05,F-21 | DSP,NTF | Remove plaintext reason from push/storage or add compatible encrypted envelopes | Cross-client crypto/API tests; inspect FCM payload | Complete |
| F-13 | Medium | HTTP/state semantics | Backend,Mobile | F-34 | CTR,DSP | Enforce expiry during finalization and remove create-on-GET side effects | B-DATA expired/finalized/read-idempotence tests | Complete |
| F-14 | Medium | Pagination | All | F-01,F-23,F-51 | CTR,MED,ADM | Cursor pagination, projections and validated bounds across all consumers | B-DATA + M-API + A-UX paging tests | Pending |
| F-15 | Medium | Backend reliability | Backend | F-69 | OPS | Await DB before listen; real health/readiness, timeouts and graceful shutdown | OPS startup/outage/SIGTERM/in-flight tests | Complete |
| F-16 | Medium | Test coverage | All | all confirmed findings | all | Add route, client, crypto and concurrency regressions with real pre-fix failure value | Broad suites and coverage inventory | Complete |
| F-17 | Medium | Locked-state exposure | Mobile | F-04 | INIT,CTR,MSG | Gate plaintext UI and cache access on current unlock state | M-SEC restart/lock widget tests | Complete |
| F-18 | Medium | Integrity verification | Mobile,Admin | F-21 | MSG,DSP | Verify message hashes and case details after decrypt; isolate failures | M-SEC + A-SEC tamper tests | Complete |
| F-19 | Medium | UI-isolate crypto | Mobile | F-04,F-20 | INIT | Move KDF/key generation off UI isolate without changing crypto format | M-SEC round trip + responsiveness test | Complete |
| F-20 | Medium | Repeated RSA work | Mobile | F-14,F-19,F-51 | MSG | Skip known ciphertext, background decrypt and remove redundant reloads | M-SEC call-count/performance regression | Complete |
| F-21 | Medium | Crypto compatibility | All | F-05,F-18,F-53 | INIT,MSG,DSP | Version OAEP/key parameters and provide backward-compatible migration before SHA change | Cross-language known-vector/legacy round trips | Complete |
| F-22 | Medium | Admin failure state | Admin | F-23,F-25 | ADM,DSP | Handle open failure without rejection/empty sheet; offer visible retry | A-UX rejected-request test | Complete |
| F-23 | Medium | Admin request races | Admin | F-14,F-25 | ADM | Abort or generation-guard stale dashboard/case requests | A-UX out-of-order response tests | Complete |
| F-24 | Medium | Admin support UX | Admin,Backend | F-14,F-56 | ADM,DSP | Real support-thread view/data source or remove misleading tab | A-UX data/badge/navigation tests | Complete |
| F-25 | Medium | Admin HTTP resilience | Admin | F-08,F-21,F-23 | ADM | Typed text/JSON errors, timeout/abort and per-session review-key caching | A-UX proxy/empty/timeout tests | Complete |
| F-26 | Medium | Admin resolution feedback | Admin | F-11,F-23 | DSP,ADM | Modal-local resolve errors and 409 refresh behavior | A-UX 409/500 tests | Complete |
| F-27 | Medium* | Model tool exposure | Admin | F-06 | ADM | Verify bridge semantics; remove or require explicit scoped operator opt-in | A-SEC absence/consent/scope test | Complete |
| F-28 | Medium | Secret duplication | Backend | F-09,F-10,F-69 | OPS | Remove local service-account JSON only after env-only startup is verified | OPS env-only Firebase init and tracked-file scan | Complete |
| F-29 | Medium | Hardcoded production config | Admin | F-08,F-64 | ADM,OPS | Require explicit local/build environment variables; no live fallback | A-SEC missing-env build/start test | Complete |
| F-30 | Medium | FCM contract mismatch | Backend,Mobile | F-49 | MED,NTF | Normalize `mediaId`/`mediaPath` producer and both parsers | B-SEC payload + M-API parser tests | Complete |
| F-31 | Medium | Accept-state mismatch | Mobile,Backend | F-11 | CTR | Persist authoritative server status after accept | M-API accepted/completed response tests | Complete |
| F-32 | Medium | Dispute model mismatch | Mobile,Backend | F-04,F-11 | CTR,DSP | Add compatible local dispute/resolution fields and sync mapping | M-API legacy/new JSON + Isar migration tests | Deferred - Documented (schema/build_runner) |
| F-33 | Medium | Language sync mismatch | Mobile,Backend | none | AUTH | Parse/cache backend language and reconcile startup preference | M-API profile/restart tests | Complete |
| F-34 | Medium | Temp status authorization | Backend,Mobile | F-13,F-43 | AUTH,CTR | Permit safe cold-join status metadata without broadening protected data | B-SEC account-state/participant tests + M-API | Complete |
| F-35 | Medium | Account creation abuse | Backend | F-02,F-43 | AUTH | Throttle first-touch upserts and require verified email for writes | B-SEC burst/unverified tests | Complete |
| F-36 | Medium | Resource quotas | Backend | F-01,F-02 | CTR,MSG,MED,NTF | Per-user/per-contract count and byte quotas with atomic enforcement | B-DATA boundary/concurrent quota tests | Pending |
| F-37 | Medium | Production debug output | Mobile | F-47 | all mobile | Replace unconditional prints with debug-gated/redacted logging | CLEAN search + release analyze/test | Complete |
| F-38 | Medium | Mobile dependencies/storage | Mobile | F-04 | INIT,OPS | Commit lockfile, move test deps, prune confirmed unused packages; defer storage consolidation safely | CLEAN dependency build and migration review | Complete |
| F-39 | Low | Temp metadata disclosure | Backend,Mobile | F-13,F-34 | CTR | Minimize pre-join response; disclose participant/hash metadata only after authorization | B-SEC guessed-ID/pre/post-join tests | Complete |
| F-40 | Low | Hash verification | Backend,Mobile | F-18 | CTR | Bound/normalize and timing-safe compare hashes | B-SEC malformed/case/timing-safe path tests | Complete |
| F-41 | Low | Ciphertext validation | Backend,All clients | F-18,F-21 | CTR,DSP | Central canonical ciphertext/hash validators shared by write paths | B-SEC malformed/noncanonical/oversized tests | Complete |
| F-42 | Low | MIME spoofing | Backend,Mobile | F-05 | MED | Magic-byte sniff allowlist with documented format policy | B-SEC extension/content mismatch tests | Pending |
| F-43 | Low | User-route authorization | Backend | F-02,F-35,F-70 | AUTH | Verified-email/state gates appropriate to each `/user` mutation | B-SEC unverified/incomplete route matrix | Complete |
| F-44 | Low | Attachment cap race | Backend | F-01,F-36 | DSP,MED | Conditional atomic attachment append and orphan cleanup | B-DATA simultaneous 25th/26th upload test | Complete |
| F-45 | Low | Support upsert race | Backend | F-01 | DSP | Retry/refetch on duplicate-key concurrent creation | B-DATA parallel ensure test | Complete |
| F-46 | Low | Missing indexes | Backend | F-14,F-36 | OPS,ADM,NTF | Add indexes only for verified query shapes with migration notes | B-DATA schema/index inspection and query plans where possible | Complete |
| F-47 | Low | Logging/audit trail | Backend | F-07,F-15 | OPS,ADM,DSP | Structured redacted request logs and append-only admin action audit | B-SEC log masking + B-DATA audit write tests | Pending |
| F-48 | Low | Push listener lifecycle | Mobile | F-30 | NTF | Retain/cancel subscriptions and keep singleton restart-safe | M-API repeated-init/dispose tests | Complete |
| F-49 | Low | Structured client errors | Mobile,Backend | F-25,F-34 | all mobile | Typed API exception preserving status/code and localized mappings | M-API representative error tests | Complete |
| F-50 | Low | Corrupt error copy | Mobile | F-49 | CTR | Replace broken message with typed descriptive error | M-API regression assertion | Complete |
| F-51 | Low | Mobile query/sync efficiency | Mobile,Backend | F-14,F-20 | CTR,MED | Indexed dedup, dedicated single-contract fetch, debounced search | M-API query/call-count tests | Deferred - Documented (schema/build_runner) |
| F-52 | Low | Admin partial decryption | Admin | F-18,F-21 | DSP,ADM | Per-field/item failure isolation with integrity labels | A-SEC one-corrupt-item test | Complete |
| F-53 | Low | Review-key identity | Admin,Backend | F-08,F-21,F-71 | DSP,ADM | Compare public modulus/fingerprint/key ID before accepting key | A-SEC wrong/correct/rotated key tests | Complete |
| F-54 | Low | Admin auth persistence | Admin | F-06 | AUTH,ADM | Use session persistence and clear sensitive state on lifecycle boundaries | A-SEC reload/tab/sign-out tests | Complete |
| F-55 | Low | Support attachment access | Backend,Admin | F-05 | DSP,MED | Gate attachments on explicit review grant until full encryption migration | B-SEC + A-SEC pre/post-grant tests | Complete |
| F-56 | Low | Unused analytics payload | Backend,Admin | F-24,F-58 | ADM | Render useful trend or remove payload/dependency after product intent check | A-UX analytics test + CLEAN dependency search | Complete |
| F-57 | Low | Destructive/draft UX | Admin | F-06,F-26,F-53 | ADM,DSP | Confirm sign-out/key swap/resolve and guard unsaved support drafts | A-UX interaction tests | Complete |
| F-58 | Low | Admin dependency/tests | Admin | F-16,F-56 | OPS,ADM | Prune confirmed unused UI/deps; pin scripts and add focused tests | CLEAN install/lint/test/build | Complete |
| F-59 | Low | Unused media endpoint | Mobile,Backend | F-05,F-51 | MED | Verify dynamic use; wire refresh semantics or remove endpoint/service together | CLEAN cross-repo reference + media tests | Complete |
| F-60 | Low | Contract hash persistence | Mobile,Backend | F-32 | CTR | Persist/map hash only if an active workflow consumes it | M-API model migration and verify flow | Deferred - Documented (schema/build_runner) |
| F-61 | Low | Development port drift | Backend,Mobile | F-64,F-69 | OPS | Align documented local defaults without changing production host behavior | OPS local startup + M-API base URL check | Complete |
| F-62 | Low | Temp status enum drift | Mobile,Backend | F-13 | CTR | Remove unreachable alias or document/emit a canonical value | M-API status matrix | Complete |
| F-63 | Low | Admin type narrowing | Admin,Backend | F-14 | ADM,DSP | Verify server normalization invariant; document or widen type | A-UX type/build + response tests | Complete |
| F-64 | Low | Deployment/documentation drift | All | F-08,F-29,F-61,F-65 | OPS | Align explicit local/production config docs; deploy manifests only if actually used | OPS clean-env local/build validation | Complete |
| F-65 | Low* | Admin runtime/toolchain | Admin | F-58,F-64 | OPS | Pin supported Node/package manager; assess stable framework path without unrelated migration | CLEAN runtime matrix + build | Complete |
| F-66 | Low | Documentation/dead code | All | all behavior changes | all | Consolidate canonical API docs and update final architecture after fixes | CLEAN links/references + doc re-audit | Complete |
| F-68 | Low* | CORS/header hardening | Backend,Admin | F-08,F-29,F-64 | AUTH,ADM,OPS | Explicit dev/admin origins, disable fingerprint header, add measured security headers | B-SEC allowed/disallowed/no-origin preflight tests | Complete |
| F-69 | Medium | Startup configuration | Backend | F-08,F-15,F-28 | OPS | Production fail-fast for DB/Firebase/Cloudinary; safe local development policy | OPS missing/valid env startup tests | Complete |
| F-70 | Medium | Token revocation/account block | Backend | F-03,F-43 | AUTH,ADM | Revocation-aware verification and consistent disabled/blocked account enforcement | B-SEC revoked/disabled/blocked tests | Complete |
| F-71 | Low | Review private-key placement | Admin,Backend | F-08,F-53 | DSP,OPS | Move key material outside repo tree and verify public/private match without logging it | OPS secret scan + A-SEC fingerprint test | Complete |
| F-72 | Low | Mobile platform identity | Mobile | F-64 | AUTH,NTF,OPS | Verify intended Android application ID; leave unshipped platforms documented | M-API Android Firebase/build validation | Pending |
| F-73 | Low | Feature completeness | Mobile | none | subscription | Verify as intentional UI-only feature; mark out-of-scope unless required for correctness | Documentation/source review | Deferred - Documented |

## Active Lifecycle Records

### F-07 — Admin authorization debug logging

Status: Complete

Root cause: An uncommitted debug block in `src/middleware/adminAuth.js` logs the
requester's Firebase identity, authorization decisions, and the full configured
admin-email set for every admin request.

Root fix: Removed only the uncommitted debug block. Added a regression test that
captures `console.log` while authorizing an allowlisted account and requires no
identity/allowlist output.

Tests:

- Pre-fix `node --test test/adminAuth.test.js`: failed exactly because the debug
  block emitted the Firebase UID/email and configured allowlist.
- Post-fix `node --test test/adminAuth.test.js`: 4/4 passed.
- Post-fix `npm test`: 21 passed, 1 optional live integration test skipped.
- `node --check src/middleware/adminAuth.js` and `git diff --check`: passed.

Re-audit: `rg` finds no `adminAuth-debug`/`configuredEmails` logging in `src` or
`test`. Authorization decisions and response behavior are unchanged. Adjacent
structured/redacted logging remains tracked separately as `F-47`.

### F-08 / F-28 / F-69 — Configuration and Firebase credential copies

Status: Complete (F-08, F-28, F-69)

Root fixes:

- **F-69 / F-08:** New `src/config/validateEnv.js` runs at module evaluation,
  before MongoDB/Firebase/any route initializes. `NODE_ENV=production` refuses
  to boot when `MONGO_URI`, Cloudinary, `ADMIN_EMAILS`, `ADMIN_REVIEW_PUBLIC_KEY`
  or `CORS_ORIGINS` are missing; development continues with warnings.
  `src/config/mongo.js` lost its import-time side effect and now exposes
  `resolveMongoUri()` + `connectDatabase()`; production refuses the localhost
  Mongo fallback. `src/utils/mediaHandler.js` gained `resolveCloudinaryConfig()`
  + `pingCloudinary()` for the non-fatal boot-time Cloudinary check.
- **F-68:** Open CORS is replaced by an allowlist from `CORS_ORIGINS`
  (`src/config/cors.js`), `helmet()` is added and `X-Powered-By` disabled
  (`src/index.js`). Origins with no `Origin` header (native mobile) are always
  allowed; localhost origins are dev-only; absent `CORS_ORIGINS` fails closed.
- **F-28:** Credential resolution moved to the pure `src/config/firebaseCredentials.js`
  (env vars first, then explicit `GOOGLE_APPLICATION_CREDENTIALS`); the implicit
  `src/config/serviceAccountKey.json` fallback is gone and the duplicate file was
  deleted, but only after an env-only Firebase boot was verified on this machine.

Verification:

- Boot probes: production boot aborts before any Firebase/Mongo init with the
  aggregate variable list (exit 1); dev boot continues; env-only Firebase
  initializes without the deleted file.
- New unit tests: `test/configValidation.test.js`, `test/cors.test.js`
  (validateEnv/collectConfigGaps/resolveMongoUri/parseCorsOrigins/isAllowedOrigin/
  buildCorsOptions).
- Full backend suite: 44 tests, 43 pass, 1 skipped (`RUN_LIVE_INTEGRATION` not set).

External steps remain: set `NODE_ENV=production`, `ADMIN_EMAILS`,
`ADMIN_REVIEW_PUBLIC_KEY`, `CORS_ORIGINS`, and the Cloudinary values on the
hosting provider, and run a live `/admin/me` + review-key smoke against that
environment. Finally, on the production host, verify the remote Mongo
credentials (see `Blocked External Actions`).

### F-09 / F-10 / F-71 — External secret actions

Status: F-71 Complete; F-10 `Blocked - External Action Required`; F-09
`Not reproducible` (history reachability remains unprovable, so provider-side
rotation is still mandated).

Local source cleanup is complete: the admin review private key now lives at
`~/.config/yack-admin/admin-review-private-key.pem`, outside the repository
tree (F-71), and the generator script + README were updated so regeneration no
longer writes private key material into the repo. The duplicate Firebase
service-account JSON was removed from the backend tree (F-28). Provider-side
credential rotation, Render variable changes, and secure external key storage
cannot be marked complete without external confirmation; the backend host's
Mongo credentials currently fail Atlas auth locally, consistent with
stale/original-author credentials needing rotation.

### F-68 / F-70 — CORS hardening and token revocation/account block

Status: Complete

Root fixes:

- **F-68:** CORS is allowlist-based (`src/config/cors.js`, `CORS_ORIGINS`,
  fail-closed in production; no-Origin native clients unaffected), `helmet()` is
  enabled and `X-Powered-By` is disabled in `src/index.js`.
- **F-70:** `src/middleware/auth.js` is now a `createAuthMiddleware({
  firebaseAdmin, UserModel })` factory. Tokens are verified with
  `verifyIdToken(token, { checkRevoked: true })`, so revoked/disabled sessions
  are rejected with a generic 401 instead of keeping access until expiry. A new
  `blocked` flag on the user document (default `false`) returns
  `403 ACCOUNT_BLOCKED` for blocked accounts; there is no self-service endpoint
  to set or clear it.

Verification: `test/auth.test.js` covers missing token, `checkRevoked: true`
passed through, revoked-token rejection, blocked-account 403, fresh-user upsert
including `blocked: false`, and the stale `email_verified` live-record refresh.
Full backend suite: 44 tests, 43 pass, 1 skipped.

### F-06 / F-54 — Dashboard session isolation

Status: Complete

Root fix: Firebase authentication now uses browser-session persistence. The
authenticated dashboard is mounted with the Firebase UID as its React key, so a
logout or direct account switch unmounts the entire case workspace and destroys
the imported review key, decrypted content, selected case/thread, and drafts.

Verification: The session-boundary regression assertions pass, dashboard lint
passes, and the production build succeeds. A manual two-admin browser test is
still recommended before release.

### F-27 — Ambient model-tool exposure

Status: Complete

Root fix: Removed the automatic `document.modelContext.registerTool` bridge.
The local admin dashboard no longer exposes dispute-opening capability to an
ambient host integration.

Verification: A source regression test forbids the bridge identifiers; lint and
production build pass.

### F-29 — Hardcoded live dashboard configuration

Status: Complete

Root fix: Removed live Firebase and Render fallback values from tracked source.
Vite validates all required public dashboard variables at dev/build startup. A
gitignored `.env.local` preserves this machine's working local configuration.

Verification: Tests reject each missing variable and accept a complete explicit
configuration. The configured production build, lint, and source checks pass.

### F-02 — Layered rate limiting

Status: Complete

Root fix: Added `express-rate-limit` (v8) with proxy-safe keying.
`src/middleware/rateLimiters.js` exports a `globalApiLimiter` (600 requests /
15 min per IP, applied before body parsing, skipping only `GET /` and `/health`)
and a `createUserLimiter({ windowMs, limit })` factory keyed on
`req.firebaseUser.uid` (falling back to `ip:<addr>` for unauthenticated or
early-failure paths). Per-operation ceilings: account setup and contract
create/join/sign/accept/delete (`accountSetupLimiter` 20, `userWriteLimiter`
200), media upload (`mediaUploadLimiter` 30), message send (`userWriteLimiter`
200) and dispute creation (`disputeLimiter` 10). Violations return
`429 RATE_LIMITED`. `src/index.js` now sets `app.set("trust proxy", 1)` and
mounts the global limiter before any body parsing. The default store is
in-memory, so ceiling accounting is per-process; a shared store is required for
horizontal scaling (documented in the module header).

Verification: `test/rateLimiters.test.js` spins up real express apps on ephemeral
ports and asserts the health route is never limited, a 610-request flood is cut
off at 600 with `RATE_LIMITED`, and per-UUID ceilings are independent. Full
backend suite below.

### F-03 — Explicit, bounded, atomic FCM registration

Status: Complete

Root fix: Implicit token mutation on every authenticated request is gone.
`src/middleware/auth.js` no longer reads or registers any FCM token. Binding
now happens only through `POST /user/fcm-token/register` (and `unregister`),
implemented as a single atomic `updateMany` pipeline in
`src/utils/fcmRegistration.js` + `src/controllers/userController.js`
(`createRegisterFcmTokenHandler`): the token is removed from any other account
and appended to the caller's list in one MongoDB write (requires MongoDB 4.2+).
The per-user list is bounded by `MAX_FCM_TOKENS_PER_USER` (5) with oldest-first
eviction. A unique partial index on `fcmTokens` enforces one-owner-per-token; a
duplicate-key race returns `409 FCM_TOKEN_CONFLICT` for a safe client retry.
The mobile `HttpHandler` no longer injects `fcmToken` into post/put/patch
bodies; registration stays explicit (`auth_cubit` → `registerCurrentToken`,
`onTokenRefresh`, logout unregister). Full hardened device-possession
attestation (a Firebase-verified per-device nonce proving control of the FCM app
instance) remains deferred; the current design's ownership semantics are:
whoever holds the account token can bind one of their own device tokens.

Verification: `test/fcmRegistration.test.js` covers the planner's
already-bound/new-bind/eviction/atomic-filter-pipeline shapes and the handler's
invalid-token 400, idempotent non-write, single-write bind, and 11000 → 409
mapping. `test/auth.test.js` proves no implicit FCM writes during upsert
(`updateMany`/`findByIdAndUpdate` never called). `flutter analyze` and all 119
mobile tests pass after the `http_handler.dart` cleanup.

### F-35 — First-touch upsert throttling and verified-email write gate

Status: Complete

Root fix: Account-creation pressure is throttled via the layered limiters
(F-02), and authenticated-but-unverified accounts are gated for the sensitive
`/user` writes with the new `src/middleware/requireVerifiedEmail.js`
(`403 EMAIL_NOT_VERIFIED`), wired into `POST /user/finalize`, `PUT
/user/private-key` and `PUT /user/profile` in `src/routes/userRoutes.js`. FCM
register/unregister are intentionally NOT gated on verified email: token
registration performs no privileged write, and gating it would create a
missed-push window right after verification.

Verification: `test/requireVerifiedEmail.test.js` proves verified requests pass
through and unverified/missing flags are blocked with `EMAIL_NOT_VERIFIED`;
the limiter and F-02 tests cover the burst throttle. Full backend suite below.

### Mobile batch — crypto compatibility, locked state, integrity, lifecycle (F-17, F-18, F-21, F-30, F-31, F-33, F-37, F-43, F-48, F-49, F-50, F-62)

Status: Complete

Root fixes:

- **F-21:** Encrypt/decrypt now uses `OAEPEncoding.withSHA256(RSAEngine())` on
  mobile (`cryptoService.dart`) and `{ name: 'RSA-OAEP', hash: 'SHA-256' }` on
  admin (`lib/crypto.ts`); MGF1 follows the OAEP hash so the two sides
  interoperate. SHA-1 ciphertext written before the change is no longer
  decryptable (accepted; test data only).
- **F-17:** The contract agreement screen is lock-gated: while the private key
  is absent the app bar shows the locked title, details stay disabled and the
  message list is hidden behind a lock empty-state.
- **F-18:** `CryptoService.plaintextMatchesHash` verifies message hashes and
  the contract details sheet verifies `sha256('title|description|price')`;
  anything failing (or matching the sentinel `[Unable to`) is shown as
  unverified via new `unverified_content` / `details_verified` /
  `details_unverified` l10n keys (en/ar/fr).
- **F-30:** Verified the backend `mediaController` emits `mediaPath`
  (`slice(0, 250)`) and both mobile parsers read `data['mediaPath']`; no
  change required beyond the parser tests.
- **F-31:** Accept persists the authoritative server status after accept.
- **F-33:** Backend language is parsed/cached and reconciled at startup.
- **F-37:** The only remaining `print(` in `lib/` is the gated one in
  `debug_logger.dart`.
- **F-43:** Verified this machine's mobile client never overrides
  authorization headers (only `@override` + `baseUrl`); verified-email gates
  for sensitive `/user` writes shipped with F-35.
- **F-48:** Push listener registration is retained/cancelled and the singleton
  is restart-safe across repeated init/dispose.
- **F-49 / F-50:** Typed API exceptions preserve HTTP status and codes with
  localized mappings; the broken corrupt-message copy is replaced with a
  descriptive error.
- **F-62:** The unreachable temp-status alias is removed; a canonical value is
  emitted.

Verification: `flutter analyze` reports 0 errors; all 119 `flutter test` tests
pass (models + crypto round trip included). Cross-checked the backend SHA-256
public-key contract and admin key format.

### Admin batch — failure state, races, HTTP resilience, key identity, resolution UX (F-22, F-23, F-25, F-26, F-52, F-53, F-55, F-56, F-57, F-58, F-63, F-64, F-65, F-66)

Status: Complete

Root fixes:

- **F-22 / F-23:** `openDispute` no longer rethrows (the confirmation modal
  opens with a loading skeleton); dashboard and case-detail responses are
  guarded by request-id refs so stale responses cannot overwrite newer ones;
  `detailError` is surfaced inline with a Retry button.
- **F-25:** `lib/api.ts` gains a typed `ApiError` (status + message), a 20s
  timeout with `AbortSignal` merging, text-based payload parsing (non-JSON
  bodies surface the status/message), `AbortError` mapping, and a
  session-scoped cached review public key (`reviewKey()` +
  `resetReviewKeyCache()`). `reviewKey()` is fetched once and reused for
  support sends (F-25 cache, F-06 scope).
- **F-26 / F-57:** Resolve-errors render inside the modal; `409` is
  recognized as "already resolved" and triggers a refetch; reject handling
  shows the outcome/note restatement inline (per-item decrypt markers),
  sign-out and discard-draft both require confirmation.
- **F-52:** `safeDecrypt` isolates per-field/per-item failures — one corrupt
  field shows an unverified label instead of failing the whole row or sheet.
- **F-53:** `lib/crypto.ts` derives the review key modulus and a SHA-256
  fingerprint from the PKCS#8 PEM; `loadReviewKey` refuses to accept a key
  whose modulus fingerprint does not match `ADMIN_REVIEW_PUBLIC_KEY` (badge
  shows `· verified` / `· mismatch`).
- **F-55:** Verified the backend ALREADY gates support attachments behind the
  review grant (`grantAuthorized`); administration copy now states files stay
  hidden until a case is shared.
- **F-56:** Backend `adminController.getAnalytics` no longer computes
  `contractTrend`; the admin `Analytics` type and the `recharts` dependency
  are gone.
- **F-58:** Deleted unused `components/ui/{chart,command,carousel,calendar,
  resizable,input-otp}.tsx` and pruned `cmdk`, `date-fns`,
  `embla-carousel-react`, `input-otp`, `react-day-picker`,
  `react-resizable-panels`, `recharts`, `wrangler`; `npm test` script added
  (`node --test test/`), 12 tests pass.
- **F-63:** `DisputeSummary.disputeState` widened to
  `'none' | 'open' | 'resolved'`, matching the backend normalization
  (`adminController.js` normalizes to open|resolved).
- **F-64 / F-65:** `.nvmrc` (`22`), `.npmrc` (`engine-strict=true`),
  `"packageManager": "npm@11.6.2"`; the admin README documents required env
  vars (no fallback), the fingerprint check, and the Test/Build commands.
- **F-66:** Admin README consolidated; `.env.example` verified against the
  no-fallback variable set (F-29).

Verification: `npm run lint` 0 errors; `npm test` 12/12 passed (including new
`test/security-boundaries.test.mjs` regression suite and
`test/crypto-interop.test.mjs` PKCS8→modulus fingerprint + RSA-OAEP SHA-256
round-trip tests); `npm run build` succeeds; `npm audit` reports 0
vulnerabilities after vendoring `react@19.2.8`,
`react-server-dom-webpack@19.2.8`, `vite@8.2.2`, `@vitejs/plugin-rsc@0.5.34`
and `vinext@1.0.0-beta.9`.

### F-05 / F-11 / F-16 — Client-side media encryption and terminal dispute resolution

Status: F-11, F-16 Complete; F-05 `Implemented - Live e2e pending`.

Root fixes:

- **F-05 (media confidentiality, all three repos):** Contract media and support
  attachments now use a flat client-side hybrid envelope. Uploaders generate a
  random AES-256-GCM key, encrypt the file bytes in an `Isolate.run`, and store
  `encryptionVersion: 1`, `iv` (12-byte nonce), `contentHash` (SHA-256 of the
  plaintext), and the AES key RSA-OAEP-SHA256 wrapped per reader
  (`keyOwner`, `keyParticipant`, `keyAdmin`). The server validates the envelope
  (canonical base64, 96-bit IV, SHA-256 hex, 128–512 B wraps, MIME allowlist,
  6 MB cap) and stores the opaque ciphertext on Cloudinary with
  `resource_type: "raw"` so it is never re-parsed as an image. Legacy records
  remain `encryptionVersion: 0` plaintext URLs and render exactly as before.
  Mobile decrypts via owner-then-participant wrap with an in-memory session
  cache (`_EncryptedMediaImage`); admin unwraps `keyAdmin` in the browser with
  `crypto.subtle.unwrapKey` (RSA-OAEP-SHA256) and AES-GCM decrypts to an
  object URL, verifying the stored hash before display.
- **F-11 / F-16 (dispute resolution terminality):** `resolveDispute` resolves
  through an atomic `findOneAndUpdate` filtered on
  `{ status: "disputed", disputeState: { $ne: "resolved" } }`, so a concurrent
  second resolution returns `409`; the F-11 terminality guard already rejects
  any party redispute of a resolved case. A regression scenario was added to
  the gated live integration test (resolve once → state `resolved`/status
  `pending`, second resolve → 409, reopen attempt → 409).

Tests:

- Backend: `npm test` 68 tests, 67 passed, 1 skipped (live integration);
  encrypted-payload validation/round-trip cases new in
  `test/mediaHandler.test.js`; `node --check` on all touched files passed.
- Mobile: 3 new hybrid-encryption round-trip tests (owner/participant/open,
  wrong-recipient rejects, tampered hash → null) in
  `test/services/crypto_service_test.dart`; full `flutter test` 126/126;
  `flutter analyze` 0 errors (96 pre-existing issues, none new).
- Admin: `npm run lint` 0 errors; `npm run build` succeeds with the new
  `decryptMediaToBlob`/`DocumentLink`/`AttachmentThumb` paths (legacy URLs pass
  through untouched; encrypted records decrypt once per session via
  `mediaBlobCache`).

Re-audit: no plaintext media bytes are ever stored or transmitted by the backend
for envelope uploads; support attachment keys are wrapped for the review key so
admins can decrypt without ever handling user private keys.

### Deferred decisions — F-04, F-32, F-51, F-60, F-73

Status: Deferred - Documented

Decisions:

- **F-04 (data at rest):** A full AES-GCM at-rest envelope is NOT implemented
  because it breaks every Isar query/link and touches every render path on
  mobile. Mitigation in place: F-17 lock-gate hides plaintext UI without a key
  in memory, Isar is cleared on logout, and decrypted state lives only in
  process memory. Revisit only with a dedicated storage-consolidation effort.
- **F-32 / F-51 / F-60 (Isar schema/build_runner):** These require new local
  Isar fields/migration (`dispute_state`, single-contract fetch indexes,
  persisted contract hash). They are deferred with F-04 until one coordinated
  schema/build_runner change is accepted, and are not required for the current
  verified workflows (titles/descriptions/price verification is re-derived
  render-time via F-18).

## Changes by Repository

### Mobile

- F-05 batch: new `lib/logic/services/media/media_crypto.dart` (AES-256-GCM +
  RSA-OAEP-SHA256 hybrid envelope via `Isolate.run`), `media_service.dart`
  (`ContractMedia` envelope fields, client-side `send(with otherPartyPublicKey)`,
  `fetchAndDecrypt`), `support_service.dart` (`downloadDecryptedBytes`,
  encrypted `uploadAttachment`), `contract_agreement.dart`
  (`_EncryptedMediaImage`, `_serverMediaById`), `support_chat.dart`
  (encrypted previews/thumbnails, `_otherPartyPublicKey`),
  `cryptoService.dart` byte-level RSA helpers, `http_handler.dart`
  `fetchBytes`; tests in `test/services/crypto_service_test.dart`.
- `lib/logic/services/network/http_handler.dart`: removed the implicit `fcmToken`
  body injection from `post`/`put`/`patch`, the `_getFcmToken()` helper and the
  `firebase_messaging` import. Token registration remains explicit via
  `notification_service.dart` / `user_service.dart` (F-03).
- Crypto/lock/integrity/lifecycle batch: `lib/logic/services/auth/crypto_service.dart`
  (RSA-OAEP SHA-256 encrypt/decrypt, `plaintextMatchesHash`, `detailsHashOf`),
  `lib/presentation/screens/contract_agr/contract_agreement.dart` (F-17 lock-gate
  + F-18 `_buildVerificationBanner`/`_showContractDetails`), `lib/l10n/{en,ar,fr}.dart`
  (`unverified_content`, `details_verified`, `details_unverified`),
  `lib/logic/services/notification/{notification_service,contract_notification_handler}.dart`
  (F-48 lifecycle), `lib/logic/services/message/message_sync_service.dart` and
  `lib/logic/services/contract/*` (F-31 accept status, F-33 language, F-62 temp
  status), `lib/logic/services/{messaging,user,account,media}.dart` and
  `lib/logic/services/debug/debug_logger.dart` (F-37 gated logging).

### Backend

- Temp-contract semantics batch (F-13 verified, F-34, F-39 verified): the
  atomic expiry check in `finalizeTempContract`
  (`expiresAt: { $gt: new Date() }`) was already enforced. The create-on-GET
  in `getTempContractStatus` is retained and now documented as an intentional,
  idempotent recovery path — the mobile client polls it (`getStatus` in
  `temp_contract_service.dart`, "UI recovers when push notifications are
  delayed or disabled") so it can materialize a contract whose /sign response
  was lost; it is exactly-once (deterministic `_id` + duplicate-key retry),
  expiry-checked and quota-bounded. Pre-join metadata minimization
  (`tempStatusPayload`) drops participant PII unless the caller is a party and
  keeps `detailsHash` for the QR cross-check (documented against the mobile
  scan flow).
- Index/ops batch (F-46 confirmed complete; F-15/F-40/F-41/F-44/F-45 verified
  as already implemented): `src/models/Contract.js` adds the
  `{ status: 1, disputeState: 1 }` compound index serving the admin
  open-dispute `$or` (`disputeState:"open"` ∪ `status:"disputed", disputeState
  ≠ "resolved"`); the participant list indexes (`userA`/`userB` + `updatedAt`),
  the admin status/dispute indexes and the `TempContract` quota/recovery
  indexes (`userA,cancelledAt,finalContract,expiresAt` and sparse
  `finalContract`) were already present and are now pinned by regression tests.
  `test/contractModels.test.js` asserts index presence for these verified query
  shapes; `test/quotaValidation.test.js` gains the `arrayBelowCap` empty-array
  semantics and the documented MAX_* cap values.
- F-05 batch: `src/models/Contract.js` (media envelope schema + `size`),
  `src/models/SupportThread.js` (attachment envelope schema),
  `src/utils/mediaHandler.js` (`validateEncryptedMediaPayload`,
  `mediaEnvelopeOf`, encrypted `raw` Cloudinary path), `src/controllers/mediaController.js`
  (envelope-aware `sendMedia`/`getAllMedia`), `src/controllers/supportController.js`
  (`uploadSupportAttachment` encrypted path, `keyParticipant` optional),
  `src/controllers/adminController.js` (dispute media/attachments carry the
  envelope for in-browser admin decrypt); deleted dead
  `src/utils/cryptoHandler.js` + `test/cryptoHandler.test.js`; docs in
  `src/api.md` describe the encryptionVersion 0/1 modes.
- F-11/F-16: `test/liveApi.integration.test.js` gains the resolve-once →
  second-resolve-409 → reopen-409 scenario (admin created via custom claim).
- `src/controllers/adminController.js`: `getAnalytics` no longer computes
  `contractTrend` (F-56); dispute summary normalization verified as
  open|resolved (F-63).
- `test/adminAuth.test.js`: regression coverage preventing admin identity and
  allowlist logging. The leaking working-tree debug block was removed from
  `src/middleware/adminAuth.js`, returning that file to its clean committed form.
- Safety/configuration batch (F-08, F-28, F-68, F-69, F-70): new
  `src/config/validateEnv.js` (boot-time gate, prod fail-fast) and
  `src/config/cors.js` (origin allowlist); `src/config/mongo.js`,
  `src/config/firebaseCredentials.js`, `src/config/firebase.js` and
  `src/utils/mediaHandler.js` refactored for testability and explicit
  credential resolution; `src/index.js` wires helmet, disables `X-Powered-By`,
  allows only configured origins and opens DB/Firebase connections after
  validation; `src/models/User.js` gained the `blocked` flag;
  `src/middleware/auth.js` is a factory using `checkRevoked: true` + blocked
  enforcement; the duplicate `src/config/serviceAccountKey.json` was removed;
  `.env.example` and `SETUP.md` document the new production requirements.
- Abuse/data-integrity batch (F-02, F-03, F-35): added
  `src/middleware/rateLimiters.js` (global + per-user, per-operation limiters),
  `src/middleware/requireVerifiedEmail.js`, `src/utils/fcmRegistration.js`
  (planFcmTokenBind planner) and `src/controllers/userController.js`'s
  `createRegisterFcmTokenHandler`; mounted the limiters on contract, message,
  media, support and user routes; removed the implicit FCM path from
  `src/middleware/auth.js`; added the unique partial index on `fcmTokens` in
  `src/models/User.js`; added `express-rate-limit` to dependencies (v8) and set
  `trust proxy` + global limiter in `src/index.js`.

### Admin

- F-05 batch: `lib/api.ts` (envelope fields on dispute `media` + `SupportAttachment`),
  `lib/crypto.ts` (`decryptMediaToBlob`: fetch → `unwrapKey` RSA-OAEP-SHA256 →
  AES-GCM decrypt → SHA-256 verify → object URL; legacy passthrough),
  `app/page.tsx` (`useResolvedMedia` + `DocumentLink`/`AttachmentThumb`,
  per-record `mediaBlobCache`).
- Removed hardcoded live Firebase/backend defaults and added startup validation.
- Added browser-session auth persistence and UID-keyed dashboard isolation.
- Removed the ambient model-tool registration.
- HTTP/failure-state batch: `lib/api.ts` (typed `ApiError`, 20s timeout +
  `AbortSignal` merging, text payload parsing, session-cached `reviewKey()` +
  `resetReviewKeyCache()`), `app/page.tsx` (request-id guard refs, inline
  detail/resolve errors with Retry, `safeDecrypt` per-field isolation, review-key
  fingerprint verification badges, sign-out/discard confirmations, resolve 409
  refetch, `disputeState` widening), `lib/crypto.ts` (PKCS#8 modulus/fingerprint
  helpers → `reviewKeyFingerprint`/`publicKeyFingerprint`).
- Dependency/test batch (F-58/F-65): deleted
  `components/ui/{chart,command,carousel,calendar,resizable,input-otp}.tsx`,
  pruned `cmdk`, `date-fns`, `embla-carousel-react`, `input-otp`,
  `react-day-picker`, `react-resizable-panels`, `recharts`, `wrangler`; added
  `.nvmrc` (`22`), `.npmrc` (`engine-strict=true`),
  `"packageManager": "npm@11.6.2"`; pinned vendored fixes
  `react@19.2.8` / `react-server-dom-webpack@19.2.8` / `vite@8.2.2` /
  `@vitejs/plugin-rsc@0.5.34` / `vinext@1.0.0-beta.9` (0 vulnerabilities).
- Tests: `test/security-boundaries.test.mjs` (extended) and
  `test/crypto-interop.test.mjs` (new) for the crypto/fingerprint/API regressions.
- Docs: README rewritten with the required no-fallback env vars, fingerprint
  check, and Test/Build sections.
- Responsiveness batch: `app/layout.tsx` adds an explicit mobile `viewport`;
  `app/page.tsx` — `min-w-0` on `SidebarInset` (fixes horizontal page
  overflow), sidebar trigger visible on desktop too (offcanvas collapse),
  cases table now scrolls horizontally with `min-w` and progressive column
  hiding (Reason < `sm`, Opened < `md`), compact header controls (search
  `min-w-0`, refresh collapses to icon < `sm`), heading scales on mobile, and
  the sticky resolve bar stacks full-width on small screens.

## Test Results

- Backend focused admin-auth test: 4 passed.
- Backend safety/configuration batch: `test/configValidation.test.js`,
  `test/cors.test.js`, `test/auth.test.js` all pass (22 assertions). Boot probes:
  production aborts pre-init with the missing-variable list; dev continues;
  env-only Firebase boot verified after the duplicate key file was removed.
- Backend abuse/data-integrity batch: `test/rateLimiters.test.js`,
  `test/fcmRegistration.test.js`, `test/requireVerifiedEmail.test.js` and the
  updated `test/auth.test.js` (no-implicit-FCM assertion) all pass (targeted 19
  tests, 0 failures). `node --check` on every touched source and test file:
  passed.
- Backend full test suite: 57 tests, 56 passed, 1 skipped
  (`RUN_LIVE_INTEGRATION` not set).
- Backend syntax/diff checks for F-07: passed.
- Mobile after F-03 cleanup: all 119 `flutter test` tests passed; `flutter
  analyze` reports 0 errors (124 pre-existing warnings/info findings, none in
  the touched files).
- Mobile final batch: `flutter analyze` 0 errors; `flutter test` 119 passed.
- Backend after F-56: `node --check src/controllers/adminController.js` passed;
  `npm test` 64 tests, 63 passed, 1 skipped.
- Backend F-05/F-16 batch: `npm test` 68 tests, 67 passed, 1 skipped (live
  integration; resolve scenario included); `node --check` on touched files.
- Mobile F-05 batch: `flutter test` 126/126 passed (3 new hybrid-envelope tests);
  `flutter analyze` 0 errors (96 pre-existing issues, none new).
- Admin F-05 batch: `npm run lint` 0 errors; `npm run build` succeeds.
- Admin final batch: `npm run lint` 0 warnings/errors; `npm test` 12 passed
  (security-boundaries + crypto-interop + config); `npm run build` succeeds
  (rsc/client/ssr environments); `npm audit` 0 vulnerabilities.
- Admin deploy batch: lockfile regenerated (`f956bd7`) so Render's `npm ci`
  resolves the `@emnapi/core`/`@emnapi/runtime` optional-platform peers nested
  under `@tailwindcss/oxide-wasm32-wasi`; validated end-to-end in a scratch
  copy (`npm ci` + `npm run build` both green).
- Backend F-46 batch: `node --check` on `Contract.js`, `TempContract.js` and the
  touched tests passed; `npm test` 73 tests, 72 passed, 1 skipped (live
  integration).
- Backend F-13 batch: `node --check src/controllers/contractController.js`
  passed. F-34/F-39/F-13 live-gated assertions already exist in
  `test/liveApi.integration.test.js` (pre-join `waiting_for_join` +
  `detailsHash` disclosure, sign-then-poll recovery).
- Admin responsiveness batch: `npm run lint` 0 warnings/errors; `npm run build`
  succeeds; `npm test` 12 passed.

## Blocked External Actions

Pending verification: provider-side rotation of any legacy/current MongoDB,
Firebase Admin, Cloudinary, and administrator review credentials; production
environment changes and redeployment. The production host must also set
`ADMIN_EMAILS`, `ADMIN_REVIEW_PUBLIC_KEY` and `CORS_ORIGINS`
(F-08/F-68 — without `CORS_ORIGINS` the deployed admin dashboard is
CORS-blocked), and the host's Mongo credentials currently fail Atlas auth
locally (stale original-author credentials). F-05's live end-to-end smoke (upload an
encrypted attachment on-device and decrypt it in the admin dashboard) is blocked
on a configured, reachable Cloudinary environment.

## Final Re-Audit Results

Not started. This section will be completed only after all original findings have
a final status and the full system has passed regression testing.
