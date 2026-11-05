# Verification and release status

Source prepared November 5, 2026. This package is source code, not an installable APK.

## Completed checks

- Final Dart static analysis: no issues found.

- All 23 Flutter tests pass on the final source: 13 accounting tests, 3 encrypted-backup/CSV tests, 3 storage/controller tests and 4 UI tests.
- Final fixes include retaining form controllers until the dialog exit animation completes and excluding keyboard focus while locked.
- Two Python release-packaging tests pass: invalid input does not enable downloads, and the published manifest matches the copied APK bytes.
- Codemagic YAML, Android XML, iOS property lists and landing-page JavaScript syntax were checked.
- The landing page was inspected in a browser. Its initial state truthfully reports that no APK is available.

## Final Flutter run

Flutter 3.47.9 / Dart 3.13.7, locked dependency restore succeeded. The final full-suite run reported `23: All tests passed!`. The release workflow independently requires analysis and all Flutter/Python tests to pass before building an APK.

## Requires the cloud build and your phone

- Android Gradle compilation, release signing, APK installation and native plugin behavior have not been verified here.
- Fingerprint/device-credential prompts, device secure storage, background locking, file import/export and OS backup exclusions require physical-device testing. Follow PHONE_TEST_CHECKLIST.md.
- iOS source is included but has not been compiled or signed here. The unsigned cloud workflow is a compilation check, not iPhone distribution.
- The website has not been published. Its download is enabled only after the release workflow includes a real APK.

The accounting tests cover salary-first spending, savings fallback, repeated rollover, missing and zero-salary months, year boundaries, backdated edits, shortfalls, savings adjustments, refunds, deletion, input validation and randomized conservation of money. Backup tests cover authenticated encryption, wrong passwords, tampering and compatibility with an actual WebCrypto export fixture. UI tests cover login cancellation, salary/expense entry, theme persistence, background locking and keyboard-focus exclusion.
