# AR AutoInvoice for the Acme billing feed (fictional sample)

## What we set up
- Transaction types: "ACME INVOICE" and "ACME CREDIT MEMO" (natural application only).
- Transaction sources: "ACME BILLING" (Imported, Batch numbering automatic).
- AutoAccounting: revenue account takes Company from the transaction type and Cost Centre from the salesperson.
- Receipt classes "ACME LOCKBOX" with receipt methods per bank account.
- Profile classes: "ACME KEY ACCOUNTS" with 45 day terms and dunning letters off.
- Aging buckets "ACME 30-60-90" for the collector report.

## Decisions
- Run AutoInvoice nightly after the billing feed lands.
- Lockbox stays manual until the bank sends the new file format.
