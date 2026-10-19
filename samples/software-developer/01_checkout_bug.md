# Bug: double charge on checkout (fictional sample)

- Root cause: a race condition between the payment webhook and the "Pay" button retry.
- Fix: made the charge endpoint idempotent with an idempotency key stored in PostgreSQL.
- Added retry with backoff on the payment client and a dead-letter queue for failed webhooks.
- Written in TypeScript (Node.js service); the React page now disables the button while the request runs.
- Regression test added; one flaky test in the cart suite quarantined.
- Rolled out behind a feature flag, then removed the flag after a week.
