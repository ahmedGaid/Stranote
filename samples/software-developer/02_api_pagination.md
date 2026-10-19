# Orders API: cursor pagination (fictional sample)

- The list endpoint returned 20k rows; added cursor pagination (limit + next cursor).
- Found an N+1 query in the ORM: one query per order line. Fixed with a join.
- Kept backward compatible: old offset params still work for 3 months, marked deprecated.
- Service is Python with FastAPI; contract documented in an ADR.
- Rate limiting at 100 requests/minute per API key, cached counts in Redis.
- Breaking change for v2 announced in the changelog.
