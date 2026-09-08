# YACK — Operator Runbook

Operational guide for running the three-repository YACK system. This is the
document that turns the remaining external/blocked remediation items
(`REMEDIATION.md` → *Blocked External Actions*, `F-09`, `F-10`) into concrete
operator steps. Everything here requires your own service accounts.

Repositories:

| Repo | Purpose |
| --- | --- |
| `YACK` (Flutter) | Mobile app |
| `YACK-Backend` (Node/Express) | API + services |
| `YACK-Admin` (React/Vite/vinext) | Administrative dashboard |

---

## 1. Environment variables

### Backend (`YACK-Backend`, all provider-configured)

Fail-fast in `NODE_ENV=production`: the server refuses to boot when any
required variable is missing (`src/config/validateEnv.js`).

| Variable | Required | Notes |
| --- | --- | --- |
| `NODE_ENV` | prod only | `production` on the host; dev continues with warnings |
| `PORT` | no (default 80) | `3000` locally, `80` on the host |
| `MONGO_URI` | yes | Atlas connection string |
| `FIREBASE_PROJECT_ID` | yes* | *or a service-account JSON via `GOOGLE_APPLICATION_CREDENTIALS` |
| `FIREBASE_CLIENT_EMAIL` | yes* | Firebase service account |
| `FIREBASE_PRIVATE_KEY` | yes* | keep escaped `\n`; no implicit `serviceAccountKey.json` lookup |
| `CLOUDINARY_CLOUD_NAME` | yes (prod) | Cloudinary dashboard |
| `CLOUDINARY_API_KEY` | yes (prod) | Cloudinary API Keys |
| `CLOUDINARY_API_SECRET` | yes (prod) | Cloudinary API Keys |
| `ADMIN_EMAILS` | yes (prod) | comma-separated admin accounts |
| `ADMIN_REVIEW_PUBLIC_KEY` | yes (prod) | from `YACK-Admin` `scripts/generate-admin-review-key.mjs` |
| `CORS_ORIGINS` | yes (prod) | comma-separated browser origins; **fail-closed** — the deployed dashboard host must be listed |

### Admin dashboard (`YACK-Admin`, `.env.local` / host env)

Fail-fast: dev and build abort unless every variable is set — no fallback
values exist (`scripts/validate-env.mjs`).

| Variable | Notes |
| --- | --- |
| `VITE_FIREBASE_API_KEY` | YACK Firebase web config |
| `VITE_FIREBASE_AUTH_DOMAIN` | YACK Firebase web config |
| `VITE_FIREBASE_PROJECT_ID` | YACK Firebase web config |
| `VITE_FIREBASE_APP_ID` | YACK Firebase web config |
| `VITE_API_BASE_URL` | deployed backend base URL, no trailing slash |

### Mobile (`YACK`, build-time defines)

| Define | Value |
| --- | --- |
| `API_BASE_URL` | release/device builds: `https://<your-backend-url>`; Android emulator defaults to `http://10.0.2.2:3000`, desktop/web to `http://127.0.0.1:3000` |

---

## 2. Mongo credential rotation (F-10)

The host's current Mongo credentials fail Atlas authentication locally
(`bad auth`, error code 8000) — a strong sign the stored credentials belong to
the original author and must be rotated.

1. Log into **MongoDB Atlas** (your account).
2. **Database Access** → add a user (e.g. `yack-app`) with read/write on the
   YACK database (not `dbAdmin`/`clusterAdmin`).
3. **Network Access** → allow the production host IP (or a stable egress range).
4. Copy the new `mongodb+srv://yack-app:<password>@...` URI into the host env
   `MONGO_URI` **and** the local `.env` used for staging.
5. Redeploy and confirm `npm test` (unit suite) then the boot probe (section 4)
   succeed against the new URI.
6. Revoke/delete the old Atlas user once the app is confirmed green.
7. Record completion in `REMEDIATION.md` (F-10) only after the live smoke pass.

## 3. Review-key rotation (F-09/F-71-as-ops)

The review private key is the same key pair used to unlock case data for
support threads; the mobile app encrypts case-sharing shares to
`ADMIN_REVIEW_PUBLIC_KEY` (likely the original author's pair today).

To take ownership:

1. In `YACK-Admin`: `npm run generate:review-key`.
   - Private key → `~/.config/yack-admin/admin-review-private-key.pem`
     (outside the repo; back this up securely).
   - Public value → `admin-review-public-key.txt` (repo root; tracked).
2. Set backend `ADMIN_REVIEW_PUBLIC_KEY` to that public value and redeploy.
3. Verify a grant/decrypt round trip: open a case in the admin dashboard,
   select the new private key; the fingerprint badge must show `· verified`.
   Backend `/admin/me` and review-key smoke (section 4) must pass.
4. Note: user-granted shares encrypted to the **old** key become unreadable
   after rotation (there is no re-encryption path yet). Rotate once, early, and
   publish it — do not rotate routinely.
5. Any legacy Firebase/Cloudinary/Mongo credentials the original author once
   committed must be revoked/rotated in their respective consoles; this is a
   provider-side action only the account owner can perform.

## 4. Deployment smoke checklist

Run after every backend/deployment change.

1. **Boot gate:** with `NODE_ENV=production`, a missing required variable aborts
   at startup with the aggregated list (before Firebase/Mongo init) → exit 1.
   Confirm the host logs show a clean boot with all variables set.
2. **Health:** `GET /health` returns `200`.
3. **Admin auth:** `GET /admin/me` with an allowlisted admin Firebase token
   succeeds; a non-admin token is rejected.
4. **Review-key:** admin dashboard opens a granted case without `mismatch` in
   the fingerprint badge.
5. **CORS:** load the deployed admin dashboard from its own origin — network
   tab shows no CORS block (`CORS_ORIGINS` must include the dashboard origin).
6. **FCM:** trigger a backend event and confirm the mobile client receives it.
7. **Media:** upload a file from the mobile app; verify arrival in Cloudinary.
8. **Rate limits present:** a rapid burst is cut off with `429 RATE_LIMITED`.
9. **`trust proxy`:** verify the hop count matches the host topology; otherwise
   IP-based limits are wrong (see SETUP.md).
10. **Audit scan:** `npm audit` clean on `YACK-Admin`, no credentials in
    tracked files (`rg` over each repo for the variable names is a quick check).

## 5. Regression entry points

| Repo | Commands |
| --- | --- |
| Backend | `npm test`, `node --check src/...` on touched files |
| Mobile | `flutter analyze`, `flutter test` |
| Admin | `npm run lint`, `npm test`, `npm run build` |

## 6. Current known gaps (operational)

- F-04 (mobile data-at-rest envelope) is **deferred**: the lock-gate hides
  plaintext without an in-memory key and Isar is cleared on logout. A full
  at-rest envelope requires a coordinated Isar schema migration (also covers
  F-32/F-51/F-60).
- F-05 (client-side media encryption) remains pending — attachments rely on
  the review-grant gating (F-55), not end-to-end encryption.
- Hosted deployment of the admin dashboard (currently Render) is
  operator-owned; no manifest is committed by design (fail-fast env validation
  keeps misconfiguration out of production).