# Phone acceptance test

Use test amounts first. Reset afterward before entering personal records. There is no seeded data in the release app.

- [ ] Install the signed APK from the HTTPS landing page. Version and file size match the release.
- [ ] Cancel device authentication: the ledger stays covered. Authenticate successfully: it opens.
- [ ] Try fingerprint and device PIN/password fallback. Check lockout/cancellation and a device with no enrolled fingerprint.
- [ ] Change currency before adding records. Verify the currency is protected from later accidental changes.
- [ ] Set savings to 500; add this month's salary of 1000; add an expense of 1200. Salary remaining is 0, savings is 300.
- [ ] Reset, add salary 1000 and expense 200; add next month's salary 1200. Savings becomes 800. Reopen repeatedly: it remains 800.
- [ ] Edit the earlier expense to 400. Savings becomes 600. Delete it: savings becomes 1000.
- [ ] Create a shortfall and verify the next salary covers it first.
- [ ] Add a partial refund; try a refund larger than the expense and one dated before it. Invalid refunds are rejected.
- [ ] Add/rename a category, search/filter history, set a spending limit, inspect six-month totals.
- [ ] Switch the single theme control. Force-close/reopen: theme and records persist after authentication.
- [ ] Switch apps, lock the phone, and return. Financial contents stay covered until authentication.
- [ ] Open a form, switch apps, then return. Unlock before continuing; a save is not duplicated.
- [ ] Export an encrypted backup, cancel the file picker, then export successfully. A cancellation does not claim success.
- [ ] Restore the export. Wrong password and damaged file are rejected without replacing the ledger. Valid restore shows a replacement confirmation.
- [ ] Import an encrypted backup exported from the original HTML preview and compare balances and categories.
- [ ] Export a CSV and inspect quotes, multiline notes, and Arabic text.
- [ ] Turn on airplane mode; repeat salary, expense, unlock and restart operations.
- [ ] Enable large system text and test a small screen, landscape, numeric keyboard, date picker and Android back button.
- [ ] Back up, install a newer APK with the same signing key over the app, and confirm records survive.
- [ ] Confirm app-switcher preview is covered and Android screenshots are blocked.
- [ ] Verify encrypted backup recovery on another phone before relying on it for important data.

Record phone model, Android version, app version/build number, expected result, actual result, and reproduction steps for any failure. Never send a real unencrypted ledger or password in a bug report.
