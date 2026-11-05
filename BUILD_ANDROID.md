# Build Penny in your browser

This guide produces a **signed Android APK** and a **website ZIP containing the APK**. Your PC only downloads/uploads files and opens websites. The heavy work runs on Codemagic.

Do not upload the unbuilt source ZIP to your landing-page host and expect an installable app. Run the release workflow first.

## 1. Put the source in a private GitHub repository

1. Unzip `Pocket_Ledger_Flutter.zip`.
2. Create a private GitHub repository called `pocket-ledger`.
3. Upload the **contents** of the `pocket-ledger-flutter` folder. `pubspec.yaml`, `pubspec.lock`, `codemagic.yaml`, `lib`, `android`, `ios`, `test`, `tool`, and `landing` must be at the repository root.
4. If GitHub's web uploader limits the file count, upload in batches or use GitHub Desktop. Neither builds the app.
5. Keep the `.gitignore` file. Never upload `android/key.properties`, `.jks` files, `.env`, `build`, or `.dart_tool`.

The application ID is `com.andrawsmalallah.pocket_ledger`. Keep it stable after first installation if you want updates to preserve app data.

## 2. Connect Codemagic

1. Open https://codemagic.io/ and create/sign in to your own account.
2. Connect the GitHub repository.
3. Choose the configuration from `codemagic.yaml`.
4. The file defines three manual workflows. No automatic store publication is configured.

The individual plan has a limited monthly build allowance; check current pricing before starting or enabling billing: https://codemagic.io/pricing/ .

## 3. Create your signing key once, without installing tools

Skip key generation if you already have a signing key you intend to use.

1. In Codemagic environment variables, create a group named `signing_setup`.
2. Add `NEW_KEYSTORE_PASSWORD`, mark it **Secret**, and choose a long unique password of at least 12 characters. Keep it in your password manager.
3. Run the **One-time Android signing key** workflow (`create-signing-key`).
4. Download `pocket-ledger-release.jks` from its private build artifacts. Keep a secure backup.
5. In Codemagic's Android code-signing identities, upload that `.jks` file.
6. Use these settings:

| Field | Value |
|---|---|
| Reference name used by workflow | `pocket_ledger_release` |
| Keystore password | The password you just chose |
| Key alias | `pocket-ledger` |
| Key password | The same password |

7. Retain the keystore and password securely. Remove old key-generation artifacts from the service when no longer needed, according to its available controls.

**Do not regenerate the key for updates.** A different signing key will normally prevent installing over the previous app. Never put the keystore on the public download website.

Codemagic's current signing guide: https://docs.codemagic.io/yaml-code-signing/signing-android/ .

## 4. Build the actual app

1. Run **Android APK and download website** (`android-release`).
2. It restores the locked dependencies, runs analysis and all tests, configures signing, builds the release APK, then prepares the website download.
3. A failed check stops the workflow. Save the failing step's log and provide it for diagnosis; do not disable tests to get a release.
4. When successful, download:
   - `app-release.apk` — installable Android app.
   - `pocket-ledger-website.zip` — complete website **with the APK inside**.
   - `release.json` — version, file size and SHA-256 checksum.

No Google Play developer account is required for this build workflow or your own phone test. Public direct distribution may be subject to Android developer verification rules applicable to the user's device/region; check those before broad distribution.

## 5. Put the landing page online

Use a static host that allows APK files and supports the APK's size. The ZIP includes normal HTML/CSS/JS plus `downloads/pocket-ledger-1.0.0.apk`; it needs no PHP server, database, or backend.

1. Extract the **entire** `pocket-ledger-website.zip` into a folder before opening `index.html`. Opening HTML directly inside a ZIP viewer can prevent the browser from finding the stylesheet, logo, and other pages.
2. Upload **all of its contents** to your HTTPS website's public directory. `index.html` must be at its root.
3. Preserve `release.json`, `release-data.js`, `style.css`, `logo.png`, `privacy.html`, `release.js`, and the `downloads/` folder.
4. Configure the host to serve `.apk` as `application/vnd.android.package-archive` or `application/octet-stream`. Do not rewrite APK requests to `index.html`.
5. Visit your landing page and confirm the download shows the version and size. The button remains hidden if the APK cannot be found.
6. Use that landing-page URL on your phone and press **Download Android APK**.

Some static hosts limit individual asset sizes; if the APK is too large, use another static/file host or serve the download path from object storage on the same origin. Do not use an expiring private CI artifact URL for a public download.

## 6. Install and test on your Android phone

1. Open the downloaded APK. If Android asks, allow installation from the browser you used. Only allow installation for a file you trust.
2. Install and open Penny.
3. Unlock using your device fingerprint, face recognition, or device credential.
4. Open Settings and choose your currency **before** adding financial records.
5. Add savings and salary, then an expense.
6. Follow `docs/PHONE_TEST_CHECKLIST.md`, especially restart persistence, background locking, and backup/restore.

Do not treat a successful cloud compilation as a substitute for these tests. Screenshot/recording protection is enabled on Android, so screenshots may be blank; that is intentional.

## Updates

- Keep the same app ID and signing key.
- Increase the semantic version in `pubspec.yaml`, e.g. `1.0.1+2`. The workflow sets an increasing Android version code from `PROJECT_BUILD_NUMBER + 1`; if you move to another Codemagic app/repository, ensure the new code exceeds the installed app's code.
- Run the release workflow again and replace the website files.
- Export a backup, then install the new APK **over** the old app. Do not uninstall first.

## iPhone

The included `ios-unsigned-check` workflow checks compilation on a cloud Mac, but its `.app` output is not installable on a normal iPhone. iPhone distribution needs your Apple signing setup and typically TestFlight/App Store. The landing page currently advertises Android only, without fake App Store links.
