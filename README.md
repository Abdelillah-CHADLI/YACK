# 📱 YACK — Your Agreement Contract Keeper

**YACK (Your Agreement Contract Keeper)** is a Flutter mobile app that lets users **create, share, sign, and verify digital contracts** securely. Contracts are protected with **end-to-end encryption** (RSA public/private keys via `pointycastle`), shared instantly over a peer-to-peer link (QR code or deep link), and kept in sync with a backend. It offers a premium, mobile-first Material 3 UI with full Arabic/French/English localization and light/dark themes.

> The app communicates with a separate Node.js backend (`YACK-Backend`), not included in this repository.

---

## ✨ Features

- ✍️ Create contracts with an encrypted title, description, and price
- 📷 Share a contract via **QR code** or paste a **deep link** manually
- 🖋️ Other party **scans / joins**, then both sides **accept & sign**
- 🔐 End-to-end encryption with asymmetric RSA key pairs (per user)
- ☁️ Firebase authentication + push notifications; Isar/Hive local storage with backend sync
- 🧾 Review contracts (accept/decline), translate content inline, and view statuses (pending, active, accepted, rejected, completed, disputed)
- 🎨 Premium Material 3 design system with light & dark themes
- 🌍 Localized UI (English, Arabic, French)

## 🗂️ Architecture

The Flutter app uses a layered structure:

| Layer | Location | Purpose |
|-------|----------|---------|
| Data | `lib/data/` | Local models (Isar), repositories, adapters |
| Logic | `lib/logic/` | Cubits (BLoC state), services (auth, network, storage, notifications, encryption) |
| Presentation | `lib/presentation/` | Screens, theming, and reusable widgets |
| L10n | `lib/l10n/` | Translation maps (`en`, `ar`, `fr`) |

```
lib/
├── main.dart / app.dart / app_wrapper.dart   # entry points & routing
├── data/
│   ├── db/models/                            # Isar models (contract, message, media)
│   └── repositories/                         # local data access (isar_adapter, …)
├── logic/
│   ├── cubits/                               # BLoC state (auth, contract, settings, …)
│   └── services/
│       ├── auth/                             # Firebase auth + encryption/crypto
│       ├── contract/                         # contract CRUD & sync
│       ├── message/ media/ notification/ network/
│       └── snapshot helpers (snackBarHandler, translation_handler)
├── presentation/
│   ├── theme/                                # design tokens + light/dark themes
│   ├── screens/                              # home, scan, share, create, settings, profile, auth, subscription, …
│   └── widgets/                              # reusable buttons, inputs, cards, badges
└── l10n/                                     # translations
```

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (stable) with Dart >= 3.9
- A backend instance (see **Backend** below)
- A Firebase project configured for Android (and optionally Web/Windows/macOS)

### 1. Install dependencies

```bash
flutter pub get
```

### 2. Configure Firebase

- Create a Firebase project and register your Android app (package `com.example.yack`).
- Place the downloaded config as `android/app/google-services.json`.
- Update `lib/firebase_options.dart` (or re-run `flutterfire configure`).
- Enable the **Email/Password** sign-in provider in the Firebase console before testing sign-up.

### 3. Point the app at your backend

In development, YACK automatically connects to the local backend at
`http://10.0.2.2:3000` on the Android emulator and `http://127.0.0.1:3000`
on desktop, iOS simulator, and web. Start `YACK-Backend` first, then run:

```bash
flutter run
```

For a physical device, pass the computer's LAN address. Release builds always
require an explicit deployed HTTPS endpoint:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.20:3000
flutter build apk --dart-define=API_BASE_URL=https://api.example.com
```

### 4. Run the app

```bash
flutter run
```

## 🔌 Backend

The API lives in a separate repository (`YACK-Backend`: Node.js/Express, Mongoose, Firebase Admin, Cloudinary) and is typically deployed to [Leapcell](https://leapcell.io). It is responsible for:

- User accounts (Firebase Auth)
- Contract creation, joining, and signing coordination
- Push notifications between the two parties
- Media uploads (Cloudinary)

> 🔐 Backend credentials (Firebase Admin service account, MongoDB URI, Cloudinary keys) live in that backend repo's environment variables — **never** commit them to this app repository.

## 🌍 Localization

Add or update strings in:

- `lib/l10n/en.dart`
- `lib/l10n/ar.dart`
- `lib/l10n/fr.dart`

Keys must be added manually to **all three** maps; missing keys fall back gracefully via `TranslationHandler`.

## 🧪 Analysis

```bash
flutter analyze
```

Zero errors is the target. Remaining warnings/infos come from generated Isar files (`.g.dart`), naming conventions, and `print()` in services.

## 🧰 Tech Stack

| Category    | Technology                                                       |
|-------------|------------------------------------------------------------------|
| Frontend    | Flutter (Material 3)                                              |
| State       | flutter_bloc (BLoC)                                               |
| Local DB    | Isar + Hive                                                       |
| Encryption  | pointycastle (RSA)                                                |
| Auth / Push | Firebase Auth, Messaging, Crashlytics                             |
| Sharing     | qr_flutter + mobile_scanner                                        |
| Backend     | Node.js/Express (separate repo)                                    |
| Languages   | English, Arabic, French                                            |
| Platforms   | Android (primary; web/windows/macOS configured)                    |

## 📄 License

This project is licensed under the **MIT License**.

## ❤️ Author

**YACK Team** — *Your Agreement Contract Keeper — simple, secure, and smart digital contracts.*
