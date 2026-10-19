# Postmortem: search outage, 40 minutes (fictional sample)

- Elasticsearch cluster ran out of heap after a memory leak in the indexing worker.
- Alerts fired in Grafana 12 minutes late; the SLA for search is 99.9% so we used most of the error budget.
- Kafka consumer lag grew to 2M messages; consumers restarted after the fix.
- Traces in OpenTelemetry showed the worker held every document in a list. Fix written in Java.
- Errors are now grouped in Sentry with the release tag.
- Follow-up: cache invalidation for the search suggestions; eventual consistency is fine for 30 s.
