# Pocket Ledger

An offline Flutter expense tracker with monthly salary, editable savings, automatic rollover on the next salary, device authentication, and encrypted local storage. The companion static landing page distributes an Android APK directly.

**Start with [BUILD_ANDROID.md](BUILD_ANDROID.md)** for the browser-only Codemagic build and download-site instructions. No Android Studio or powerful local computer is required for that route.

## Included

- A complete Flutter application with Android and iOS platform projects.
- Empty initial ledger; useful categories, but no sample financial records.
- Salary-first spending, savings fallback, shortfall tracking and salary rollover.
- Expense editing/deletion, linked partial refunds, category editing, monthly search, optional spending limits and six-month insights.
- Device biometrics with device credential fallback, startup/background locking and native screen privacy.
- An AES-256-GCM encrypted ledger snapshot in SQLite, with the random key in platform secure storage. SQLite metadata itself is not encrypted; all financial contents are.
- Password-encrypted exports (PBKDF2-HMAC-SHA256, 600,000 iterations, AES-256-GCM) compatible with the browser preview's `.ledger` format, validated restore, and CSV export.
- A responsive landing page, privacy policy, truthful release availability, and APK checksum.
- Cloud signing/setup/release workflows, tests, and release packaging scripts.

## Local development

Use Flutter **3.47.9** (Dart 3.13.7), matching the committed native project and cloud configuration.

```sh
flutter pub get --enforce-lockfile
flutter analyze
flutter test
flutter run
```

Android minimum: API 24 / Android 7.0. iOS project is provided, but requires a macOS build and device testing. Direct APK distribution is Android-only; an iPhone cannot install an Android APK.

The app requires an enrolled device screen lock. There is no bypass button, simulated authentication, or app account. If authentication is unavailable, set up the device lock in system settings and retry.

## Structure

- `lib/core/ledger.dart`: validated domain records, integer amounts, deterministic accounting.
- `lib/data/`: SQLite vault, key storage, encrypted backups, device authentication, controller.
- `lib/ui/`: screens, forms, theme.
- `android/`, `ios/`: native integration, privacy and build settings.
- `landing/`: deployable static download website.
- `tool/`: signing and release helpers; test fixture generator.
- `test/`: domain, encryption, persistence and Flutter UI tests.
- `docs/`: accounting decisions, test report and phone acceptance checklist.

## Data and money rules

See [docs/ACCOUNTING.md](docs/ACCOUNTING.md). Currency changes are allowed only before financial records exist. IQD uses whole dinars, matching the original preview; other supported currencies use two decimal places. There is no exchange-rate conversion.

Data is local. OS backup exclusions are configured; exported files can be uploaded only if the user chooses a cloud location in the system file picker. Back up before uninstalling or changing phones. Never commit real backups, passwords, signing files or private ledger data to the repository.

## Release status

The source and automated checks are described in [docs/VERIFICATION.md](docs/VERIFICATION.md). A signed APK must be produced with your signing identity by the cloud workflow. The source delivery is not a claim of App Store/Play approval or physical-device verification.

The website's download button remains unavailable until `tool/prepare_release.py` copies a real APK into `landing/downloads/` and writes its manifest. The release workflow does this automatically and outputs `pocket-ledger-website.zip`.
