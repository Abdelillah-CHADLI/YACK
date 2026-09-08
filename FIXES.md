# Full System Audit Report

Three-repository forensic audit of the YACK system, reconstructed end-to-end from working code:

- **YACK** (Flutter mobile app, branch `develop`) — `C:\Users\moham\Desktop\Projects\YACK`
- **YACK-Backend** (Node/Express + Mongoose, branch `main`) — `C:\Users\moham\Desktop\Projects\YACK-Backend`
- **YACK-Admin** (React/Vite admin panel, branch `master`) — `C:\Users\moham\Desktop\Projects\YACK-Admin`

Investigation-only. No source code was changed to produce this report. Every finding below carries direct code evidence (repo, file, line, function/endpoint). Items that could not be fully confirmed from the checked-out code are explicitly marked `Needs verification`.

## Executive Summary

The system is a functional end-to-end encrypted contract-signing and dispute-resolution platform connecting two mobile parties through a central Node API, with Firebase as the identity/FCM provider, MongoDB as the store, and Cloudinary as media storage. A React admin panel reviews disputes and supports parties with a browser-held review key. The overall architecture is coherent, all 37 frontend API calls map 1:1 to implemented backend routes, authorization is server-side across the board (no frontend-only authorization on protected content), and the state machine uses atomic conditional updates that survive concurrency analysis (accept/dispute/finalize converge).

The highest-risk problems are clustered in four areas:

1. **Denial-of-service and abuse primitives on the backend.** Embedded contract/support arrays grow without a ceiling (a single participant can push a contract document past MongoDB's 16 MB limit, permanently corrupting it for *both* parties). There is no rate limiting anywhere, no per-user quota, and FCM token registration trusts any string a caller supplies — enabling token hijacking (notification interception) and spam.
2. **Data-at-rest protection gaps that contradict the product's "encrypted" positioning.** The mobile app stores plaintext contracts/messages in Isar; contract media and support attachments are stored unencrypted on Cloudinary behind permanent public URLs while a complete media-encryption implementation sits unused; the admin panel keeps decrypted case material and the review key across sign-out.
3. **Configuration and secret hygiene.** `ADMIN_EMAILS` and `ADMIN_REVIEW_PUBLIC_KEY` are unset in the working `.env` (admin gate degrades to custom-claim-only and the review-key endpoint returns 503), real credentials live on disk in backend `.env` and `src/config/serviceAccountKey.json`, and the admin app hardcodes production Firebase/API fallbacks. A leftover debug log dumps the entire admin allowlist plus per-request identity to stdout.
4. **Observability and production hardening.** No graceful shutdown, no request timeouts, a constant health endpoint, no structured logging or admin audit stream, and the Mongo connection is not awaited before listen.

Integration problems are medium/low: several backend fields are silently dropped by the client models (`language`, dispute specifics, `hash`), the accept flow hardcodes a local status instead of using the server response, media push payloads emit a `mediaId` key the client parser never reads, and the RSA-OAEP hash is implicit SHA-1 on clients while the (dead) backend helper assumes SHA-256 — a latent interop trap.

Maintainability carries real debt: two storage engines (Hive + Isar) overlap in the mobile app, `pubspec.lock` is gitignored, several packages are declared but unused (three Cloudinary Flutter packages, `firebase_database`), the admin app ships a pre-release framework (`vinext@beta`) plus a large set of unimported UI wrappers with no test script, and the backend test suite covers none of the authorization/dispute/concurrency surface that this report flags.

## Priority Classification

| ID | Severity | Category | Title | Source IDs |
|----|----------|----------|-------|------------|
| F-01 | High | Database / Abuse | Unbounded embedded arrays can exceed MongoDB 16 MB document limit | BD F-02, MB F-13, SEC S-09 |
| F-02 | High | Security / Abuse | No rate limiting or DoS controls anywhere on the API | BD F-03, SEC S-07 |
| F-03 | High | Security | FCM token registration without ownership proof (push hijack) plus non-atomic move | BD F-01/F-04/F-05, INT I-14, SEC S-11/S-12 |
| F-04 | High | Mobile / Security | Contracts and messages stored DECRYPTED at rest in Isar | MB F-01 |
| F-05 | High | Mobile / Security | Contract media and support attachments unencrypted on Cloudinary; media-encryption code dead | MB F-02 |
| F-06 | High | Admin / Authz | Decrypted review material and review key survive sign-out / account switch | ADM F-01 |
| F-07 | High | Security / Config | `adminAuth` debug logging leaks admin allowlist and per-request PII | BD F-07, MB F-14, ADM F-11, SEC S-22 |
| F-08 | High | Config | Admin env not validated at startup; `ADMIN_EMAILS` and `ADMIN_REVIEW_PUBLIC_KEY` unset | BD F-08, INT I-09, SEC S-19 |
| F-09 | High* | Secrets | Legacy Firebase service-account key possibly present in git history | SEC S-01 (*Needs verification) |
| F-10 | High | Secrets | Real production credentials in backend `.env` on disk (untracked) | SEC S-02 |
| F-11 | Medium | Concurrency | Reopening a dispute after resolution destroys the resolution audit trail | BD F-09 |
| F-12 | Medium | Security | Dispute reason transmitted/stored/returned in plaintext | BD F-10 |
| F-13 | Medium | Backend | GET endpoints perform writes; finalization can outlive invitation TTL | BD F-12 |
| F-14 | Medium | Backend | No pagination on `/contracts/list`, `/media/all`; hidden cap on `/admin/disputes` | BD F-11, ADM F-07 |
| F-15 | Medium | Backend | No graceful shutdown, request timeouts, or real health endpoint; Mongo connect not awaited | BD F-17, SEC S-17/S-18 |
| F-16 | Medium | Testing | Tests miss the entire authorization/dispute/concurrency surface | BD F-22 |
| F-17 | Medium | Mobile / Security | "Locked account" state still renders previously synced decrypted data | MB F-03 |
| F-18 | Medium | Mobile / Security | Message `contentHash` and grant `detailsHash` never verified (client or server) | MB F-05, ADM F-03 |
| F-19 | Medium | Mobile / Performance | Argon2id (64 MB/3-pass) and RSA keygen run synchronously on the UI isolate | MB F-06 |
| F-20 | Medium | Mobile / Performance | Serial per-message RSA decryption on the UI isolate, re-run on every open and after each send | MB F-07 |
| F-21 | Medium | Mobile / Security | RSA-OAEP uses SHA-1 on clients; backend crypto helper uses SHA-256 (latent mismatch) | MB F-04, ADM F-02 |
| F-22 | Medium | Admin / State Mgt | Unhandled promise rejection on dispute-open failure; sheet opens before data arrives | ADM F-05 |
| F-23 | Medium | Admin / State Mgt | Out-of-order responses race without abort or deduplication | ADM F-06 |
| F-24 | Medium | Admin / UI-UX | "Support" view is a duplicate of "Disputes" with a mismatched badge count | ADM F-08 |
| F-25 | Medium | Admin / Integration | `request()` swallows non-JSON/empty errors; no timeout; review key fetched on every send | ADM F-09 |
| F-26 | Medium | Admin / UI-UX | Failed "Resolve dispute" is invisible behind the modal | ADM F-14 |
| F-27 | Medium | Admin / Security | In-browser model tool auto-registered without explicit operator consent | ADM F-04 |
| F-28 | Medium | Secrets | Firebase Admin service-account JSON duplicated inside backend source tree | SEC S-03 |
| F-29 | Medium | Config | Hardcoded production Firebase/API fallbacks in admin client | ADM F-13, INT I-08, SEC S-04 |
| F-30 | Medium | Integration | FCM media notification payload uses `mediaId`, client parser reads `mediaPath` | INT I-01 |
| F-31 | Medium | Integration | Mobile accept flow ignores server `status`, hardcodes local `accepted` | INT I-02 |
| F-32 | Medium | Integration | Flutter drops dispute specifics (reasons, timestamps, disputeState) on sync | INT I-03 |
| F-33 | Medium | Integration | `language` written by backend but never read by Flutter profile model | INT I-05 |
| F-34 | Medium | Integration | Temp-contract status poll requires an active (finalized) account | INT I-11 |
| F-35 | Medium | Abuse | Mass account creation — backend auto-upserts users with no creation throttle | SEC S-08 |
| F-36 | Medium | Abuse | No per-user quota on contracts, uploads, or Cloudinary storage; notification spam | SEC S-10/S-12 |
| F-37 | Medium | Code Quality | Mobile ships unconditional `print(...)` debug statements in production paths | SEC S-24 |
| F-38 | Medium | Dependencies | Hive + Isar storage overlap; `pubspec.lock` ignored; test libs in prod deps | SEC S-30, MB F-11 |
| F-39 | Low | Security | Pre-join temp status leaks final-version `detailsHash` and participant names | BD F-23, SEC S-13 |
| F-40 | Low | Validation | `verifyContract` hash comparison lacks normalization and is not constant-time | BD F-13 |
| F-41 | Low | Validation | Contract encrypted fields not validated as ciphertext (drift vs message validation) | BD F-14 |
| F-42 | Low | Security | Upload MIME type inferred from filename extension only (MIME spoofing) | BD F-19 |
| F-43 | Low | Abuse | Unverified/incomplete accounts can exercise all `/user/*` endpoints | SEC S-14 |
| F-44 | Low | Concurrency | Support attachment count cap is racy | BD F-15 |
| F-45 | Low | Concurrency | Concurrent `ensureSupportThread` upserts can throw E11000 → 500 | BD F-16 |
| F-46 | Low | Database | Missing indexes for query patterns actually used | BD F-21 |
| F-47 | Low | Backend | Unstructured logging; no admin action audit stream | BD F-18, SEC S-23 |
| F-48 | Low | Mobile | Push listeners registered without retaining subscriptions; `dispose()` kills singleton | MB F-08 |
| F-49 | Low | Mobile | Backend structured error codes discarded by client | MB F-09 |
| F-50 | Low | Mobile | Corrupted error string `'S mpID field.'` | MB F-10 |
| F-51 | Low | Mobile / Perf | Local indexing/rendering inefficiencies (O(n²) media dedup, search rebuild per keystroke) | MB F-12 |
| F-52 | Low | Admin / Crypto | All-or-nothing decryption: one malformed ciphertext blocks an entire case | ADM F-16 |
| F-53 | Low | Admin | Review-key import accepts any PKCS8 file with no identity/fingerprint check | ADM F-20 |
| F-54 | Low | Admin / Auth | Firebase auth uses default local persistence; no per-tab isolation | ADM F-19 |
| F-55 | Low | Admin / Security | Support-thread attachments disclosed before review access granted | ADM F-18 |
| F-56 | Low | Admin | Analytics `contractTrend` fetched but never rendered; `recharts` unused | ADM F-10 |
| F-57 | Low | Admin | No confirmation for sign-out, silent review-key swap, no unsaved-draft guard | ADM F-15 |
| F-58 | Low | Admin / Dependencies | Unused/heavy dependencies and UI wrappers shipped; no test script | ADM F-17 |
| F-59 | Low | Integration | `GET /media/get` implemented but never invoked by mobile UI | INT I-06 |
| F-60 | Low | Integration | Contract `hash` parsed but never persisted to Isar | INT I-04 |
| F-61 | Low | Config | Backend `PORT` defaults to 80 vs Flutter dev defaults to port 3000 | INT I-10 |
| F-62 | Low | Integration | Temp status string `"finalized"` never emitted by backend | INT I-12 |
| F-63 | Low | Integration | Admin `DisputeSummary.disputeState` type narrower than backend enum | INT I-13 |
| F-64 | Low | Config | No committed deploy manifests; admin default API URL mismatches backend docs | SEC S-20 |
| F-65 | Low | Config | Admin Node engine floor `>=22.13.0` with pre-release toolchain, no pin | SEC S-21 |
| F-66 | Low | Code Quality | Documentation drift; duplicated API docs across repos | SEC S-27 |

---

## Critical Issues

No finding meets the WORK.md "Critical" bar (unauthed full compromise, credential exposure via tracked files, or irreversible corruption that is *currently* occurring). The two closest candidates are tracked as High with explicit evidence intervals: F-01 (permanent, unrecoverable contract corruption is *reachable* today but requires an abusive participant) and F-10/F-09 (real credentials exist on disk / may exist in history but are not committed). The genuinely time-boxed issue blocking the current deployment is F-08 (admin dashboard non-functional until `ADMIN_REVIEW_PUBLIC_KEY` is set).

---

## High — Security

### F-01 Unbounded embedded arrays can permanently corrupt contracts (16 MB BSON limit)

**Severity:** High
**Category:** Database / Abuse
**Affected repositories:**
- YACK-Backend
**Location:**
- `src/models/Contract.js:108-109` — `messages: [EmbeddedMessageSchema]`, `media: [EmbeddedMediaSchema]`
- `src/models/SupportThread.js:51-52` — `messages`, `attachments` embedded arrays
- `src/controllers/messageController.js:27-34` — `$push` with no count guard
- `src/controllers/mediaController.js:38-45` — `$push` with no count guard
- `src/controllers/supportController.js:210-214` — support message `$push` uncapped
**Problem:** Messages and media are appended to the contract document with no ceiling. Reads are `$slice`-capped (max 100), but writes are not. Messages are up to 4096 chars each for sender and recipient plus hash (~8.5 KB/message), so roughly ~1,900 messages exceed MongoDB's 16 MB single-document limit. Once a document exceeds it, *every* write fails — send message, upload media, accept, dispute, and admin resolution — for both parties.
**Evidence:**
```js
// messageController.js:27-33
const updated = await Contract.findOneAndUpdate(
    { _id: req.contract._id, $or: [{ userA: req.userDoc._id }, { userB: req.userDoc._id }] },
    { $push: { messages: entry } }, ...
```
**Impact:** Permanent, cheap, single-participant DoS against a specific agreement; data effectively frozen and requires a migration to repair.
**Reproduction / Failure Scenario:** Party A sends 2,000 messages (scripted or legitimate abuse) to an active contract; the document passes 16 MB; every subsequent operation returns a document-too-large error.
**Recommended Fix:** Enforce a hard per-contract cap inside the atomic update (e.g., `$expr: { $lt: [{ $size: "$messages" }, 500] }` or a counter field) and reject overflow; or move messages/media into separate capped collections. Apply the same guard to `SupportThread.messages`.
**Related Issues:** F-36, F-44.

### F-02 No rate limiting or DoS controls anywhere on the API

**Severity:** High
**Category:** Security / Abuse
**Affected repositories:**
- YACK-Backend
**Location:**
- `src/index.js:20-35` — only `cors()`, `express.json({limit:"10mb"})`, `express.urlencoded({limit:"10mb"})`
- `src/middleware/auth.js:41` — `verifyIdToken` runs per request
**Problem:** No `express-rate-limit`/equivalent, no per-IP or per-user throttle, no connection-pool cap. Every mutation route (`/contracts/*`, `/messages/*`, `/media/*`, `/support/*`, `/user/*`, `/admin/*`) is unbounded; each also runs an expensive Firebase token verification plus (F-03) FCM registration writes.
**Evidence:** Grep for `rateLimit|helmet` in `src/` returns nothing; `package.json:23-30` has no rate-limit dependency. Cross-validated: `src/index.js:20` `app.use(cors())` is the only relevant global middleware.
**Impact:** API flooding, DB/Cloudinary/FCM spend, brute-force token probing, and it amplifies F-01 (array flooding) and F-36 (no quotas).
**Reproduction / Failure Scenario:** An attacker floods `POST /contracts/create` and `POST /messages/send` with valid Firebase tokens; CPU/IO exhaustion and storage burn.
**Recommended Fix:** Per-user and per-IP limits, stricter on create/join/sign/dispute/upload; allowlist health checks; consider `helmet` and disabling `x-powered-by` alongside F-68 (CORS).
**Related Issues:** F-35, F-36.

### F-03 FCM token registration without ownership proof (push hijack) plus non-atomic move

**Severity:** High
**Category:** Security
**Affected repositories:**
- YACK-Backend
**Location:**
- `src/middleware/auth.js:76-77` — reads `x-fcm-token` header or `body.fcmToken` on **every** request and re-registers
- `src/middleware/auth.js:11-32` (`registerDeviceToken`) — awaits `updateMany` pull then `findByIdAndUpdate` add, with `User.fcmTokens` unindexed (`src/models/User.js:19`)
- `src/controllers/userController.js:216-236` (`registerFcmToken`) — same pull-then-add pattern
- `src/utils/fcmToken.js:1-6` — only format check (length 20-4096, no whitespace); no ownership attestation
- Flutter `lib/logic/services/network/http_handler.dart:79-95,106-123` — sends token in body of every POST/PUT
**Problem:** A Firebase/FCM device token is an opaque string with no binding to the user it belongs to. Any authenticated user who learns another account's token can register it on their own account; the backend *removes it from the victim's account first* and attaches it to the attacker. All push notifications for the victim's contracts (joined/signed/accepted/disputed, new message/media — including dispute reason text, F-12) now route to the attacker. Registration also happens implicitly on any request carrying the token, and the remove-then-add is not atomic (two concurrent registrations can leave the token on both accounts or drop it).
**Evidence:**
```js
// auth.js:18-26
await User.updateMany({ _id: { $ne: user._id }, fcmTokens: fcmToken }, { $pull: { fcmTokens: fcmToken } });
return await User.findByIdAndUpdate(user._id, { $addToSet: { fcmTokens: fcmToken } }, { new: true }) || user;
```
**Impact:** Notification interception and suppression; privacy breach (dispute reasons, identity data); erasure of the victim's legitimate pushes. This is a live, reachable vector.
**Reproduction / Failure Scenario:** Attacker obtains victim's token (log, shared device, sniffing) and adds it to a POST body while authenticated; the victim stops receiving pushes and the attacker starts receiving them.
**Recommended Fix:** Prove possession (Firebase-verified device nonce or a received-registration receipt) before binding; require an explicit register endpoint instead of implicit body-token registration; make remove+add a single atomic pipeline update; add a unique/partial index on `fcmTokens`; cap tokens per user.
**Related Issues:** F-01 (indexing), F-36, F-12.

### F-04 Contracts and messages stored DECRYPTED at rest in Isar

**Severity:** High
**Category:** Mobile / Security
**Affected repositories:**
- YACK (Flutter)
**Location:**
- `lib/logic/services/contract/contract_sync_service.dart:9` — doc comment: "Contracts are stored DECRYPTED in Isar for easy display."
- `lib/logic/services/contract/contract_sync_service.dart:84-119,144-147` — decrypts then persists plaintext `title/description/price`
- `lib/logic/services/message/message_sync_service.dart:7,95-118` — stores `decryptedContent`
- `lib/presentation/screens/contract_agr/contract_agreement.dart:224-244` — decrypts messages inline into Isar
- `lib/data/repositories/isar_adapter.dart:68-92,328-342` — writes plaintext fields
- Cleared only at explicit logout: `isar_adapter.dart:509-515`
**Problem:** The RSA envelopes protect transit and the *server-stored* ciphertext copies, but the copy the user actually views is plaintext on disk in Isar, surviving restarts and device backups. The encryption password and screen lock protect nothing at rest.
**Impact:** Any backup, forensic copy, or compromised/rooted device reveals full contract text, prices, dispute reasons, and message history — contradicting the app's "encrypted" positioning and the `attachment_privacy_note` copy.
**Recommended Fix:** Persist only ciphertext envelopes and keep plaintext solely in the in-memory `DecryptedKeyCache`; or encrypt the Isar payload with a key derived after account unlock; clear the cache on background/restart when locked.
**Related Issues:** F-17.

### F-05 Contract media and support attachments unencrypted on Cloudinary; media-encryption code is dead

**Severity:** High
**Category:** Mobile / Security
**Affected repositories:**
- YACK-Backend
- YACK (Flutter)
**Location:**
- Backend `src/controllers/mediaController.js:18-95` (`sendMedia`) — stores `{ content: stored.path, url: stored.url }` (Cloudinary public_id + secure_url)
- Backend `src/utils/mediaHandler.js:117-132` — `send()` uploads raw base64, returns permanent `secure_url`
- Backend `src/utils/cryptoHandler.js` — `encryptMedia/decryptMedia/encryptWithRSA/decryptWithRSA/convertPublicKeyToPEM` (AES-256-GCM + RSA-OAEP sha256); grep confirms **no** import anywhere in `src/` (cross-validated)
- Support attachments use the same plaintext path: `src/controllers/supportController.js:241`
- Client displays public URL directly: `lib/presentation/screens/contract_agr/contract_agreement.dart:1016` (`Image.network(media.url)`); upload is plaintext base64: `lib/logic/services/media/media_service.dart:121-122`
**Problem:** Contract evidence (photos, invoices, PDFs, videos) and support attachments are stored at-rest plaintext on a third-party CDN behind permanent, public, unexpiring URLs. A complete media-encryption implementation exists but is never wired in.
**Impact:** Anyone who obtains a media URL (shared, logged, guessed) can download uncrypted contract evidence with no expiry and no access control.
**Recommended Fix:** Wire media through client-side encryption before upload, or use Cloudinary access-controlled delivery with short-lived signed URLs; then remove the dead `cryptoHandler.js`.
**Related Issues:** F-21, F-01.

### F-06 Decrypted review material and review key survive sign-out / account switch

**Severity:** High
**Category:** Admin / Authz
**Affected repositories:**
- YACK-Admin
**Location:**
- `app/page.tsx:371-381` — `onAuthStateChanged` sign-out branch clears only `adminEmail` and `analytics`
- `app/page.tsx:395-402` (`openDispute`) — transparently decrypts with the retained `reviewKey`
- `app/page.tsx:460-481` (`loadReviewKey`), `:515-537` (`resolveCase`)
- The `Home` component stays mounted across sign-out (renders `<LoginScreen/>` at `page.tsx:570`), so state persists
**Problem:** `reviewKey`, `reviewKeyName`, `decrypted`, `decryptedSupport`, `detail`, `detailOpen`, `selectedThreadId`, `supportDraft` are never reset on sign-out or account switch. The README security guarantee ("review key remains in this browser tab's memory only", README.md:26-28) is scoped to a single operator session — instead the key and pre-decrypted case material leak across sessions and across operators on a shared tab, and the next admin silently decrypts new cases with the previous admin's private key.
**Impact:** Cross-session / cross-operator exposure of decrypted dispute and support content; defeats the in-memory-only security model on shared workstations.
**Reproduction / Failure Scenario:** Admin A imports a private key and opens a case, signs out; Admin B signs in on the same tab and opens a new case, which decrypts under A's still-held key.
**Recommended Fix:** On both sign-out paths, reset `reviewKey`, `reviewKeyName`, `decrypted`, `decryptedSupport`, `detail`, `detailOpen`, `selectedThreadId`, `supportDraft`, `error`; await `signOut(auth)`.
**Related Issues:** F-54, F-53.

### F-07 `adminAuth` debug logging leaks admin allowlist and per-request PII

**Severity:** High
**Category:** Security / Config
**Affected repositories:**
- YACK-Backend (uncommitted working-tree change)
**Location:**
- `src/middleware/adminAuth.js:16-27` (confirmed via `git diff`; the committed version at HEAD lacks it)
```js
console.log("[adminAuth-debug]", JSON.stringify({
    firebaseUser: req.firebaseUser ? { uid, email, admin, role } : null,
    emailVerified, hasAdminClaim, isAllowlisted,
    configuredEmails: Array.from(configuredAdminEmails()),
}));
```
**Problem:** Every `/admin/*` request writes the requester's Firebase UID/email/claims and the entire `ADMIN_EMAILS` allowlist to stdout. In aggregated logs this exposes exact admin identities and the gate policy.
**Impact:** PII exposure in logs; reconnaissance for targeted phishing; disclosure of which emails are admins and whether claims are used.
**Recommended Fix:** Remove the debug block before deploy; if audit logging is desired, log only `uid` + allowed/denied boolean without emails.
**Related Issues:** None.

### F-08 Admin environment not validated at startup; `ADMIN_EMAILS` and `ADMIN_REVIEW_PUBLIC_KEY` unset

**Severity:** High (`Needs verification` for the production host; confirmed for the working `.env`)
**Category:** Config
**Affected repositories:**
- YACK-Backend
**Location:**
- `.env` (working tree): `ADMIN_EMAILS` and `ADMIN_REVIEW_PUBLIC_KEY` not set (cross-validated; `MONGO_URI`/`CLOUDINARY_API_KEY` are set)
- `src/middleware/adminAuth.js:10-14` — admin access granted by allowlist OR Firebase custom claim; with the allowlist empty, the *only* thing granting `/admin/*` is a custom claim
- `src/controllers/supportController.js:71-77` — `GET /support/review-key` returns 503 `REVIEW_KEY_UNAVAILABLE` when the public key is unset
- `src/index.js` performs no startup validation of these values
**Problem:** Without `ADMIN_EMAILS` the allowlist check is dead code and a stale Firebase custom claim (`admin:true`/`role:"admin"`) silently grants permanent admin access with no revocation control besides token expiry. Without `ADMIN_REVIEW_PUBLIC_KEY`, both the mobile app and YACK-Admin cannot obtain the review key — the admin's whole review flow degrades. Nothing fails at boot to signal this.
**Impact:** Admin dashboard unusable (or, worse, silently privileged via stale claims); the review-key 503 blocks share/send and admin decryption; misconfigurations appear "healthy."
**Recommended Fix:** Fail-fast at startup when `ADMIN_EMAILS` is missing; require allowlisted email AND explicit claim; set `ADMIN_EMAILS` and `ADMIN_REVIEW_PUBLIC_KEY` in the deployment env (`Needs verification`: confirm values on the deployed host); add both to `.env`.
**Related Issues:** F-38 (localhost Mongo fallback), F-29.

### F-09 Legacy Firebase service-account key possibly present in git history

**Severity:** High — `Needs verification` (not confirmable from reachable history)
**Category:** Secrets
**Affected repositories:**
- YACK-Backend
**Location:**
- Claimed by `SETUP.md:148`: "The original Firebase service-account key was previously committed to git history."
- Commit `cb52c1b` "chore(security): Stop tracking the Firebase service account key" — its diff only touches `.gitignore` (3 insertions), the file itself never appears in the diff
- `git log --all -S "-----BEGIN PRIVATE KEY-----"` yields only placeholder strings; `git rev-list --all -- src/config/serviceAccountKey.json` is empty
**Problem:** A real Admin-SDK service-account key in history grants full Firebase Admin access (Auth, Messaging, DB) to anyone who obtains it and cannot be un-committed, only rotated. The evidence is internally inconsistent: the claim exists, but the actual key blob was **not** found in reachable history.
**Impact:** If the key ever landed in a shared remote/fork (note upstream fork `generalBenmalek/yack-backend`), an attacker can mint admin tokens and send arbitrary FCM pushes.
**Recommended Fix:** Treat as "rotate defensively" — revoke the legacy service account in the Firebase console; ensure only the current `yack-aeb34` key is active; if the upstream fork holds the blob, force-rewrite with `git filter-repo`.
**Related Issues:** F-10, F-28.

### F-10 Real production credentials in backend `.env` on disk (untracked)

**Severity:** High
**Category:** Secrets
**Affected repositories:**
- YACK-Backend (operational, not committed)
**Location:**
- `.env` — live `MONGO_URI` (Atlas user belonging to the original author, masked), `FIREBASE_CLIENT_EMAIL`/`FIREBASE_PRIVATE_KEY` (`firebase-adminsdk` for project `yack-aeb34`), `CLOUDINARY_API_KEY`/`CLOUDINARY_API_SECRET`
- `.gitignore` excludes `.env`; `git ls-files` shows only `.env.example` tracked — this is **not** a git leak
**Problem:** The Atlas DB username belongs to the original author even though `SETUP.md:11-12` states credentials were rewired to new owner accounts — these may be previous owner's live credentials still in use. Any machine compromise/stray backup exposes full DB + Firebase Admin + Cloudinary access.
**Impact:** Full backend credential exposure if the file leaks; unchanged-owner credentials across ownership transitions.
**Recommended Fix:** Rotate the Atlas user password, Cloudinary API key/secret, and (if any doubt) the Firebase SA key to current-owner credentials; keep `.env` out of backups/cloud sync; add a secrets scanner pre-commit hook.
**Related Issues:** F-09, F-28.
**Note:** Secret values deliberately masked in this report per the audit brief.

---

## High — Authentication and Authorization

(No additional findings beyond F-03/F-06/F-08. The authorization architecture itself is sound: all contract-scoped routes run `auth` + `requireActiveAccount` + `checkContractPermission` (`contractPermission.js:16-26` correctly scopes to participants), and all `/admin/*` routes run `auth` + `adminAuth`. See F-43 and F-91 for the residual `/user/*` and revocation gaps.)

---

## Medium — Security

### F-12 Dispute reason transmitted/stored/returned in plaintext

**Severity:** Medium
**Category:** Security
**Affected repositories:**
- YACK-Backend
**Location:**
- `src/controllers/contractController.js:826` (stores reason), `:866-881` (FCM data payload `{ type:"contractDispute", reason, ... }`), `:970-973` (returned to both parties via `/contracts/list`)
- `src/utils/sendNotification.js:12-18` (stringify/truncate only)
- `src/controllers/adminController.js:40-41` (returned to admins)
**Problem:** Dispute reasons may contain sensitive business detail; they are sent verbatim into FCM data (visible in Firebase messaging logs and on the counterparty's device) and combined with F-03 the token holder can read them. They cannot be revoked.
**Impact:** Confidential dispute explanations leak to push transport and counterparty regardless of sender intent.
**Recommended Fix:** Encrypt the reason for the admin audience (same pattern as `reviewAccessGrants`) and never place it in FCM `data`; expose to the counterparty only via an explicit, authenticated disclosure flow.
**Related Issues:** F-03.

### F-13 GET endpoints perform writes; finalization can outlive invitation TTL

**Severity:** Medium
**Category:** Backend
**Affected repositories:**
- YACK-Backend
**Location:**
- `src/controllers/contractController.js:545-593` — `GET /contracts/temp/status` calls `finalizeTempContract` when both signatures present
- `src/controllers/contractController.js:98-104` — `finalizeTempContract` filter does **not** include `expiresAt`
- `src/controllers/adminController.js:195-197` — `GET /admin/disputes/:contractId` runs `Promise.all(participants.map(ensureSupportThread))`, creating documents on read
- `src/controllers/supportController.js:166` — `GET /support/thread` upserts
**Problem:** GET with side effects breaks HTTP semantics/cacheability; an expired-but-signed invitation can still be materialized into a final `Contract` merely by polling status; admin/user read endpoints create DB rows.
**Impact:** Contract materialization outside the documented expiry boundary; surprise writes on reads.
**Recommended Fix:** Gate finalization on `expiresAt: { $gt: new Date() }` or move it to a POST-only path; make thread reads non-creating (404 when absent).
**Related Issues:** F-34.

---

## Medium — Backend

### F-14 No pagination on `/contracts/list`, `/media/all`; hidden cap on `/admin/disputes`

**Severity:** Medium
**Category:** Backend
**Affected repositories:**
- YACK-Backend
- YACK-Admin (client blind spot)
**Location:**
- `src/controllers/contractController.js:930-935` — `Contract.find(...).populate(...).sort({ updatedAt:-1 })`, no limit; full embedded arrays ride along
- `src/controllers/mediaController.js:97-115` — `.select("media")` with no cap
- `src/controllers/adminController.js:162-166` — `.limit(250)` hidden, no pagination params
**Problem:** Long-lived accounts return every contract with every embedded message/media (unbounded payload); admins cannot reach disputes beyond the newest 250; sort/filter params unvalidated.
**Impact:** Client/server memory blowup, blind spots in admin queue, growing DB scan cost.
**Recommended Fix:** Cursor/limit pagination with validated bounds; project only needed fields; paginate `/admin/disputes` with server-side search.
**Related Issues:** F-01, F-56.

### F-15 No graceful shutdown, request timeouts, or real health endpoint; Mongo connect not awaited

**Severity:** Medium
**Category:** Backend
**Affected repositories:**
- YACK-Backend
**Location:**
- `src/index.js:44-47` — `app.listen` is the last statement; no `server.close()`, no SIGTERM/SIGINT handlers, no `unhandledRejection` handler
- `src/config/mongo.js:6-13` — fire-and-forget connect; `process.exit(1)` only on connect failure
- `src/index.js:25-27` — health endpoint returns a constant regardless of DB/Firebase state
**Problem:** On deploys/restarts in-flight requests are hard-dropped; a stray unhandled rejection kills the process; the health probe can't detect DB degradation; first requests after boot hit un-connected DB.
**Impact:** Request loss during deploys, unpredictable crashes, false "healthy" status, slow failure during DB outages.
**Recommended Fix:** Gate `listen` on the Mongo connect promise; register SIGTERM/SIGINT handlers that `server.close()` + `mongoose.disconnect()`; add `unhandledRejection`/`uncaughtException` logging; add `/health` + `/health/ready` (DB + Firebase probe); set socket/connection timeouts.
**Related Issues:** None.

### F-16 Tests miss the entire authorization/dispute/concurrency surface

**Severity:** Medium
**Category:** Testing
**Affected repositories:**
- YACK-Backend
**Location:**
- `test/` — 8 files, all unit-level
- `test/liveApi.integration.test.js:4-9` — integration test skipped unless `RUN_LIVE_INTEGRATION=1`, happy path only
**Problem:** No test imports `auth`, `requireActiveAccount`, `checkContractPermission`, or any user/contract/message/media/support/admin controller or route. The exact areas this audit flags (IDOR, dispute lifecycle F-11, attachment cap F-44, review grants, MIME spoofing, idempotency) have zero regression protection.
**Impact:** Regressions in access control and the contract state machine ship silently.
**Recommended Fix:** Add supertest-style route tests for 401/403/400/404/409/410 paths, cross-user IDOR cases, dispute-after-resolve, expired/cancelled reservations, concurrent accept/sign, upload validation, and admin resolution.
**Related Issues:** F-11, F-44.

---

## Medium — Mobile Application

### F-17 "Locked account" state still renders previously synced decrypted data

**Severity:** Medium
**Category:** Mobile / Security
**Affected repositories:**
- YACK (Flutter)
**Location:**
- `lib/presentation/screens/contract_agr/contract_agreement.dart:542-560` — `build()` streams `watchObject` and renders contract unconditionally
- `:778-886` — message list streams decrypted records with no lock filter
- `:570` — AppBar shows `contract.title` with no key check
- Lock only disables input (`:1163-1174`) and shows a lock icon in the empty state (`:810-838`)
- `DecryptedKeyCache.value` is `null` after restart (`lib/logic/services/auth/decrypted_key_cache.dart`)
**Problem:** After relaunch, cached plaintext content and message history are shown to anyone who opens the app while the UI asks for the encryption password — implying protection that does not exist.
**Impact:** False sense of security; anyone with the unlocked device reads full history without the password.
**Recommended Fix:** Gate rendering of decrypted content behind `DecryptedKeyCache.isUnlocked`; combined with F-04 this becomes moot.
**Related Issues:** F-04.

### F-18 Message `contentHash` and grant `detailsHash` never verified

**Severity:** Medium
**Category:** Mobile / Security
**Affected repositories:**
- YACK (Flutter)
- YACK-Admin
**Location:**
- Client decrypt ignores hash: `lib/logic/services/message/message_sync_service.dart:95-118`, `lib/presentation/screens/contract_agr/contract_agreement.dart:224-244`
- Server stores with format checks only: `YACK-Backend/src/utils/messageValidation.js:25-53`, pushed at `messageController.js:21-23`
- Support path **does** verify: `lib/logic/services/support/support_service.dart:121-125` (throws on mismatch)
- Admin ignores both: `YACK-Admin/app/page.tsx:1035-1039` (renders hash as a label only), `lib/crypto.ts:89-94` (`sha256Hex` only used for outgoing messages)
**Problem:** `contentHash` is the only tamper-detection mechanism for encrypted content, but the client that can check it doesn't. A tampered ciphertext is rendered as authentic. Admin review of legally significant evidence never verifies `detailsHash`.
**Impact:** Undetected alteration/corruption of message and case material.
**Recommended Fix:** After decryption compare `sha256(plaintext)` with `contentHash` (messages) and recompute `detailsHash` from decrypted title+description+price; display `[Unable to verify]` on mismatch — same pattern as `support_service.dart`.
**Related Issues:** None.

### F-19 Argon2id (64 MB/3-pass) and RSA keygen run synchronously on the UI isolate

**Severity:** Medium
**Category:** Mobile / Performance
**Affected repositories:**
- YACK (Flutter)
**Location:**
- `lib/logic/cubits/user/user_cubit.dart:128-154` (`decryptAndLoad`), `:22-35` (`finalize`)
- `lib/logic/cubits/auth/change_encryption_password_cubit.dart`
- Params: `lib/logic/services/auth/cryptoService.dart:19-23,36-61` — Argon2id, `memoryPowerOf2=16` (64 MB), `iterations=3`
**Problem:** 64 MB / 3-pass Argon2id takes 1-3 s (more on low-end hardware) of frozen UI on unlock, account setup, and password change. The freeze is papered over with `await Future.delayed(50ms)` (`user_cubit.dart:24-25,130-131`).
**Impact:** UI freezes, dropped input, ANR risk; perceived as an app hang.
**Recommended Fix:** Run derivation/keygen in a background isolate (`Isolate.run`/`compute`) with progress UI.
**Related Issues:** F-20.

### F-20 Serial per-message RSA decryption on the UI isolate, re-run on every open and after each send

**Severity:** Medium
**Category:** Mobile / Performance
**Affected repositories:**
- YACK (Flutter)
**Location:**
- `lib/presentation/screens/contract_agr/contract_agreement.dart:224-244` — `_syncMessages()` loops calling `decryptWithPrivateKey` inline, then per-message Isar writes
- `lib/logic/cubits/message/message_cubit.dart:66-94` — `sendMessage` → `syncMessages` → full fetch + decrypt
- Dedup only prevents duplicate rows, not re-decryption: `lib/data/repositories/isar_adapter.dart:291-298`
**Problem:** Long chats cause repeated main-thread RSA work and jank; every send re-fetches and re-decrypts the whole page.
**Impact:** Stutter on open and after each send; grows with message count.
**Recommended Fix:** Decrypt in a background isolate; skip messages whose `externalId` is already stored; avoid the redundant reload after send.
**Related Issues:** F-19, F-51.

### F-21 RSA-OAEP uses SHA-1 on clients; backend crypto helper uses SHA-256 (latent mismatch)

**Severity:** Medium — `Needs verification` for the "breakage" half (interop is not exercised end-to-end today)
**Category:** Mobile / Security
**Affected repositories:**
- YACK (Flutter)
- YACK-Backend
- YACK-Admin
**Location:**
- Flutter `lib/logic/services/auth/cryptoService.dart:204-205,222-223` — `OAEPEncoding(RSAEngine())` defaults to SHA-1 hash + MGF1-SHA1
- Admin `lib/crypto.ts:42-49,60-78` — WebCrypto `importKey` binds `hash: 'SHA-1'` for both the review private key and user JWKs
- Backend `src/utils/cryptoHandler.js:25-45` — `oaepHash: 'sha256'` (dead code today, F-05)
**Problem:** Both live clients use SHA-1 OAEP and currently interoperate with each other; the (dead) backend canonical helper uses SHA-256. Any future "modernization" of one side to SHA-256 without the other silently breaks every envelope. SHA-1 OAEP is NIST-deprecated. Additionally, `ADMIN_REVIEW_PUBLIC_KEY` is a single unversioned global — rotating it makes every previously encrypted grant/support message undecryptable.
**Impact:** Latent coupling risk; no round-trip test asserts the parameters; total loss of historical review material on key rotation.
**Recommended Fix:** Configure SHA-256 explicitly on both clients (`OAEPEncoding(RSAEngine(), SHA256Digest(), SHA256Digest())`) and keep backend `oaepHash` in sync; add a round-trip test (encrypt with published review public key, decrypt via `importReviewPrivateKey`); version the review key (`keyId` per grant/ciphertext).
**Related Issues:** F-05, F-53.

---

## Medium — Admin Dashboard

### F-22 Unhandled promise rejection on dispute-open failure; sheet opens before data arrives

**Severity:** Medium
**Category:** Admin / State Mgt
**Affected repositories:**
- YACK-Admin
**Location:**
- `app/page.tsx:383-417` (`openDispute`) — catches, sets `error`, then `throw loadError` (line 411)
- Callers `void openDispute(item._id)` at `:847` and the MCP execute at `:450`, neither with `.catch()`
- `setDetailOpen(true)` at `:386` before fetch; `setDetailLoading(true)` at `:387`
**Problem:** Every open failure produces an unhandled rejection; the sheet opens showing an error-less empty panel until the banner appears behind it.
**Impact:** Poor error visibility; console noise; confusing empty sheet with no retry affordance.
**Recommended Fix:** Catch at call sites or remove the rethrow; open sheet only after detail resolves; add retry.
**Related Issues:** F-23.

### F-23 Out-of-order responses race without abort or deduplication

**Severity:** Medium
**Category:** Admin / State Mgt
**Affected repositories:**
- YACK-Admin
**Location:**
- `app/page.tsx:345-369` (`loadDashboard`) — four parallel fetches, no generation counter/AbortController
- `lib/api.ts:109-130` (`request`) — no abort/timeout plumbing
- `openDispute` (`:383-417`) shares single `detail`/`decrypted`/`selectedThreadId` state
**Problem:** A slower earlier response can overwrite a newer one (e.g., opening case A then case B — A resolving later shows A's sheet with B's decrypted data); refresh races can regress lists to stale server state.
**Impact:** Reviewing/deciding on the wrong or old case state; silently reverted statistics.
**Recommended Fix:** `AbortController` in `request()`, monotonic request-id token per call, ignore stale responses; disable Refresh while in flight.
**Related Issues:** F-22, F-25.

### F-24 "Support" view is a duplicate of "Disputes" with a mismatched badge count

**Severity:** Medium
**Category:** Admin / UI-UX
**Affected repositories:**
- YACK-Admin
**Location:**
- `app/page.tsx:572-586` (`nav`) — Disputes badge uses `openCases.length`, Support badge uses `analytics?.openSupportThreads ?? 0`
- Support view (`:782-869`) changes only heading/subheading; table renders the identical `visibleCases` list with no support filtering
**Problem:** Two different data sources feed the two badges; neither matches what the Support tab actually displays (the full dispute queue). The tab promises support conversations but shows case rows.
**Impact:** Confusing navigation and uncorrelated counters.
**Recommended Fix:** Implement a genuine support-thread view or remove the tab; derive both badges from one source.
**Related Issues:** F-14.

### F-25 `request()` swallows non-JSON/empty errors; no timeout; review key fetched on every send

**Severity:** Medium
**Category:** Admin / Integration
**Affected repositories:**
- YACK-Admin
**Location:**
- `lib/api.ts:109-130` — `response.json().catch(() => ({}))`; HTML/empty/proxy errors become generic `Request failed (500)`; no `AbortSignal`
- `app/page.tsx:492-494` (`sendSupport`) — `api.reviewKey(user).then(importYackPublicKey)` on every message send
**Problem:** Backend cold starts / 502s produce opaque failures and stuck loaders; the review key is refetched per message, widening the F-21 key-rotation inconsistency window.
**Impact:** Opaque failures and stuck UIs; unnecessary request volume.
**Recommended Fix:** Parse errors via `text()` with status + truncated body; add timeout/abort; cache the review public key per session.
**Related Issues:** F-21, F-23.

### F-26 Failed "Resolve dispute" is invisible behind the modal

**Severity:** Medium
**Category:** Admin / UI-UX
**Affected repositories:**
- YACK-Admin
**Location:**
- `app/page.tsx:515-537` (`resolveCase`) catch sets shared `error`; banner renders at `:688-695` behind the `AlertDialog` overlay (`:1260-1313`)
- Backend 409 "dispute is no longer open" (`adminController.js:320-322`)
**Problem:** A failed resolve gives no perceptible feedback inside the modal; admin may retry blindly or assume success.
**Impact:** Wrong operational belief about whether a decision was recorded.
**Recommended Fix:** Render inline error in `AlertDialogContent`; on 409, refetch and show "already resolved by someone else."
**Related Issues:** None.

### F-27 In-browser model tool `open_dispute_case` auto-registered without explicit consent

**Severity:** Medium — `Needs verification` (the `document.modelContext` bridge semantics are not defined in this repo)
**Category:** Admin / Security
**Affected repositories:**
- YACK-Admin
**Location:**
- `app/page.tsx:419-458` — `modelContext.registerTool({ name: 'open_dispute_case', ... })` whenever any admin is signed in, no per-session opt-in
**Problem:** Exposes an admin-only capability to whatever in-browser AI agent owns `modelContext`, with weaker human authorization than the Review button; the DOM includes attacker-written content (dispute reasons, decrypted messages), a prompt-injection surface that could drive the agent to open other cases and exfiltrate metadata.
**Impact:** Silent, model-driven access to dispute metadata during admin sessions; potential prompt-injection pivot.
**Recommended Fix:** Require explicit per-session opt-in; restrict the tool to a user-selected contract ID; exclude untrusted/decrypted text from the model-visible DOM; consider removing the integration.
**Related Issues:** F-06.

---

## Medium — Integration

### F-30 FCM media notification payload uses `mediaId`, client parser reads `mediaPath`

**Severity:** Medium
**Category:** Integration
**Affected repositories:**
- YACK-Backend
- YACK (Flutter)
**Location:**
- Backend `mediaController.js:66-83` — sends `{ type:"contractMedia", contractId, mediaId }`
- Flutter `lib/data/db/models/notification.dart:64-69` and `lib/logic/services/notification/contract_notification_handler.dart:75-80` — read `data['mediaPath']`
**Problem:** The only key the client parsers look for is never emitted; `AppNotification.mediaPath` is always null.
**Impact:** Media path silently lost in notifications (routing still works via `contractId`).
**Recommended Fix:** Emit `mediaPath` alongside `mediaId`, or normalize the client to read `mediaId`.
**Related Issues:** None.

### F-31 Mobile accept flow ignores server `status`, hardcodes local `accepted`

**Severity:** Medium
**Category:** Integration
**Affected repositories:**
- YACK (Flutter)
- YACK-Backend
**Location:**
- Flutter `lib/logic/services/contract/contractHandler.dart:99-104` — `accept(contractId)` then `updateContractStatusInIsar(contractId, 'accepted')`
- Backend `contractController.js:781-787` — response `status` may be `"completed"` when both parties have agreed (`:732-741`)
**Problem:** The client discards the authoritative server status; a contract completed by mutual acceptance renders as "Accepted" until the next `/contracts/list` sync.
**Impact:** Stale/churn state in UI and inconsistent filtering.
**Recommended Fix:** Read `response['status']` and persist it, falling back to `'accepted'`.
**Related Issues:** None.

### F-32 Flutter drops dispute specifics on sync

**Severity:** Medium
**Category:** Integration
**Affected repositories:**
- YACK (Flutter)
- YACK-Backend
**Location:**
- Backend `contractController.js:949-978` returns `disputeReasonUserA/B`, `disputedAtUserA/B`, `disputedUserA/B`; model `Contract.js:81-95`
- Flutter `lib/data/repositories/isar_adapter.dart:143-146` collapses to constant `'Disputed'`; Isar `lib/data/db/models/contract.dart:51-53` has only `disputeReason`/`disputedBy`
**Problem:** Per-party reasons/timestamps and full dispute/resolution state (`disputeState`, resolution fields) never stored locally.
**Impact:** Users cannot see dispute/reason/timeline offline; resolution state invisible on-device while it drives the admin UI.
**Recommended Fix:** Add `disputeReasonUserA/B`, `disputedAtUserA/B`, `disputeState`, resolution fields to Isar `Contract`; populate from `ContractListItem`.
**Related Issues:** None.

### F-33 `language` written by backend but never read by Flutter profile model

**Severity:** Medium
**Category:** Integration
**Affected repositories:**
- YACK (Flutter)
- YACK-Backend
**Location:**
- Backend `src/controllers/userController.js:19-32` (`userResponse` includes `language`), `:185-190` (validates en/fr/ar)
- Flutter `lib/logic/services/user/user_service.dart:27-39` — `UserProfile.fromJson` maps no `language`; `lib/logic/services/auth/account_service.dart` caches none
**Problem:** The backend stores the preference; the app never restores or displays it.
**Impact:** Language preference silently lost after every app restart/profile refetch.
**Recommended Fix:** Map `language` in `UserProfile.fromJson` and cache in Hive, defaulting to `en`.
**Related Issues:** None.

### F-34 Temp-contract status poll requires an active (finalized) account

**Severity:** Medium
**Category:** Integration
**Affected repositories:**
- YACK (Flutter)
- YACK-Backend
**Location:**
- Flutter `lib/presentation/screens/scan_contract.dart:161,332`, `shareContract.dart:147` poll `TempContractService.getStatus` (`temp_contract_service.dart:82` → `GET /contracts/temp/status?tempID=`)
- Backend `src/routes/contractRoutes.js:27` — `auth, requireActiveAccount, getTempContractStatus`; `requireActiveAccount.js:8-16` blocks with 409 `ACCOUNT_INCOMPLETE` when not finalized
**Problem:** The join/scan recovery flow reverts to "Account setup must be completed" instead of temp status when the account isn't fully finalized (e.g., prospective userB scans before finalizing keys, or on expired invites).
**Impact:** Failing recovery path for cold-join flows.
**Recommended Fix:** Relax `requireActiveAccount` on the status route (metadata is already gated to A-and-B after join), or ensure onboarding finalizes before polling.
**Related Issues:** F-13.

---

## Medium — Abuse / Dependencies / Code Quality

### F-35 Mass account creation — backend auto-upserts users with no throttle

**Severity:** Medium
**Category:** Abuse
**Affected repositories:**
- YACK-Backend
**Location:**
- `src/middleware/auth.js:70-74` — `User.findOneAndUpdate({ firebaseID }, { $setOnInsert... }, { new:true, upsert:true })`
**Problem:** registration/creation is fully open and scriptable; the backend has no control over signup rates beyond Firebase's client-side heuristics.
**Impact:** Thousands of placeholder `User` rows; a feed for other abuse scenarios.
**Recommended Fix:** Rate-limit first-touch user creation; require verified email for all writes.
**Related Issues:** F-02, F-43.

### F-36 No per-user quota on contracts/upload; notification spam

**Severity:** Medium
**Category:** Abuse
**Affected repositories:**
- YACK-Backend
**Location:**
- `src/controllers/contractController.js:199` — `TempContract.create` with no per-user cap
- `src/controllers/mediaController.js:23` — upload with no count/byte budget per user (6 MB per-file cap only, `mediaHandler.js:5`)
- `src/controllers/contractController.js:363-379,511-530`, `messageController.js:53-71`, `mediaController.js:65-84`, `adminController.js:286-291,355-362` — fire-and-forget `sendNotification` on every action
**Problem:** Unlimited temp/final contracts, unlimited media (Cloudinary spend), unlimited pushes to counterparty devices — all only bounded by the (missing) rate limits.
**Impact:** Storage/transfer cost escalation, bill shock, per-user notification flood.
**Recommended Fix:** Per-user quotas (open invites, contracts, media per contract, daily upload bytes); return 429 above quota; rate-limit underlying endpoints.
**Related Issues:** F-02, F-01.

### F-37 Mobile ships unconditional `print(...)` debug statements in production paths

**Severity:** Medium
**Category:** Code Quality
**Affected repositories:**
- YACK (Flutter)
**Location:**
- `lib/logic/services/contract/temp_contract_service.dart:57,60,65,69,101,105`; `contract_sync_service.dart:33,49,58,66,91,104,116,150,157,163,176`; `message_sync_service.dart:36,63,70,81,103,121,126,132,155`; `auth_cubit.dart:110,113`; `change_encryption_password_cubit.dart:60`
**Problem:** Debug payloads (join/sign responses, sync results — including invite metadata) land in release-mode logs.
**Impact:** Info disclosure in device logs; log spam/performance on every sync.
**Recommended Fix:** Gate with `kDebugMode` logger; strip `[DEBUG]` prints.
**Related Issues:** None.

### F-38 Hive + Isar storage overlap; `pubspec.lock` ignored; test libs in prod deps

**Severity:** Medium
**Category:** Dependencies
**Affected repositories:**
- YACK (Flutter)
**Location:**
- `pubspec.yaml:37-38` (`hive`, `hive_flutter`) + `:56-57` (`isar`, `isar_flutter_libs`) both active
- `pubspec.yaml:43-51` — `flutter_test`/`flutter_lints` under `dependencies`
- `.gitignore` ignores `pubspec.lock`
**Problem:** Two native DB engines persist overlapping state; ignoring the lockfile makes CI/device builds non-reproducible; test/lint packages ship in the app graph.
**Impact:** Larger APK, conflicting migration logic, non-deterministic builds.
**Recommended Fix:** Consolidate on one storage engine; commit `pubspec.lock`; move test/lint deps to `dev_dependencies`.
**Related Issues:** F-08-abuse (mobile deps) — see also unused Cloudinary/Firebase RTDB packages (F-66 hardcoded inventory).

---

## Low — Miscellaneous

### F-39 Pre-join temp status leaks final-version `detailsHash` and participant names

**Severity:** Low
**Category:** Security
**Location:** `contractController.js:60-78` (`tempStatusPayload` returns `detailsHash` always), `:545-570` (any authenticated active user may read pre-join metadata at `:560-562`)
**Problem:** `detailsHash` is a bare SHA-256 of low-entropy plaintext terms (brute-forceable offline); participant names/`_id` are also returned pre-join.
**Impact:** Offline dictionary attack on terms; PII enumeration of creators to anyone holding a tempID.
**Fix:** Return `detailsHash` only after `userB` is reserved (or HMAC it); limit pre-join metadata to status + expiry + signature flags.

### F-40 `verifyContract` hash comparison lacks normalization and is not constant-time

**Severity:** Low
**Category:** Validation
**Location:** `contractController.js:898-924` (`:905-908` input checks only; `:917` `storedHash === providedHash`)
**Impact:** Timing side-channel (low exploitability on WAN); inconsistent match semantics between create/join and verify; unbounded input size.
**Fix:** Bound to ≤512 chars, trim/normalize case like the store side, compare with `crypto.timingSafeEqual`.

### F-41 Contract encrypted fields not validated as ciphertext

**Severity:** Low
**Category:** Validation
**Location:** `contractController.js:14-25` (`requiredString` — type/trim/length only) vs `messageValidation.js:25-53` (requires canonical Base64); duplicated SHA-256-hex regex across 4 files, already drifted
**Impact:** A party can persist garbage envelopes; counterparty decryption fails with no server-side signal; blacklisted contracts.
**Fix:** One shared `validateCiphertext` + hash validator used by contract/join/review-access paths.

### F-42 Upload MIME type inferred from filename extension only

**Severity:** Low
**Category:** Security
**Location:** `mediaHandler.js:117-132`
**Impact:** Attacker-controlled content-type (bytes never sniffed); SVG is correctly absent from the allowlist and path traversal is blocked — positive notes confirmed.
**Fix:** Verify magic bytes against inferred type; store sniffed type; reject mismatches.

### F-43 Unverified/incomplete accounts can exercise all `/user/*` endpoints

**Severity:** Low
**Category:** Abuse
**Location:** `userRoutes.js:15-20` mounts only `auth` (no `requireActiveAccount`); `userController.js:216-236`, `:35`, `:113`, `:123`, `:166`
**Impact:** Free write slots for credential churn; noise in `User` docs.
**Fix:** Require verified email for writes; rate-limit `/user/finalize` and FCM routes.

### F-44 Support attachment count cap is racy

**Severity:** Low
**Category:** Concurrency
**Location:** `supportController.js:233-257` — check-then-`$push` is not atomic (two concurrent uploads can exceed 25)
**Fix:** Enforce the cap inside the conditional update with `$expr` (`$size: "$attachments" < 25`); delete the Cloudinary object if rejected.

### F-45 Concurrent `ensureSupportThread` upserts can throw E11000 → 500

**Severity:** Low
**Category:** Concurrency
**Location:** `supportController.js:62-68` + unique index `SupportThread.js:55`; `adminController.js:195-197` uses `Promise.all(participants.map(ensureSupportThread))`
**Fix:** E11000 retry (refetch existing thread) or update-then-insert fallback.

### F-46 Missing indexes for query patterns actually used

**Severity:** Low
**Category:** Database
**Location:** `Contract.js:113-123` (only `sourceTempContract`, `userA+updatedAt`, `userB+updatedAt`); `adminController.js:105-129,311-321` queries by `status`/`disputeState`/`createdAt`; `User.countDocuments({isComplete:true})`; FCM `updateMany` pull
**Fix:** Add `{status,updatedAt}`, `{disputeState,updatedAt}`, `{createdAt}` on Contract; `{isComplete}` and partial `{fcmTokens}` on User.

### F-47 Unstructured logging; no admin action audit stream

**Severity:** Low
**Category:** Error Handling
**Location:** 9 bare `console.error(error)` in `contractController.js` (`:215,394,539,590,679,789,892,921,983`); no request ID; admin actions recorded only as scattered DB fields
**Fix:** Structured JSON logger with request IDs + PII masking; append-only admin audit collection (view/resolve/reply with identity+timestamp).

### F-48 Push listeners registered without retaining subscriptions; `dispose()` kills singleton

**Severity:** Low
**Category:** Mobile
**Location:** `notification_service.dart:43-53` (subscriptions not stored); `contract_notification_handler.dart:187-191` (`_eventController.close()`)
**Fix:** Store/cancel subscriptions before re-subscribing; make `dispose()` safe for the singleton.

### F-49 Backend structured error codes discarded by client

**Severity:** Low
**Category:** Mobile
**Location:** `http_handler.dart:216-224` keeps only `json["error"]` string, drops `code`; backend returns `code` (e.g., `EMAIL_NOT_VERIFIED`, `ACCOUNT_INCOMPLETE`, `CONTRACT_EXPIRED`); l10n key `invitation_cancelled_or_expired` (`en.dart:20-22`) is unreachable
**Fix:** Typed `ApiException` carrying `status`+`code`; map known codes to localized messages.

### F-50 Corrupted error string `'S mpID field.'`

**Severity:** Low
**Category:** Mobile
**Location:** `temp_contract_service.dart:193-195`
**Fix:** Fix the text and raise a descriptive typed error.

### F-51 Local indexing/rendering inefficiencies

**Severity:** Low
**Category:** Mobile / Performance
**Location:** `isar_adapter.dart:389-393` (O(n) full-scan per media insert → O(n²)); `contract_sync_service.dart:169-181` (`syncSingleContract` re-runs full list — TODO); `home.dart:227-241` (filter rebuild per keystroke)
**Fix:** Filtered Isar query; add `GET /contracts/:id`; debounce search.

### F-52 All-or-nothing decryption on a case

**Severity:** Low
**Category:** Admin / Crypto
**Location:** `app/page.tsx:178-220` (`Promise.all` over all fields/messages with no per-item isolation)
**Fix:** Per-item try/catch; render per-field/message failure markers; show successfully decrypted portions.

### F-53 Review-key import accepts any PKCS8 file with no identity check

**Severity:** Low
**Category:** Admin / Crypto
**Location:** `lib/crypto.ts:36-49`; `app/page.tsx:460-481`
**Fix:** Compute SHA-256 fingerprint or compare modulus to fetched `ADMIN_REVIEW_PUBLIC_KEY`; show "review key fingerprint …" before enabling decryption; record fingerprint with the decision.

### F-54 Firebase auth uses default local persistence; no per-tab isolation

**Severity:** Low
**Category:** Admin / Auth
**Location:** `lib/firebase.ts:16-18` — no `browserSessionPersistence`; token in `localStorage`; combined with F-06 material persists across sign-out
**Fix:** Consider `browserSessionPersistence`; clear sensitive state on sign-out/tab-hide.

### F-55 Support-thread attachments disclosed before review access is granted

**Severity:** Low
**Category:** Admin / Security
**Location:** `adminController.js:220-230` gates contract `media` on `reviewAccessGrants?.length` but `:236-243` maps `thread.attachments` unconditionally; `app/page.tsx:1100-1104` copy promises hidden files but `:1159-1194` renders them regardless of grant state
**Fix:** Gate support attachments on grant state too, or update the copy.

### F-56 Analytics `contractTrend` fetched but never rendered; `recharts` dead weight

**Severity:** Low
**Category:** Admin
**Location:** `lib/api.ts:102-103`; `app/page.tsx:349-355`; `package.json:32`; only consumer is never-imported `components/ui/chart.tsx`
**Fix:** Render the chart or drop the dependency + payload.

### F-57 No confirmation for sign-out, silent review-key swap, no unsaved-draft guard

**Severity:** Low
**Category:** Admin / UI-UX
**Location:** `app/page.tsx:642-650` (sign-out `onClick={() => signOut(auth)}`), `:460-481` (key overwrite), `:874` (sheet close discards `supportDraft`), resolve dialog `:1260-1313` (no outcome/note restatement)
**Fix:** Confirmation prompts; verify new key against current case before accepting; draft-loss guard; restate outcome+note at resolve confirm.

### F-58 Unused/heavy admin dependencies; no test script

**Severity:** Low
**Category:** Admin / Dependencies
**Location:** `package.json:16-52` — only 11 of the shipped UI wrappers are imported; unused: `recharts`, `cmdk`, `embla-carousel-react`, `input-otp`, `react-day-picker`, `date-fns`, `react-resizable-panels`, plus ~30 wrappers; `wrangler` (4.92.0, dev) leftover from removed Cloudflare hosting; no `test` script
**Fix:** Prune; remove `wrangler`; add minimal tests for `lib/crypto.ts` and `lib/api.ts`.

### F-59 `GET /media/get` implemented but never invoked by mobile UI

**Severity:** Low
**Category:** Integration
**Location:** `lib/logic/cubits/media/media_cubit.dart:28-42` → `media_service.dart:157`; no screen calls `getMedia` (only `loadMedia`/`uploadMedia`); backend `mediaRoutes.js:16` → `mediaController.js:117`
**Fix:** Wire into a media preview screen, or remove.

### F-60 Contract `hash` parsed but never persisted to Isar

**Severity:** Low
**Category:** Integration
**Location:** `contract_list_service.dart:33,92` parses `hash`; `isar_adapter.dart:98-150` never writes it; Isar `Contract` has `detailsHash` but no `hash`
**Fix:** Add `hash` to Isar `Contract` and persist.

### F-61 Backend `PORT` defaults to 80 vs Flutter dev defaults to port 3000

**Severity:** Low
**Category:** Config
**Location:** `src/index.js:44`; Flutter `http_handler.dart:38-41`
**Fix:** Default `PORT=3000` when `NODE_ENV != 'production'`.

### F-62 Temp status string `"finalized"` never emitted by backend

**Severity:** Low
**Category:** Integration
**Location:** `temp_contract_service.dart:269-273` (`isFinalized` accepts `'finalized'`); backend `contractController.js:51-58` emits `waiting_for_join|waiting_for_signatures|finalizing|completed|cancelled|expired`
**Fix:** Drop `'finalized'` or emit it.

### F-63 Admin `DisputeSummary.disputeState` type narrower than backend enum

**Severity:** Low
**Category:** Integration
**Location:** `Contract.js:91-95` (`none|open|resolved`) vs `lib/api.ts:14` (`'open'|'resolved'`); normalization at `adminController.js:35`
**Fix:** Widen the type or document the normalization invariant.

### F-64 No committed deploy manifests; admin default API URL mismatches backend docs

**Severity:** Low
**Category:** Config
**Location:** `lib/api.ts:106` defaults to `https://yack-backend.onrender.com`; `SETUP.md:129-135,158` documents Leapcell; no `render.yaml`/`Dockerfile`/`wrangler.toml` in any repo (`Needs verification`: actual deployed host)
**Fix:** Align fallback with documented host or fail at build; commit minimal deploy config/workflow per repo.

### F-65 Admin Node engine floor + pre-release toolchain, no pin

**Severity:** Low — `Needs verification` (host compliance not checkable from here)
**Category:** Config
**Location:** `package.json:6-7` (`node >=22.13.0`), `:36` (`vinext 1.0.0-beta.5`), no `.nvmrc`/`packageManager`
**Fix:** Add `.nvmrc`, `packageManager`/`engines-strict`; document runtime.

### F-66 Documentation drift; duplicated API docs

**Severity:** Low
**Category:** Code Quality
**Location:** `mobile/lib/api.md` + `mobile/lib/notification.md` duplicate `backend/src/api.md` + `backend/src/notification.md`; possible unused `mobile/lib/data/db/models/notification.dart` (`Needs verification`)
**Fix:** Keep API docs in one place; delete confirmed-unused files.

---

## Medium — Security (Secrets & Config, continued from High)

### F-28 Firebase Admin service-account JSON duplicated inside backend source tree

**Severity:** Medium
**Category:** Secrets
**Location:** `src/config/serviceAccountKey.json` (on disk, gitignored, loaded as fallback by `src/config/firebase.js:33-55`)
**Problem:** Second copy of the crown-jewel Admin SDK key alongside `.env`; any `git add -f`, IDE cache, or directory zip leaks it.
**Impact:** Same exposure as F-10 plus credential sprawl.
**Fix:** Delete the file; rely solely on `FIREBASE_*` env vars; pre-commit secrets guard.

### F-29 Hardcoded production Firebase/API fallbacks in admin client

**Severity:** Medium
**Category:** Config
**Location:** `lib/firebase.ts:4-13` — real `apiKey`/`authDomain`/`projectId`/`appId` fallbacks; `lib/api.ts:105-107` — `https://yack-backend.onrender.com` default
**Problem:** Any build without `.env` silently targets the live production backend and embeds real Firebase identifiers; `.env.example` uses placeholders; no build-time validation.
**Impact:** Misconfig; accidental writes to production; real identifiers in committed code (web API key is public-client material, not a server secret).
**Fix:** Remove fallbacks; fail at build when `VITE_*` are absent.

---

## High/Medium remaining — Cross-cutting

### F-68 (folded-in) CORS open + `X-Powered-By`

**Severity:** Low — `Needs verification` for production host posture (Render may impose its own allowlist)
**Category:** Security
**Location:** `src/index.js:20` `app.use(cors())` (no origin allowlist)
**Impact:** Any website may read response bodies; latent risk if cookie-based auth is ever introduced; bearer-token CSRF is not applicable today (tokens from JS memory, not auto-attached).
**Fix:** Restrict origins to the admin host(s) + `http://localhost:*` for dev; `app.disable('x-powered-by')`; consider `helmet`.

### F-69 (folded-in) Firewall env: localhost Mongo fallback, lazy Cloudinary validation

**Severity:** Medium
**Category:** Config
**Location:** `src/config/mongo.js:4` (`|| "mongodb://127.0.0.1:27017/yack"`); `mediaHandler.js:49-56` lazy `MediaConfigurationError` at first upload
**Fix:** Reject startup on missing required env in production; validate Cloudinary at boot; warn/redacted-loggable.
**Related:** F-08.

### F-70 (folded-in) Revoked/disabled Firebase tokens keep full access until expiry

**Severity:** Medium
**Category:** Authn
**Location:** `auth.js:41` `verifyIdToken(token)` — no `{ checkRevoked: true }`; no `blocked` flag on `User`
**Fix:** Pass `{ checkRevoked: true }`; return 401 on revocation; enforce a `blocked` flag in `requireActiveAccount`/`adminAuth`.
**Related:** F-43.

### F-71 (folded-in) Admin dispute-review RSA private key present in repo directory

**Severity:** Low
**Category:** Secrets
**Location:** `admin-review-private-key.pem` / `admin-review-public-key.txt` at `YACK-Admin` root, gitignored (`Needs verification` for whether the key was ever committed — history scan says no)
**Impact:** Travels with any archive of the folder; decrypts all user-shared dispute evidence.
**Fix:** Move to `~/.config/yack-admin/`; note backup in a secrets manager; confirm the key matches `ADMIN_REVIEW_PUBLIC_KEY` on the backend (supports F-08).
**Related:** F-08, F-53.

### F-72 (folded-in) Mobile Firebase client configs tracked (normal), Android package mismatch

**Severity:** Low
**Category:** Config
**Location:** `android/app/google-services.json` (placeholder package `com.example.yack`); iOS/macOS unconfigured in `lib/firebase_options.dart`
**Impact:** Public-client config (safe); feature gaps: no APNs/FCM on iOS; wrong applicationId.
**Fix:** Configure iOS/macOS if shipping; update applicationId in both `google-services.json` and `build.gradle.kts`.

### F-73 Subscription/billing screen is UI-only

**Severity:** Low (incomplete feature, not a defect)
**Category:** Mobile
**Location:** `lib/presentation/screens/subscription.dart` — doc states there is "no purchase backend"
**Status:** Incomplete by design; document in SYSTEM_DOCUMENTATION.md §26.

---

## Unused or Dead Code Candidates

- Backend `src/models/Media.js`, `src/models/Message.js` — never imported anywhere (INT I-07).
- Backend `src/utils/cryptoHandler.js` — `encryptMedia/decryptMedia/encryptWithRSA/decryptWithRSA/convertPublicKeyToPEM` self-referenced only (F-05).
- Backend `MediaHandler.getUrl` (`mediaHandler.js:224`) — no callers.
- Backend `GET /media/get` (`mediaRoutes.js:16`) — no UI caller (F-59).
- Backend `GET /support/attachments` (`supportRoutes.js:47`) — `SupportService.getAttachments` exists but `support_chat.dart` uses `thread.attachments`; tagged `Needs verification`.
- Backend `GET /` health — constant; used only by external probes (Needs verification).
- Flutter `'dispatched'`/`'on dispute'` mapping (`isar_adapter.dart:190-193`) — backend never emits those statuses.
- Flutter `local_`-prefix message upgrade branch (`isar_adapter.dart:303-326`) — no producer writes `local_` messages anymore.
- Flutter `AuthCubit` 5-second retry block (`auth_cubit.dart:56-64`) — guarded by `state is AuthError`, but the `AuthError` emit is commented out (`:53-54`), so it can never fire.
- Admin never-imported UI wrappers and deps (`chart`, `command`, `carousel`, `input-otp`, `calendar`, `resizable` + backing libs; `wrangler`) — F-58.
- Admin `contractTrend` payload + `recharts` — F-56.

## Hardcoded Values

- Flutter: locale flag emojis `'🇩🇿'`/`'🇺🇸'`/`'🇫🇷'` (`languageSheet.dart`); 6 MB limit duplicated in `contract_agreement.dart:94` and `support_chat.dart:474`; three different decryption-failure strings; `'S mpID field.'` (F-50); dev base URLs `http://10.0.2.2:3000`/`http://127.0.0.1:3000` (`http_handler.dart:38-41`); release throws unless `API_BASE_URL` injected; 12-second support polling interval (`support_chat.dart:43-45`); RSA plaintext ceiling 190 bytes (`cryptoService.dart:11`).
- Admin: production Firebase config fallbacks (`firebase.ts:6-13`, F-29); API base URL fallback (`api.ts:106`, F-29/F-64); RSA-2048 fixed in `generate-admin-review-key.mjs:23`; RSA-OAEP SHA-1 pinned (`crypto.ts:45`, F-21).
- Backend: `MAX_ENCRYPTED_FIELD_LENGTH = 16_384` (`contractController.js:10`) vs client RSA 190-byte ceiling (no conflict today, but server does not meaningfully police ciphertext sizing); `adminController.js:166` `limit(250)`; `:10-11` `MAX_CIPHERTEXT_LENGTH=16384`, `MAX_RESOLUTION_NOTE_LENGTH=4000`.

## TODO / FIXME / HACK Inventory

- Flutter `notification_service.dart:59` — `// TODO: Show local notification if needed` (foreground pushes only persist, no system notification).
- Flutter `contract_sync_service.dart:172` — `// TODO: Add endpoint to fetch single contract` (F-51).
- No TODO/FIXME/HACK found in backend `src/` or admin `app/`/`lib/` (grep-verified).

## Unused Backend Endpoints

- `GET /media/get` — `mediaRoutes.js:16` (F-59).
- `GET /support/attachments` — `supportRoutes.js:47` (service method exists, no UI caller; Needs verification).
- `GET /` root health — used only by external probes (Needs verification).

## Missing Backend Endpoints Referenced by Frontends

- **None.** All 37 client calls (30 mobile + 7 admin) map 1:1 to implemented routes with matching method/path/params (`contractId`, `tempID`, `state`, `outcome`, `contentForUser/Admin`, `contentForSender/Recipient`).
- Non-blocking gap: no dedicated `GET /contracts/:id`; `syncSingleContract()` re-runs full `/contracts/list` (F-51).

## API Contract Mismatches

- F-30 `mediaId` vs `mediaPath` in FCM payload.
- F-31 accept response `status` discarded for local `'accepted'`.
- F-62 temp status `'finalized'` string never emitted.
- F-63 `disputeState` type narrower on admin.
- F-49 backend `error.code` ignored by client.
- F-61 `PORT` 80 vs 3000 dev mismatch.
- (None method/path-level — endpoint matrix is 100% aligned.)

## Data Model Mismatches

See SYSTEM_DOCUMENTATION.md §19 (integration section) for the full matrix. Key mismatches:
- Contract: `hash` not persisted (F-60); dispute specifics dropped (F-32); `disputeState`/resolution fields absent from Isar model.
- User: `language` ignored by Flutter (F-33).
- SupportAttachment `size` present backend-only; SupportThread `user` omitted from mobile payload.
- Backend `Message.js`/`Media.js` dead models shadow embedded-array design (F-20/INT I-07).

## Missing Validation

- No pagination/limit/sort-param validation: `/contracts/list`, `/media/all`, `/admin/disputes` (F-14).
- `verifyContract` hash: length/format/trim/normalization, non-constant-time (F-40).
- Contract/join/review-access encrypted fields: length-only, no ciphertext-format check (F-41).
- FCM token registration: no proof of possession, only format (F-03).
- Media: no magic-byte verification against declared type (F-42).
- Dispute reason: length-capped but stored/transmitted plaintext (F-12).

## Missing Authorization Checks

- None found for contract-scoped routes: all message/media/support/contract-mutation routes run `auth` + `requireActiveAccount` + `checkContractPermission`; `checkContractPermission` correctly scopes to participants; all `/admin/*` routes run `auth` + `adminAuth`.
- Residual gaps: admin gate falls back to custom claims when `ADMIN_EMAILS` unset (F-08); Firebase token revocation not checked (F-70); FCM token binding without ownership proof (F-03); `/user/*` not gated on verified/finalized accounts (F-43); `getReviewPublicKey` is intentionally auth-only (not a gap).

## Missing Rate Limits

Entire API surface. Explicit: `/contracts/create`, `/contracts/join`, `/contracts/sign`, `/messages/send`, `/media/send`, `/user/finalize`, `/user/fcm-token/register`, `/user/fcm-token/unregister`, `/support/*`, `/admin/analytics`, plus per-request `verifyIdToken` (F-02).

## Race Condition Candidates

1. FCM token move (pull-then-add, two statements) — `userController.js:223-230` / `auth.js:18-26` (F-03).
2. Support attachment cap (check-then-`$push`) — `supportController.js:237-257` (F-44).
3. `ensureSupportThread` concurrent upsert → E11000 → 500 — `supportController.js:62-68` (F-45).
4. `disputeContract` vs `resolveDispute` interleave — resolution record wiped (F-11).
5. Cloudinary orphan if process crashes between upload and `$push` — cleanup only in catch (`mediaController.js:86-90`); partially unavoidable, noted.
6. Analyzed and found to converge (not flagged): `acceptContract` (`contractController.js:694-754`), `joinContract` reservation (`:329-347`), `signContract` (`:459-471`), `finalizeTempContract` deterministic `_id` + E11000 retry (`:130-159`), `grantReviewAccess` single-document-serialized.
7. `finalizeTempContract` ignores `expiresAt` — expired-but-signed invitations can still finalize via GET (F-13).

## Potential User Abuse Cases

1. Mass account + temp-contract creation (F-02, F-35, F-36).
2. Unbounded embedded-array document-corruption DoS via ~1,900 messages (F-01).
3. MongoDB/Cloudinary storage exhaustion with no per-user quota (F-36).
4. FCM push interception/hijack + push flood (F-03, F-36).
5. Pre-join participant-name + `detailsHash` enumeration (F-39).
6. MIME spoofing by extension (F-42).
7. Unverified-account write surface on `/user/*` (F-43).

## Production Configuration Risks

- `ADMIN_EMAILS` / `ADMIN_REVIEW_PUBLIC_KEY` unset ⇒ admin gate degraded + review-key 503 (F-08).
- Wide-open CORS + `X-Powered-By` (F-68); no `helmet`.
- No rate limiting (F-02); no request timeouts/graceful shutdown/crash handlers (F-15); minimal health now (F-15).
- Backend `.env` + `serviceAccountKey.json` real credentials on disk; admin review private key in repo dir (F-10, F-28, F-71).
- Lazy Cloudinary validation + localhost Mongo fallback (F-69).
- Admin prod fallbacks to production API/Firebase (F-29); no deploy manifests; admin URL vs backend doc mismatch (F-64).
- Node floor/`vinext` beta on admin (F-65).
- Deploy-host facts (Render vs Leapcell; whether env vars are set) are `Needs verification` — set `ADMIN_REVIEW_PUBLIC_KEY` and confirm on the actual host.

## Recommended Fix Order

**Phase 0 — Deploy blockers (do first, no code):**
1. Set `ADMIN_EMAILS` and `ADMIN_REVIEW_PUBLIC_KEY` in the backend hosting env (F-08); confirm the admin review public key matches `YACK-Admin/admin-review-public-key.txt` (F-71).
2. Redeploy backend with committed `fc8f841`/`c3bca67` state (removes the admin page's earlier review-key coupling) and verify `/admin/me` + `/support/review-key`.
3. Remove the uncommitted `[adminAuth-debug]` logging (F-07) before/with that redeploy.
4. Rotate the Atlas/Cloudinary/Firebase credentials and delete `src/config/serviceAccountKey.json` (F-10, F-28); move the admin RSA key out of the repo dir (F-71).

**Phase 1 — Abuse/DoS hardening (backend):**
5. Add `express-rate-limit` per-user + per-IP (F-02).
6. Cap embedded arrays atomically and apply the same guard to support messages (F-01, F-44).
7. Add per-user quotas (F-36); mass-account throttle (F-35); verified-email gate on `/user/*` (F-43).
8. Reject FCM body-token auto-registration; require explicit register with ownership proof; atomic move; index + cap tokens (F-03).

**Phase 2 — Data protection:**
9. Migrate Isar sync to ciphertext-at-rest; gate UI on `DecryptedKeyCache.isUnlocked` (F-04, F-17).
10. Wire media encryption or signed Cloudinary URLs; then delete dead `cryptoHandler.js` (F-05).
11. Reset admin decrypted state on sign-out; session-scoped key lifecycle with versioned review key and round-trip test (F-06, F-21, F-53).
12. Verify `contentHash`/`detailsHash` on decrypt paths (F-18).

**Phase 3 — Correctness and state machine:**
13. Reject dispute-after-resolved or preserve resolution record append-only (F-11).
14. Fix GET-side-effects + `expiresAt` finalization guard (F-13); fix temp-status auth requirement for cold joins (F-34).
15. Add pagination to the three list endpoints (F-14); fix accept-status persistence (F-31); emit `mediaPath` in FCM payloads (F-30).

**Phase 4 — Reliability/quality:**
16. Graceful shutdown, health probes, Mongo-gated listen, timeouts (F-15); structured logging + admin audit stream (F-47); indexes (F-46).
17. Background-isolate crypto in Flutter (F-19, F-20); fix notifications lifecycle (F-48); error-code surfacing (F-49).
18. Admin: abort/race-safe requests + inline resolve errors + Support view (F-23, F-26, F-24); confirmation flows (F-57).
19. Dependency hygiene: prune admin deps + mobile unused packages, commit `pubspec.lock`, consolidate storage (F-58, F-38).
20. Add regression tests for authorization/dispute/concurrency surface (F-16).

**Phase 5 — Cleanup:**
21. Remove dead models/endpoints/hardcoded values documented above; align docs (F-66); strip debug prints (F-37); CORS allowlist + helmet (F-68); env validation at boot (F-69).

---

*Document generated from the five workstream audit reports (backend, mobile, admin, cross-repo integration, security/secrets/deploy). Cross-validated by re-reading the primary evidence for the High-severity cluster. Items marked `Needs verification` could not be confirmed from the checked-out code (see individual findings).*