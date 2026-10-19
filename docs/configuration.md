# Configuration

Use dashboard controls for session duration, downloads, adapter selection, AP management address and the optional update policy. These apply to the next session. The update-policy checkbox resets after a run and is never remembered as enabled.

`config.json` sets underlying defaults and test targets. Edit valid JSON without comments, use decimal points, then restart LinkLapse. Every session saves its effective settings. Do not commit personal adapter names, internal addresses or custom private URLs in a public release.

| Key | Default / range |
| --- | --- |
| `Language` | `en` by default, including on German Windows; `de` is available manually. The app remembers a selected language. |
| `InterfaceName` | Empty = adapter of the route to the second Internet target; exact Windows name otherwise |
| `DurationMinutes` | 60; UI presets 0/5/60/1440/4320/10080/20160/43200, 0 unlimited |
| `IntervalSeconds` | 1, allowed 1–60 |
| `PingTimeoutMs` | 800; at least 100 and below the interval in milliseconds |
| `TcpEverySeconds` / `WebEverySeconds` | 5 / 60 |
| `DashboardEverySeconds` | 5; browser reads new snapshots without reloading the controls |
| `HighInternetLatencyMs` / `HighGatewayLatencyMs` | 150 / 30; observation thresholds, not provider guarantees |
| `WeakWifiPercent` | 40; Windows quality threshold |
| `InternetTargets` | Exactly three distinct IPv4 addresses |
| `TcpTargets` | Exactly two IPv4 addresses with ports |
| `WebUrls` | Exactly two small HTTPS URLs |
| `Topology.Enabled` | true; controls TTL and extra-node probes, not ordinary ping/routing |
| `Topology.MaxHops` | 12, allowed 1–30 |
| `Topology.TimeoutMs` | 500, allowed 100–1000 |
| `Topology.DiscoverEveryMinutes` | 15, at least 5 |
| `Topology.ProbeEverySeconds` | 5, at least 5 |
| `Topology.MaxMonitoredHops` | 3, allowed 0–8 extra visible hops per route |
| `Topology.HighHopLatencyMs` | 75, positive |
| `Topology.AccessPointAddress` | Empty or confirmed IPv4 management address |
| `Speed.Enabled` | false |
| `Speed.EveryMinutes` | 60; UI offers 15/30/60/180 |
| `Speed.MaxMiB` | 5; UI offers 1/5/10/25/50 |
| `Speed.MaxSeconds` | 15, allowed 2–60 |
| `Speed.MaxMbps` | 0 uncapped; dashboard offers 0/2/5/10/20 |
| `Speed.ExpectedMbps` | 0 disables reference comparison |
| `Speed.SlowRatio` | 0.5; between 0 and 1 |

The default public ping targets are Cloudflare, Google and Quad9. TCP/HTTPS target availability and ICMP responsiveness are not guaranteed. Choose suitable endpoints you are entitled to probe.

HTTPS combines DNS, TCP, TLS and HTTP rather than isolating DNS. It may use a proxy/IPv6 and a different path from IPv4 ping. Download uses no HTTP proxy, limits read volume/time, and may underestimate fast connections because setup is included.

Runtime preferences, local UI instance details and request settings stay under `data`, excluded from Git and release packages. The UI accepts bounded typed settings, not arbitrary command lines or executable paths.
