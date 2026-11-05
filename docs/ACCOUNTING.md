# Accounting behavior

The model intentionally matches the approved browser preview.

- All values are integers in the currency's chosen minor unit. IQD is whole dinars; USD/EUR/GBP/AED/SAR use cents (two decimals). No exchange-rate conversion.
- There is one salary per calendar month. Editing it replaces the amount; it never adds a duplicate salary payment.
- Records are evaluated in ascending calendar-month order. Within a month, expenses minus linked refunds are netted, then savings adjustments are applied.
- Adding a salary for a later month moves the previous remaining salary to savings. A month without a salary record does not trigger a rollover; existing salary continues funding expenses. A recorded zero salary closes the previous period.
- New salary first covers any negative savings balance, then becomes available for spending.
- Nonnegative net spending consumes salary first and savings second. A net refund month credits savings.
- Negative savings is shown as a shortfall; expenses are not silently rejected or discarded for insufficient funds.
- Editing savings records the difference between the requested balance and the calculated balance as a dated adjustment. It does not rewrite past transactions. Editing earlier records can therefore change later balances.
- Refunds must reference an existing expense, use its category, be no earlier than it, and collectively not exceed its amount. Expense deletion also deletes linked refunds.
- Balances are derived each time, not saved as mutable rollover counters. This prevents double rollover across restarts or repeated saves.
- Monthly budgets are informational spending limits. They do not add money or move it between salary and savings.
- Future records can be entered; viewing a month includes only records through that month. Month/date keys use local device calendar dates, without UTC conversion.

## Storage

SQLite schema v1 contains one `vault` row. Its payload is AES-256-GCM ciphertext of the versioned, validated ledger document. Each successful save generates a fresh nonce and atomically replaces that row in a transaction. No plaintext financial fields are inserted into SQLite, journal or WAL. The AES key is generated randomly and stored using the OS secure-storage plugin; iOS keys use this-device-only accessibility.

This snapshot design suits a personal ledger (up to 10,000 entries) and preserves exact backup compatibility. It is not intended for a shared or multi-user database. Only one save runs at a time. The controller updates its displayed state after persistence succeeds.

Unreadable records or missing encryption keys do not cause an automatic reset. A recovery screen offers retry, validated backup restoration, or an explicit typed reset. Device authentication is a UI access gate; it is distinct from cryptographic key authentication and is not a defense against a compromised app process or rooted OS.
