# YACK frontend/backend integration audit

Audit date: 2026-09-07  
Repositories: `YACK` (Flutter) and `YACK-Backend` (Node/Express/MongoDB)  
Status: audited, repaired, and exercised against the configured live development services

## Executive result

The main reason normal app actions appeared non-functional was a dead hardcoded API host. The Android release manifest also lacked the internet permission, and several mutations could be blocked by FCM token retrieval or reported as failed after their database writes had already succeeded.

The development app now targets the local backend automatically, release builds require an explicit backend URL, and the backend contract, account, messaging, media, and notification paths have been aligned with the Flutter client. A two-user live integration test passed through Firebase Auth, MongoDB, and Cloudinary.

The original audit requested an investigation-only backend review. The user subsequently and explicitly authorized backend repairs, so the resolved backend findings below were implemented after that authorization.

## Verification performed

- Flutter unit/service tests: 119 pass.
- Flutter analyzer: no compile errors; remaining findings are generated Isar warnings and legacy naming/logging/deprecation lints.
- Android debug APK: builds successfully.
- Backend deterministic tests: 17 pass; the environment-gated live test is skipped during the ordinary suite.
- Live integration: 1 pass. It created two verified Firebase users, finalized both profiles, created and joined an invitation, rejected a mismatched terms hash, signed both sides, listed the final contract, sent and read an encrypted message, uploaded and read a real Cloudinary image, accepted from both sides, rejected a post-completion dispute, cancelled a second invitation, then removed all test users/data/media.

## API contract matrix

| Workflow | Flutter request | Backend route | Result |
| --- | --- | --- | --- |
| Finalize account | `POST /user/finalize` | `userRoutes` → `finalizeAccount` | Aligned; verified email and complete key bundle required |
| Profile/read key bundle | `GET /user/profile` | `getProfile` | Aligned, including Mongo user ID, salt, IV, and language |
| Update profile/language | `PUT /user/profile` | `updateProfile` | Aligned |
| Change encrypted key | `PUT /user/private-key` | `updatePrivateKey` | Aligned; ciphertext, salt, and IV required |
| Notification device | `POST /user/fcm-token/register`, `/unregister` | matching user routes | Aligned |
| Create invitation | `POST /contracts/create` | `createContract` | Aligned, including `detailsHash` |
| Inspect invitation | `GET /contracts/temp/status?tempID=…` | `getTempContractStatus` | Added and aligned |
| Join invitation | `POST /contracts/join` | `joinContract` | Aligned; hash and terms integrity enforced |
| Sign invitation | `POST /contracts/sign` | `signContract` | Aligned and idempotent |
| Cancel invitation | `DELETE /contracts/temp/:tempID` | `cancelTempContract` | Added and aligned |
| List contracts | `GET /contracts/list` | `getContracts` | Aligned; caller receives only its encrypted envelope |
| Accept/dispute | `POST /contracts/accept`, `/dispute` | matching controllers | Aligned and state-guarded |
| Verify hash | `GET /contracts/verify?contractId=…&hash=…` | `verifyContract` | Aligned |
| Send/read messages | `POST /messages/send`, `GET /messages/all` | matching message routes | Aligned; caller-specific ciphertext returned |
| Send/read media | `POST /media/send`, `GET /media/all`, `/media/get` | matching media routes | Aligned; MIME, size, metadata, and URL shape verified |

## End-to-end traces

### Account creation and restoration

Sign-up screen → `AuthService.signup` → Firebase Email/Password account → automatic verification email → confirmation polling → forced fresh Firebase ID token → account setup screen → `InitAccountService` generates keys → `POST /user/finalize` → verified-token check and Mongo user completion → profile cache stores the Mongo user ID and encrypted key bundle → in-memory private-key unlock → authenticated home.

### Create, share, join, and sign

Create screen validates RSA byte limits and price → encrypts each field for the creator → computes SHA-256 terms hash → `POST /contracts/create` → Mongo temporary invitation → share screen places plaintext review terms, invitation ID, join secret, and terms hash in QR → scanner recomputes hash and compares it with both QR and `GET /contracts/temp/status` → review screen → encrypts the same terms for the joining party → atomic `POST /contracts/join` → each participant uses idempotent `POST /contracts/sign` → deterministic final contract creation → polling observes `completed` even without push → awaited contract sync confirms the final ID in Isar → success/home.

### Messaging and attachments

Agreement screen → RSA byte-limit check → encrypt message separately for sender and recipient and hash plaintext → `POST /messages/send` → atomic Mongo array append → success response → best-effort push → `GET /messages/all` returns only the caller's ciphertext → local decryption and Isar sync. Attachments follow file selection → 6 MB client guard/MIME detection → Base64 request → server validation → Cloudinary upload → atomic media metadata append → URL/metadata response → Isar sync.

### Acceptance and dispute

Agreement confirmation → `ContractStateCubit` → `POST /contracts/accept` or `/dispute` → membership check → conditional atomic state update → persisted dispute reason/timestamp or acceptance flag → best-effort push → frontend refetches the authoritative contract state.

### Logout and notifications

Settings logout → obtain current FCM token → authenticated unregister request → local Firebase token deletion → Firebase sign-out → decrypted key cache, profile cache, contracts, messages, media, and notification data cleared. Authenticated startup registers the current token and listens for token rotation.

## Findings resolved in this pass

### F-01 — Dead API destination made core features unusable

**Severity:** Critical  
**Confidence:** Confirmed Bug  
**Location:** `lib/logic/services/network/http_handler.dart`; frontend `README.md`; backend `SETUP.md`  
**Problem:** The app defaulted to `https://yack.leapcell.app`, which did not respond during verification.  
**Why it matters:** Every backend-backed feature timed out or failed, matching the report that several unrelated actions did nothing.  
**Failure scenario / reproduction:** Launch the prior build and perform any profile, contract, message, or media request while using the hardcoded host.  
**Evidence:** Direct requests to the old host timed out; the configured local backend returned HTTP 200 and passed the live workflow.  
**Recommended fix:** Implemented. Development selects the correct emulator/localhost URL; production requires `API_BASE_URL` so a dead URL cannot be silently shipped.

### F-02 — Android production manifest omitted network permission

**Severity:** Critical  
**Confidence:** Confirmed Bug  
**Location:** `android/app/src/main/AndroidManifest.xml`  
**Problem:** `INTERNET` existed only in development-specific manifests.  
**Why it matters:** A release APK could not perform any network request even with a valid server URL.  
**Failure scenario / reproduction:** Build a release APK from the previous manifest and invoke any Firebase/backend network action.  
**Evidence:** The main manifest had no internet permission.  
**Recommended fix:** Implemented by adding the permission to the main manifest; debug/profile allow cleartext only for local development.

### F-03 — Normal sign-up did not send verification mail and reused an unverified token

**Severity:** High  
**Confidence:** Confirmed Bug  
**Location:** `lib/logic/services/auth/auth_service.dart`; backend `src/controllers/userController.js`  
**Problem:** The first email was sent only after tapping Resend. After verification, the user record was reloaded but the ID token used by `/user/finalize` could retain `email_verified: false`.  
**Why it matters:** New users could be stranded before account/key setup or receive a 403 immediately after successful verification.  
**Failure scenario / reproduction:** Sign up, wait for an email without tapping Resend, or verify and immediately finalize using the cached token.  
**Evidence:** `signup` previously created only the Firebase user; `confirmAccount` did not force-refresh the ID token while the backend authorizes from that token claim.  
**Recommended fix:** Implemented. Initial delivery is attempted automatically with Resend recovery, and successful confirmation refreshes the ID token.

### F-04 — Push-token failures blocked ordinary API writes

**Severity:** High  
**Confidence:** Confirmed Bug  
**Location:** `lib/logic/services/network/http_handler.dart`; backend `src/utils/sendNotification.js`  
**Problem:** Each write waited for `FirebaseMessaging.getToken()` without recovery, and push delivery failures could escape after database mutations.  
**Why it matters:** Contracts/messages/media could fail when notification permissions or FCM were unavailable; committed actions could be shown as failures and then duplicated on retry.  
**Failure scenario / reproduction:** Deny notification setup or make FCM unavailable, then create/sign/send.  
**Evidence:** FCM token acquisition and notification delivery were in the primary mutation failure path.  
**Recommended fix:** Implemented. Token acquisition and server delivery are best effort; core responses depend on persistence, not push.

### F-05 — Business routes accepted incomplete or unverified accounts

**Severity:** High  
**Confidence:** Confirmed Bug  
**Location:** backend `src/middleware/requireActiveAccount.js` and contract/message/media routes  
**Problem:** Authentication created placeholder Mongo users, while business routes did not consistently require verified email and initialized encryption keys.  
**Why it matters:** Operations could create records that could not later be decrypted or attributed to a fully initialized account.  
**Failure scenario / reproduction:** Obtain a Firebase token, skip `/user/finalize`, and invoke contract/message/media routes.  
**Evidence:** The old route stacks used auth/membership checks but no complete-account guard.  
**Recommended fix:** Implemented with one reusable verified-and-complete account middleware on all business routes.

### F-06 — Participants could sign different plaintext terms

**Severity:** High  
**Confidence:** Confirmed Bug  
**Location:** `create_contract.dart`, `shareContract.dart`, `scan_contract.dart`, temp contract service; backend contract controller/model  
**Problem:** Each participant supplied its own encrypted envelope, but the joining flow did not prove that both envelopes represented the same reviewed title, description, and price.  
**Why it matters:** The final record could bind the parties to different plaintext.  
**Failure scenario / reproduction:** Alter the QR terms or join payload before user B encrypts its envelope.  
**Evidence:** The backend formerly stored but did not require/compare a canonical terms digest during join.  
**Recommended fix:** Implemented with the same normalized SHA-256 digest in creator storage, QR review, pre-join status, and atomic join validation.

### F-07 — Contract completion depended on push and invitations could be abandoned live

**Severity:** High  
**Confidence:** Confirmed Bug  
**Location:** share/scan screens, temp contract service; backend temp status/cancel routes and model  
**Problem:** The UI waited for FCM to learn that another party joined/signed, and leaving the creator flow did not revoke the invitation.  
**Why it matters:** Disabled/delayed push left both users stuck; abandoned QR codes remained joinable.  
**Failure scenario / reproduction:** Disable notifications during join/sign, or leave the share screen and later scan the old QR.  
**Evidence:** No authoritative temp-status or cancellation endpoints existed in the original route map.  
**Recommended fix:** Implemented with three-second status polling, recoverable lifecycle states, TTL, and creator-only idempotent soft cancellation.

### F-08 — Join and finalization were vulnerable to concurrent duplicates

**Severity:** High  
**Confidence:** Potential Risk  
**Location:** backend `src/controllers/contractController.js`, `Contract.js`, `TempContract.js`  
**Problem:** Read-then-write reservation/signing allowed concurrent joiners or retries to race, and final contract creation lacked a stable idempotency key.  
**Why it matters:** Two users could believe they joined, or duplicate final records could be materialized after retries.  
**Failure scenario / reproduction:** Submit simultaneous join requests or both signatures while retrying a lost response.  
**Evidence:** The prior implementation made decisions from stale loaded documents before separate saves/creates.  
**Recommended fix:** Implemented using conditional Mongo updates, same-user retry handling, a deterministic final `_id`, and a unique `sourceTempContract` index.

### F-09 — Concurrent messages/media could overwrite each other

**Severity:** High  
**Confidence:** Potential Risk  
**Location:** backend message/media controllers  
**Problem:** Appending to embedded arrays through loaded documents and saving can lose a concurrent append.  
**Why it matters:** Evidence or conversation entries could disappear without either client receiving an error.  
**Failure scenario / reproduction:** Both participants send at nearly the same moment and the second save is based on a stale array.  
**Evidence:** The former controllers used document mutation/save for the arrays.  
**Recommended fix:** Implemented with atomic `$push`; failed media persistence also deletes the orphaned Cloudinary upload.

### F-10 — Several screens announced success before confirming synchronized state

**Severity:** Medium  
**Confidence:** Confirmed Bug  
**Location:** share/scan/auth flows and contract synchronization services  
**Problem:** Navigation and success messages could run after starting, but not awaiting or verifying, contract/profile synchronization.  
**Why it matters:** Users could land on Home with no new agreement or with the wrong participant decryption identity.  
**Failure scenario / reproduction:** Slow or failed list/profile request immediately after final signing/login.  
**Evidence:** The prior flows launched background sync and navigated unconditionally.  
**Recommended fix:** Implemented. Critical flows await the authoritative fetch and confirm the expected final external ID before success.

### F-11 — Device notification tokens were not managed across login/logout/rotation

**Severity:** Medium  
**Confidence:** Confirmed Bug  
**Location:** notification/user services and settings; backend auth/user controller  
**Problem:** Tokens were opportunistically attached to requests but were not explicitly rotated or removed from an old account.  
**Why it matters:** A shared device could receive another account's contract notifications, and stale tokens accumulated.  
**Failure scenario / reproduction:** Log out of account A, log into B on the same install, then trigger a notification for A.  
**Evidence:** There were no register/unregister routes or token-refresh listener.  
**Recommended fix:** Implemented with explicit lifecycle endpoints, cross-account token transfer, refresh registration, invalid-token pruning, and logout unregistration.

### F-12 — Restored sessions could lose the Mongo participant identity

**Severity:** High  
**Confidence:** Confirmed Bug  
**Location:** user/account cubits and services; contract sync/decryption  
**Problem:** Profile restoration did not consistently cache the backend Mongo user ID used to choose the user's encrypted contract envelope.  
**Why it matters:** After reinstall or cache loss, the app could select the other party's ciphertext and fail decryption.  
**Failure scenario / reproduction:** Sign in on a clean install to an existing complete account and sync contracts.  
**Evidence:** Profile responses included an ID but the earlier cache paths omitted it.  
**Recommended fix:** Implemented in all profile cache paths, with account readiness awaited before contract sync.

### F-13 — Media payload and response assumptions were inconsistent and weakly validated

**Severity:** High  
**Confidence:** Confirmed Bug  
**Location:** Flutter media service; backend media controller/handler/model  
**Problem:** MIME metadata, size limits, filename sanitization, Cloudinary URL persistence, cleanup, and returned record shape were not consistently enforced.  
**Why it matters:** Valid uploads could fail to display, oversized requests could exhaust resources, and failed database writes could leave paid-storage orphans.  
**Failure scenario / reproduction:** Upload an unsupported/large file, retrieve a legacy resource, or force persistence failure after upload.  
**Evidence:** Frontend/backend payload handling and stored fields did not previously share one explicit contract.  
**Recommended fix:** Implemented with a common 6 MB ceiling, supported MIME inference, sanitized names, metadata/secure URL storage, legacy lookup, and cleanup. Verified with mocked and live Cloudinary tests.

### F-14 — Network failures had no bounded, actionable outcome

**Severity:** Medium  
**Confidence:** Confirmed Bug  
**Location:** `lib/logic/services/network/http_handler.dart`  
**Problem:** Requests could wait indefinitely or surface low-level client exceptions.  
**Why it matters:** Loading controls appeared stuck and users could not distinguish invalid data from an unreachable backend.  
**Failure scenario / reproduction:** Stop the backend or use the dead host while performing a mutation.  
**Evidence:** The common request layer lacked a uniform timeout/connection mapping.  
**Recommended fix:** Implemented with a 20-second bound and clear server-timeout/connection messages.

### F-15 — State evidence and timestamps were incomplete

**Severity:** Medium  
**Confidence:** Confirmed Bug  
**Location:** backend contract model/controller; Flutter contract models/home  
**Problem:** Dispute reasons were transient, server timestamps could be replaced locally, and UTC values were displayed without explicit local conversion.  
**Why it matters:** Users could lose the reason for a dispute or see misleading activity ordering/dates.  
**Failure scenario / reproduction:** Dispute with a reason, resync, or view a contract around a timezone date boundary.  
**Evidence:** The prior schema lacked dispute evidence fields and sync code regenerated some timestamps.  
**Recommended fix:** Implemented by persisting reason/time per participant, preserving server times, and converting for display.

### F-16 — Unexpected backend errors exposed implementation messages

**Severity:** Low  
**Confidence:** Confirmed Bug  
**Location:** backend `src/index.js` global error handler  
**Problem:** Generic 500 responses included `err.message`.  
**Why it matters:** Internal database/provider details could be disclosed to clients.  
**Failure scenario / reproduction:** Trigger an error that reaches the global middleware.  
**Evidence:** The response explicitly included a `details` field from the thrown error.  
**Recommended fix:** Implemented; details remain server-side only.

## Remaining risks and deliberate limitations

### R-01 — A production API must still be deployed and supplied to the release build

**Severity:** High  
**Confidence:** Confirmed Bug (operational state)  
**Location:** deployment environment; frontend `API_BASE_URL` build define  
**Problem:** The previous public deployment is unavailable. The repaired backend currently works locally, but code changes alone cannot create a new hosted endpoint.  
**Why it matters:** A release APK has no reachable API until deployment configuration is completed.  
**Failure scenario / reproduction:** Build release without `--dart-define=API_BASE_URL=https://…`.  
**Evidence:** The old host timed out; local/live validation succeeded.  
**Recommended fix:** Deploy `YACK-Backend` using `SETUP.md`, set its environment variables, then build the app with that HTTPS URL.

### R-02 — Attachments are not end-to-end encrypted

**Severity:** High  
**Confidence:** Potential Risk  
**Location:** Flutter media service; backend media handler/Cloudinary storage  
**Problem:** Text and messages use per-party encryption, while attachment bytes are uploaded as readable image/video data.  
**Why it matters:** The storage provider or anyone with an exposed asset URL may be able to read contract evidence.  
**Failure scenario / reproduction:** A sensitive attachment is uploaded and its Cloudinary asset or credentials are exposed.  
**Evidence:** The client Base64-encodes raw file bytes; no AES envelope or per-party wrapped key is generated.  
**Recommended fix:** Encrypt bytes client-side with a random symmetric key, wrap that key separately for both parties, store only ciphertext, and decrypt only on authorized clients.

### R-03 — Embedded message/media arrays have a long-term document-size ceiling

**Severity:** Medium  
**Confidence:** Potential Risk  
**Location:** backend `src/models/Contract.js`  
**Problem:** Every message and attachment record is embedded in one contract document. MongoDB documents have a finite maximum size.  
**Why it matters:** Very active/long-lived contracts can eventually reject new messages or media metadata.  
**Failure scenario / reproduction:** Accumulate enough encrypted messages/media entries for the contract document to reach the database document limit.  
**Evidence:** Both collections are schema arrays updated with `$push`.  
**Recommended fix:** Move messages/media to separate indexed collections keyed by contract ID.

### R-04 — Older messages cannot be paged after the newest window

**Severity:** Medium  
**Confidence:** Confirmed Bug  
**Location:** backend `getAllMessages`; Flutter `MessageService.getAll`  
**Problem:** The API returns only the newest bounded slice and exposes no before/cursor parameter.  
**Why it matters:** Once a conversation exceeds the selected limit, older entries cannot be retrieved by the app.  
**Failure scenario / reproduction:** Send more than 50 messages and attempt to scroll/load the earliest ones.  
**Evidence:** The query uses only `$slice: -limit`; the client has only `limit`.  
**Recommended fix:** Add stable cursor pagination using `(createdAt, _id)` and a load-older UI, ideally alongside separate message storage.

### R-05 — Direct RSA encryption intentionally limits each text field/message

**Severity:** Medium  
**Confidence:** Potential Risk  
**Location:** `lib/logic/services/auth/cryptoService.dart` and create/message UI  
**Problem:** RSA-OAEP can encrypt only a small plaintext, currently guarded at 190 UTF-8 bytes.  
**Why it matters:** Longer multilingual descriptions/messages are rejected even though the UI otherwise supports multiline content.  
**Failure scenario / reproduction:** Enter text whose UTF-8 encoding exceeds 190 bytes (Arabic/emoji reaches the limit faster).  
**Evidence:** `CryptoService.maxRsaPlaintextBytes` and UI checks enforce the limit.  
**Recommended fix:** Migrate text to hybrid encryption: AES-GCM for content plus RSA-wrapped AES keys for each participant. Preserve the current guard until migration is complete.

### R-06 — Broad collection endpoints do not paginate

**Severity:** Low  
**Confidence:** Potential Risk  
**Location:** backend contract list/media list and corresponding Flutter sync services  
**Problem:** Contract and media list endpoints return every matching record/entry.  
**Why it matters:** Accounts with many contracts or attachments will consume increasing response time and memory.  
**Failure scenario / reproduction:** Use one account for a large number of long-lived agreements with many media entries.  
**Evidence:** The queries have sorting but no cursor/limit contract.  
**Recommended fix:** Add cursor pagination while keeping incremental Isar synchronization.

## Conclusion

The core integration is now operational in development and the previously broken account, contract, notification, message, and media paths have runtime evidence behind them. The required operational next step is production deployment/configuration. The remaining code risks are longer-term architecture items rather than blockers for the repaired core workflow.
