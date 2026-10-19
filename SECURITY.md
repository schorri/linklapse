# Security

The UI binds to `127.0.0.1` on a local port. It does not listen on the LAN. API requests require a per-instance token; mutations additionally require the same origin and JSON. Host checking, cross-site request rejection and an explicit route list limit browser access. There is no generic shell, file-browsing or command-execution endpoint.

The normal worker runs with the launching user's permissions. Only the optional update-policy helper requests administrator approval. It pauses automatic security updates too and keeps protected restoration state. Do not test it on a managed device. Builds are initially unsigned; organizational application controls may block execution.

Logs may contain internal IPs, adapter names, URLs and timestamps. Avoid posting raw logs or unreviewed reports publicly. When importing untrusted CSV into a spreadsheet, treat fields as text.

Once hosted, use **Report a vulnerability** in this repository's Security tab when private reporting is enabled. Until then, report through the private channel from which you obtained the package. Do not include exploit details or sensitive logs in a public issue. No separate contact address or response-time promise is assumed.
