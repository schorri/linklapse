# Measurement method

LinkLapse records observations from one Windows laptop. It does not recover every physical device, certify a broadband line, or establish which party caused a failure.

## Ping and independent services

Gateway and each external target qualify after at least 8 successful replies in a rolling window of 10 valid probes on the same target/session/route. Invalid local errors do not train a baseline. Once qualified, a target stays qualified during prolonged reply loss. Target, interface/next-hop, session and continuity changes reset learning.

Initially silent targets remain in raw counts but do not create ping alarms or inflate the evaluated failure ratio. They can qualify later. This also means a fault present at startup may remain unassessed by ping. The denominator of eligible targets is always shown. Wi-Fi, TCP and HTTPS remain independent evidence.

The TCP checks test connection setup to two services. HTTPS includes name resolution, TLS and HTTP. Recent successes argue against a complete loss of every Internet path; they do not establish unrestricted access. Mixed routes cannot support a unique upstream attribution.

## Topology

Windows IPv4 route selection groups targets by interface and next hop. TTL discovery probes one representative per group, with a fixed maximum hop count and timeout. Later routes can diverge. Silent TTL steps are unknown, not failed devices.

An AP bridge/switch may not appear in the trace. A physical device can serve several roles. Optional AP management and discovered node addresses are probed via their own routes. Different probe/trace interfaces remain unknown; direct node responses are control-plane evidence, not proof about packet forwarding.

Extra nodes use the same 8/10 baseline at their own cadence. After qualification, one/two consecutive failed probes are amber and three are red. A route mismatch resets their basis; gaps split segments.

## Time and aggregation

Times are recorded in UTC and displayed in the browser timezone. Matching observations form spans from the first to last probe, not an exact duration of failure. A single sample has a zero-second observed span. Gaps, session changes and backwards clock jumps break continuity.

Minute/hour/day plots retain maximum latency and minimum signal. Evaluated failure percentages use actual evaluated counts. Mean/P95/max statistics use successful replies; P95 rounds samples to milliseconds. Recent detailed tracks are bounded in HTML; full main-track segments and raw node probes are exported in reports.

Reports preserve recorded eligibility. Historical topology is selected only from snapshots known before the report end. Extra-node charts describe the final included session; raw `nodes.csv` covers all included sessions. Session context copies can contain later snapshots, which are not treated as past topology.

## Download samples

Short successful HTTPS downloads measure payload divided by elapsed time including setup. Rate caps and small payloads can constrain the result. Partial transfers are logged but not treated as valid capacity samples. Own test load is marked in ordinary rounds. A user reference enables a cautious slow-sample indication; no reference is inferred from a tariff.

## References

- [Microsoft: tracert and routers invisible to TTL probes](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/tracert)
- [Microsoft: GetBestRoute](https://learn.microsoft.com/en-us/windows/win32/api/iphlpapi/nf-iphlpapi-getbestroute)
- [Microsoft: Native Wi-Fi query parameters](https://learn.microsoft.com/en-us/windows/win32/api/wlanapi/ne-wlanapi-wlan_intf_opcode)
- [Microsoft: Wi-Fi location-permission changes](https://learn.microsoft.com/en-us/windows/win32/nativewifi/wi-fi-access-location-changes)
- [Microsoft: PowerSetRequest](https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-powersetrequest)
- [Microsoft: Windows Update settings](https://learn.microsoft.com/en-us/windows/deployment/update/waas-wu-settings)
- [Cloudflare: speedtest implementation](https://github.com/cloudflare/speedtest)
