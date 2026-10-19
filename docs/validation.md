# Validation for 0.1.0

Checked on Windows 11 with Windows PowerShell 5.1 and Microsoft Edge. This is a first release candidate, not a claim of coverage across every home network or Windows policy configuration.

## Automated checks

- C# compilation and PowerShell source parsing.
- Ping qualification, raw/evaluated counts, initially silent targets, later persistent failures, target/route/session/gap resets and recorded-state report replay.
- Extra-node learning, different probe routes and exclusion of future topology from historical reports.
- Dashboard assessment for Wi-Fi/Ethernet, mixed routes, fresh/stale service evidence, AP management vs forwarding and capped/partial downloads.
- Typed UI settings, bounded values, adapter selection and rejection of unknown command fields.
- Local HTTP bridge: HTML response type, token/origin/host checks, route allowlist, request-size limits and graceful shutdown.

The offline checks do not start external measurements or change update policy. Bridge tests use loopback HTTP in a disposable test folder.

## Short integration checks

The actual dashboard started a hidden four-sample worker, respected its selected duration/settings, rejected a second concurrent start, produced HTML and ZIP reports, then started and stopped another session. Wi-Fi, ping/TCP/HTTPS and bounded TTL discovery ran during these checks. Different VPN/Wi-Fi routes remained separate and did not produce a blanket Internet-outage claim from initially silent pings.

English/German, download-option controls, evidence dialogs, time filters, a 390-pixel viewport and print/PDF were reviewed without observed JavaScript errors. Public screenshots/demo use synthetic data; real test logs are excluded from source and packages.

## Still to validate

- Multi-day runs on additional private laptops and home networks.
- Full elevated update-policy installation/restart/restoration on supported private Windows editions. It was not installed on the development work computer.
- Broader proxy, driver, Modern Standby and access-point combinations.

The download transfer core is unchanged from the previous prototype. Its result classification is covered offline; no new real capacity claim is made from this release's short checks. GitHub-hosted workflows are prepared but cannot be reported as passed before they run in the repository.
