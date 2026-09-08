# YACK Frontend Screens Reference

> Purpose: complete inventory of every frontend screen and component in the YACK Flutter app, written as a design prompt for reimplementing pages with Google Stitch / GPT-5.6. Describes layout, elements, states, navigation, and incomplete areas.

---

## 1. Navigation Shell

### Root (BottomNavBar)
- **File:** `lib/presentation/screens/root.dart`
- **Layout:** Adaptive shell using `IndexedStack` to preserve state across 4 tabs:
  1. **Contracts** (home) - `Icons.description_outlined`
  2. **Scan** - `Icons.qr_code_scanner_outlined`
  3. **Notifications** - `Icons.notifications_none_outlined` (with unread badge via Isar stream)
  4. **Settings** - `Icons.manage_accounts_outlined`
- **Responsive behavior:** `< 840px` → `NavigationBar` (bottom bar); `>= 840px` → `NavigationRail` (left sidebar with rail)
- **Badge:** Live unread count from `isar.appNotifications` stream
- **Navigation:** Tabs switch via `setState`; no nested navigation within tabs

---

## 2. Auth Flow Screens

All auth screens share `YackAuthScaffold` — a centered card layout with brand mark, icon chip, title, subtitle, form body, and optional footer link. Max width 460px.

### 2.1 Onboarding (Welcome)
- **File:** `lib/presentation/screens/welcome.dart`
- **Route:** `/welcome`
- **Layout:** Top bar with `YackBrand` + "Login" link. `PageView` with 3 pages, each showing a workflow preview illustration (icon + skeleton UI), title, subtitle. Bottom: progress bars + "Next"/"Get Started" button + "Skip" text.
- **Pages:** Create contracts (green), Secure verification (brass), Track agreements (blue)
- **States:** Page 1-3, last page shows "Get Started" instead of "Next"
- **Navigation:** Sets `didFirstTime = true` in Hive, then → `/signup`

### 2.2 Sign Up
- **File:** `lib/presentation/screens/auth/signup.dart`
- **Route:** `/signup`
- **Form fields:** Email, First name, Last name, Password (min 8), Confirm password
- **Elements:** `CustomTextFormField` with icons, validators, autofill hints. Footer: "Already have account? Login" link.
- **States:** Loading (button spinner), Success → `/confirm`, Error (snackbar)
- **Navigation:** → `/confirm` on success, → `/login` via footer link

### 2.3 Login
- **File:** `lib/presentation/screens/auth/login.dart`
- **Route:** `/login`
- **Form fields:** Email, Password
- **Elements:** "Forgot password?" link, `YackNotice` (neutral tone) about encryption unlock, footer: "Don't have account? Sign up"
- **States:** Loading, Success → `/decrypt-account`, Unverified → `/confirm`, Error (snackbar)
- **Navigation:** → `/decrypt-account`, → `/confirm`, → `/forgot-password`

### 2.4 Confirm Account
- **File:** `lib/presentation/screens/auth/confirm.dart`
- **Route:** `/confirm`
- **Elements:** `YackNotice` showing verification email, "Verified Email" button, "Resend Email" text button, footer: "Use another account" link
- **States:** Loading, Success → `/init-account`, Unverified (warning snackbar), Error
- **Navigation:** → `/init-account` on success, → `/login` via switch account

### 2.5 Init Account (Create Encryption Key)
- **File:** `lib/presentation/screens/auth/initAccountScreen.dart`
- **Route:** `/init-account`
- **Purpose:** First-time setup — creates local encryption key after email verification
- **Form fields:** First name + Last name (only if missing), Encryption password (min 12 chars, stronger than login), Confirm password, CheckboxListTile for recovery acknowledgment
- **Elements:** `YackNotice` (warning tone) about key importance, "Use another account" footer
- **States:** Loading, Success → `/home`, Error
- **Validation:** Password min 12, must check acknowledgment checkbox

### 2.6 Decrypt Account (Unlock Key)
- **File:** `lib/presentation/screens/auth/decryptAccountScreen.dart`
- **Route:** `/decrypt-account`
- **Purpose:** Returning user sign-in — unlocks encrypted private key with encryption password
- **Form fields:** Encryption password (with helper text "not your login password")
- **Elements:** `YackNotice` showing email being unlocked, "Use another account" footer
- **States:** Loading, Success → `/home`, ProfileMissingKeys → `/init-account`, Error
- **Navigation:** → `/home` on success, → `/init-account` if no keys

### 2.7 Forgot Password
- **File:** `lib/presentation/screens/auth/forgetPassword.dart`
- **Route:** `/forgot-password`
- **Form fields:** Email
- **Elements:** `showBack = true` on scaffold, "Back to Login" footer
- **States:** Loading, Success (shows positive `YackNotice` + "Back to Login" button), Error
- **Navigation:** → `/login`

---

## 3. Home / Contracts List

### 3.1 ContractsScreen (Home)
- **File:** `lib/presentation/screens/home.dart`
- **Layout:** `CustomScrollView` with pull-to-refresh
- **AppBar:** `YackBrand` + sync button (shows spinner during refresh)
- **Content:**
  - `YackPageHeading`: eyebrow = greeting + first name, title = "Contracts", subtitle = total count, trailing = "Add Contract" button (wide only)
  - Search `TextField` with clear button
  - Horizontal scrollable filter chips: All / Open / Completed / Disputed (with counts)
  - `YackSectionHeading` showing filter name + count
  - `SliverList` of `ContractCard` widgets
- **FAB:** "Add Contract" (narrow screens only), hidden on wide
- **Empty states:** `YackEmptyState` for no contracts, no matching contracts (with "Clear Filters" action)

### 3.2 ContractCard
- **File:** `lib/presentation/screens/home.dart`
- **Layout:** Horizontal card with left colored status bar (4px), content area, right chevron or menu
- **Content:** Title (max 2 lines), `StatusBadge`, description (max 2 lines), metadata row: price, party name, date
- **States:** `StatusBadge` colors per contract status. Closed contracts show popup menu "Hide from Device" (with undo snackbar)
- **Tap:** → `/contract/view` with `contract.id` argument
- **Hidden contracts:** Stored in Hive `hiddenContractIds`, filtered out on load

---

## 4. Contract Flow Screens

### 4.1 Create Contract
- **File:** `lib/presentation/screens/create_contract.dart`
- **Route:** `/contract/create_contract`
- **Form fields:** Title, Description, Price (decimal)
- **Elements:** `PopScope` with discard-draft dialog, price validation (min 100), SHA-256 hash of details shown during processing
- **Navigation:** After creation → `/contract/scan_contract` (share via QR) or home

### 4.2 Share Contract (QR Invitation)
- **File:** `lib/presentation/screens/shareContract.dart`
- **Route:** (navigated from create flow)
- **Elements:** QR code via `qr_flutter`, waiting/processing states, creator sign-off flow after other party joins
- **States:** Generating QR, showing QR, waiting for other party, contract created

### 4.3 Scan Contract
- **File:** `lib/presentation/screens/scan_contract.dart`
- **Route:** `/contract/scan_contract` (also embedded in BottomNavBar tab)
- **Elements:** `MobileScanner` camera view, processing/waiting states, pre-join review via `AcceptDeclineContract`
- **States:** Scanning, processing, reviewing contract details, waiting for confirmation
- **Self-QR rejection:** Prevents scanning own QR code via `creatorId` check

### 4.4 Accept / Decline Contract
- **File:** `lib/presentation/screens/acceptDeclineContract.dart`
- **Layout:** Read-only document review of contract terms
- **Elements:** Title, description, price, parties. Translate feature behind privacy-consent dialog. Accept and Decline buttons
- **Logic:** `isUserA` flag determines party perspective
- **States:** Viewing, accepting, declining, already accepted/declined

### 4.5 Subscription
- **File:** `lib/presentation/screens/subscription.dart`
- **Route:** `/subscription`
- **Layout:** Static preview of plan tiers
- **Elements:** `YackNotice` warning that billing is not yet simulated. Close button
- **Note:** No actual billing integration — placeholder only

---

## 5. Contract Agreement (Chat/Activity)

### ContractAgreement
- **File:** `lib/presentation/screens/contract_agr/contract_agreement.dart`
- **Route:** `/contract/view` with `contractId` argument
- **Layout:** Three-section vertical layout:
  1. **Status section** (top): Contract status icon + text, price, accept/dispute buttons
  2. **Messages list** (middle): Combined messages + media, sorted by time, auto-scroll
  3. **Chat input bar** (bottom): Attachment button, text field, send button
- **Message bubbles:** Sent (right, primary color) vs received (left, surface color). Avatar circle with initial. Timestamp. Encrypted content decrypted locally.
- **Media bubbles:** Image preview (network or local file), file placeholder with type icon (PDF, video, doc, etc.), filename, timestamp
- **Attachment picker:** Bottom sheet with Camera, Gallery, Video options
- **Status section logic:**
  - Shows accept + dispute buttons when contract is `active` or `pending` and not yet accepted by current user
  - "Waiting for other to accept" state when current user accepted but other hasn't
  - Accept/Dispute both show confirmation dialogs (dispute has optional reason field)
- **Contract details sheet:** Bottom sheet showing title, other party, price, description
- **Notifications:** Listens to FCM `ContractNotificationEvent` for real-time accept/dispute/message/media updates
- **Encryption:** Messages encrypted with RSA (sender + recipient public keys), decrypted locally with private key from `DecryptedKeyCache`
- **Max attachment:** 6 MB
- **Empty states:** Locked (no private key) or no messages yet

---

## 6. Notifications (Activity)

### NotificationsPage
- **File:** `lib/presentation/screens/notifications.dart`
- **Layout:** `ListView` with day-grouped notifications
- **AppBar:** Title changes in selection mode (shows count). Actions: mark all read, select mode toggle
- **Notification rows (`_ActivityRow`):**
  - Left icon (type-colored chip), title (bold if unread), body text, time
  - Unread dot indicator or chevron if navigable
  - Selection mode: checkboxes, bottom bar with "Mark as Read" + "Delete" buttons
- **Grouping:** Today, Yesterday, or DD/MM/YYYY
- **Tap behavior:**
  - With `contractId` → `NotificationRouterService.navigateToContract`
  - With `tempId` only → snackbar hint ("invite activity hint")
  - Marks as read on open
- **Delete:** Confirmation dialog, removes from Isar, snackbar with count
- **Notification types:** contractJoin, contractSign, contractAccept, contractDispute, contractMessage, contractMedia, unknown — each with distinct icon + color

---

## 7. Profile

### ProfileScreen
- **File:** `lib/presentation/screens/profile.dart`
- **Route:** `/profile`
- **Layout:** Scrollable `YackContent` (maxWidth 680)
- **Sections:**
  1. `YackPageHeading`: "Identity & Security" title + subtitle
  2. **Profile Information:** `UserInfoHeader` card
  3. **Contracts Summary:** `ContractStatusSummary`

### UserInfoHeader
- **File:** `lib/presentation/widgets/profile/user_info_header.dart`
- **Layout:** Card with avatar initial + name + email + edit button, divider, two status rows
- **Status rows:**
  - Email verification: verified (green) or unverified
  - Key status: unlocked / locked / setup incomplete
- **Edit:** Opens `showEditNameDialog` from Hive box

### ContractStatusSummary
- **File:** `lib/presentation/widgets/profile/contract_status_summary.dart`
- **Layout:** Three `_SummaryRow` items: In Progress (orange), Closed (green), Disputed (red)
- **Data:** Live stream from Isar contracts, grouped by status

---

## 8. Settings

### SettingsScreen
- **File:** `lib/presentation/screens/settings.dart`
- **Layout:** Scrollable `YackContent` (maxWidth 760)
- **Sections:**
  1. **Account:** Profile, Password, Encryption Password
  2. **Preferences:** Appearance, Language, Notifications, Privacy
  3. **Plans & Support:** Plans Preview, Help/Support (disabled), About YACK
  4. **Logout:** `YackNotice` (neutral) about device-only logout + destructive `SecondaryActionButton`
- **Each setting item:** `SettingsIcon` (colored 40px chip) + title + subtitle + chevron. Appearance/Language show current value on right.
- **Bottom sheets:**
  - **Appearance:** Radio tiles (Light/Dark/System) via `SettingsSheet`
  - **Language:** Radio tiles (Arabic/English/French) with flag emojis, server-synced via `UserService`
  - **Notifications:** Info-only placeholder with `YackNotice` (warning)
  - **Privacy:** Info-only placeholder with `YackNotice` (neutral)
- **Logout flow:** Confirmation dialog → unregister FCM token → sign out → clear cached data → mark unauthenticated → navigate to `/login`

---

## 9. App Wrapper / Boot

### AppWrapper
- **File:** `lib/app_wrapper.dart`
- **Route:** `/` (initial)
- **Purpose:** Auth state listener that routes to the correct screen
- **Layout:** `YackBrand` + spinner + "Checking account" text
- **Routing logic:**
  - `UnverifiedUser` → `/confirm`
  - `AccountNotComplete` → `/init-account`
  - `AccountCompleteButLocked` → `/decrypt-account`
  - `Unauthenticated` + first time → `/welcome`
  - `Unauthenticated` + seen login → `/login`
  - `Unauthenticated` default → `/signup`
  - `Authenticated` → `/home`

### MyApp (App Config)
- **File:** `lib/app.dart`
- **Theme:** `AppTheme.lightTheme` / `AppTheme.darkTheme`, mode from Hive `theme` value (1=light, 2=dark, 3=system)
- **Locale:** From `TranslationHandler.locale`, supports en/ar/fr
- **Routes:** All named routes with `themedRoute` wrapper for system UI overlay style
- **Navigator key:** `NotificationRouterService.navigatorKey` for push-from-background

---

## 10. Design System

### YackUI Components (`lib/presentation/widgets/yack_ui.dart`)
- **YackBrand:** Product mark — green square with document icon + brass dot. Optional name text. Size prop (default 34).
- **YackContent:** Centering wrapper with `maxWidth` (default 760) and horizontal padding (20px)
- **YackPageHeading:** Eyebrow (small, primary color) + headline title + subtitle + optional trailing widget
- **YackSectionHeading:** Title (titleMedium) + caption (bodySmall) + optional action
- **YackNotice:** Colored callout with left border, icon, message. 4 tones: `neutral` (green bg), `positive` (green), `warning` (orange), `critical` (red bg, error color)
- **YackEmptyState:** Centered 72px icon + title + message + optional action button. Max width 420.
- **YackAuthScaffold:** Shared auth layout — brand back row, 52px icon chip, title, subtitle, form child, divider, footer

### Theme Tokens (`lib/presentation/theme/theme.dart`)
- **Brand colors:** yackGreen `0xFF0E6755`, yackGreenLight `0xFFE3F1EC`, yackBrass `0xFFB7791F`, yackInk `0xFF17231F`, yackBackground `0xFFF3F5F2`, yackGray `0xFF5C6963`, yackGrayLight `0xFFE7EBE8`, yackDivider `0xFFD9DFDB`
- **Dark surfaces:** darkBackground `0xFF101613`, darkSurface `0xFF171F1B`, darkSurfaceHigh `0xFF202A25`, darkText `0xFFF0F4F1`
- **Status colors:** statusGreen `0xFF17815F`, statusOrange `0xFFB96B14`, statusRed `0xFFB83B3B`, statusBlue `0xFF356B8C`, statusGray `0xFF68736E`
- **Spacing:** spaceXs=4, spaceSm=8, spaceMd=12, spaceLg=16, spaceXl=24, space2Xl=32, pagePadding=20, maxContentWidth=760
- **Radii:** radiusSm=6, radiusMd=10, radiusLg=14
- **Motion:** fast=120ms, normal=200ms, slow=300ms, ease=Curves.easeOutCubic
- **Typography:** Material3 text theme. Headings bold (w800), body medium (w400), labels semibold (w600-w700)
- **Component themes:** All Material3 components themed (buttons, inputs, cards, dialogs, sheets, chips, switches, navigation, etc.)

### Shared Widgets
- **StatusBadge:** Colored pill with icon + label per `ContractStatus`. Compact mode (icon only). Maps: active=green, accepted=blue, pending=orange, disputed=red, completed=blue, rejected=gray
- **PrimaryActionButton:** Full-width `FilledButton.icon`, 54px height, loading spinner state
- **SecondaryActionButton:** Full-width `OutlinedButton.icon`, 54px height, destructive mode (error color), loading spinner
- **CustomTextFormField:** `TextFormField` with label/hint, optional icon prefix, password toggle (animated visibility), directional text for email/number fields, helper text, multi-line support
- **SettingsCard:** Rounded bordered container for grouping setting items
- **SettingsItem:** Row with icon chip + title + subtitle + optional value + chevron
- **SettingsIcon:** 40px colored icon chip with alpha background
- **SectionHeader:** Small label with optional icon and color
- **SettingsSheet:** Generic modal bottom sheet with radio/switch tiles and optional apply button
- **MetricCard:** Dashboard tile with icon + value + label + optional trend badge
- **StatusCountTile:** Icon in circle + count + label, animated container

### Color Scheme Summary (Light)
- Primary: yackGreen (`0xFF0E6755`)
- On Primary: white
- Primary Container: `0xFFDCEDE7`
- Secondary: yackBrass (`0xFFB7791F`)
- Background: yackBackground (`0xFFF3F5F2`)
- Surface: white
- Surface Container: `0xFFF0F3F0`
- Outline: `0xFFD6DDD8`
- Error: statusRed (`0xFFB83B3B`)

### Color Scheme Summary (Dark)
- Primary: `0xFF58C5A5`
- On Primary: `0xFF082019`
- Background: darkBackground (`0xFF101613`)
- Surface: darkSurface (`0xFF171F1B`)
- Outline: `0xFF344039`
- Error: `0xFFFF8A86`

---

## 11. Known Incomplete / Placeholder Areas

| Area | Status | Notes |
|------|--------|-------|
| Notification settings sheet | Info-only | `YackNotice` + explanation text, no toggles |
| Privacy settings sheet | Info-only | `YackNotice` + explanation text, no controls |
| Subscription page | Static | Plan cards shown, no billing integration |
| Help & Support | Disabled | `SettingsItem` with `enabled: false` |
| Help support subtitle | Says "unavailable" | |
| temp-ID invitation notifications | Non-navigable | Shows snackbar hint only |
| Local push notifications | TODO | `notification_service.dart` has `TODO: Show local notification` |
| `syncSingleContract` | Stubbed | Falls back to full sync |
| About dialog | Version/copyright | No deep linking or changelog |

---

## 12. Screen Routing Map

```
/ (AppWrapper)
├── /welcome → /signup | /login
├── /signup → /confirm
├── /login → /decrypt-account | /confirm | /forgot-password
├── /confirm → /init-account | /login
├── /init-account → /home | /login
├── /decrypt-account → /home | /init-account | /login
├── /forgot-password → /login
├── /home (BottomNavBar)
│   ├── Tab 0: ContractsScreen
│   │   └── ContractCard tap → /contract/view
│   ├── Tab 1: ScanContractScreen → (review) → /contract/view
│   ├── Tab 2: NotificationsPage → /contract/view (via router)
│   └── Tab 3: SettingsScreen
│       ├── /profile
│       ├── /subscription
│       ├── Appearance sheet
│       ├── Language sheet
│       ├── Notification info sheet
│       ├── Privacy info sheet
│       ├── About dialog
│       └── Logout → /login
├── /contract/create_contract → /contract/scan_contract | /home
├── /contract/view (ContractAgreement)
│   ├── Accept → sync
│   ├── Dispute → sync
│   ├── Contract details sheet
│   └── Attachment picker sheet
└── /subscription → close
```

---

## 13. Localization

- **Languages:** English (en), Arabic (ar), French (fr)
- **Implementation:** `TranslationHandler` with Hive-stored preference + server-synced via `UserService`
- **RTL support:** Arabic triggers RTL layout throughout
- **All user-facing strings** go through `TranslationHandler.get()` / `TranslationHandler.resolve()` with param interpolation
