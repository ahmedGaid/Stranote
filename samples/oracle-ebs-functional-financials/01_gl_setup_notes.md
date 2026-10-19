# Acme ledger setup - working notes (fictional sample)

- Accounting calendar "ACME CAL" has 12 monthly periods plus one adjusting period (ADJ-26).
- Chart of accounts: 5 segments (Company, Cost Centre, Account, Product, Intercompany).
- Cross-validation rules: block Company 02 with Cost Centre 9xx.
- Security rules restrict the Payables Clerk responsibility to Company 01.
- Data access sets: "ACME DAS ALL" gives read/write on both ledgers.
- Profile GL: Data Access Set = ACME DAS ALL on the GL Super User responsibility.
- Journal sources added: "Acme Payroll" (freeze journals = Yes), journal categories "Payroll Accrual".
- Recurring journals for rent; MassAllocations for IT cost per cost centre.
