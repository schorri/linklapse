# Using LinkLapse

## Open, choose, start

Extract the release ZIP to a new writable local folder and open **LinkLapse.exe**. Do not overwrite a running older installation. **START.cmd** opens the same launcher. Opening it again returns to the existing app for that folder.

Connect the laptop to the affected network, plug in AC power and leave the lid open. Disable VPN/Ethernet when practical for an isolated Wi-Fi comparison; otherwise the app keeps different routes visible.

Choose **5 minutes, 1 hour, 24 hours, 3/7/14/30 days, or until stopped**, optionally enable download samples, then click **Start monitoring**. No console interaction is needed. Settings are locked during a session; stop before changing them for the next run.

**Stop** ends the run gracefully. Pending tests may take a few seconds to finish. Timed sessions stop automatically. **Quit** stops the session and closes the background app after pending tests finish. Closing the browser tab alone does not stop monitoring. Open LinkLapse.exe again to return.

The page is available only on this computer. Choose English/Deutsch at the top. Measurements update roughly every five seconds. An open evidence dialog holds its current view.

## Measurements

Adapter/Wi-Fi state and four parallel IPv4 pings are sampled every second by default. Two TCP connections are checked every five seconds; two HTTPS URLs every minute. Bounded TTL discovery runs at startup, route changes and every 15 minutes. Next-hop and up to three extra visible router nodes are probed every five seconds. Download tests are optional.

Windows signal percentage is not dBm. Wi-Fi link rates are not Internet throughput. Missing values remain unknown. Brief interruptions between probes may be missed; timeouts and intervals limit resolution.

## Reading the page

The assessment and four cards describe the latest Wi-Fi/adapter, AP, gateway and Internet observations. Select a topology node for evidence. Successful individual tests do not establish unrestricted Internet service.

The **View** selector changes timelines, plots and affected-segment rows, independently of session duration. A short run fills its available range even when a longer view is selected. Cards, latest download and totals remain latest/session values.

Plots switch from individual samples through one hour to minute buckets through 24 hours, hourly buckets through 30 days, then daily buckets. Aggregates show maximum latency, minimum signal and the actual evaluated ping failure ratio. Latency/failure axes adapt; signal stays at 0–100%. Gaps and route changes are not joined by continuous lines.

Red tracks mean missing replies/disconnection; amber signal, latency or partial response; grey an unclear or unevaluated result. Select a segment to see times, counts and its **minimum observed span**. A single probe establishes a zero-second span. Onset and recovery may lie between probes or remain unknown. A red segment is not an exact proven duration of total Internet failure. A gap is missing evidence.

The live view retains up to 500 main-track segments, 200 per extra node and 200 gaps. The table shows up to 200 retained affected segments. Older areas without retained evidence stay grey; raw logs retain individual probes. New sessions reset the live view, while reports can combine sessions. For clipped segments, counts refer to the full retained segment and time boundaries to the visible portion.

**Measurement details & raw statistics** separates raw failures from evaluated ping replies and includes failed web/download attempts. Mean/P95/max use successful replies; P95 is based on rounded milliseconds.

## Reading the charts

Duration, the download switch and Start/Stop share the session toolbar. Enabling downloads opens their settings; starting a session collapses the extra options. Below the charts, expand **Network paths**, **Affected observation segments** or measurement details as needed. The top navigation jumps to the timeline, charts and details. Exported reports show the supporting sections expanded.

Response times use **ms**, signal quality and missing replies use **%**, and download samples use **Mbit/s**. Time labels follow your browser's local time zone. The signal scale stays at 0–100%; other scales adapt to the visible values, so check the axis when comparing periods.

Hover over a chart or tap it to see the timestamp and values. You can also focus the chart and use the left/right arrow keys; Home/End jumps to the first/last available point, and Escape dismisses the readout. The readout identifies the sample or aggregate resolution. Missing observations remain gaps. Download markers show individual tests, with no continuous speed inferred between them.

## Routes, APs and ping qualification

Automatic adapter selection follows the IPv4 route to the second ping target, normally 8.8.8.8. You can choose an exact adapter under **Connection & power options**. Ethernet is supported.

Targets with different route interfaces or next hops appear separately. A TTL trace describes one example target per group; other targets can diverge later. Silent steps do not establish broken routers. Tunnels, proxies, IPv6, multipath routing and changes during probes limit attribution.

Bridging APs and ordinary switches are normally invisible to layer-3 traces. One physical device can combine AP/router/switch roles. Enter an **AP management IP** only when known; otherwise leave it empty. The app does not scan subnets or log into routers. Management ping is not proof of forwarding health, and a directly probed node on a different interface remains unknown.

Ping evaluation requires at least **8 replies in 10 valid probes** per target/session/route. Permanently silent targets stay visible without generating ping alarms. Once qualified, later failures remain evaluable even when prolonged. Target, route, session and large-gap changes restart learning. A fault present at startup may therefore remain unassessed by ping; TCP, HTTPS and raw data remain independent.

Extra nodes learn at their own cadence. After qualification, one/two consecutive unsuccessful probes are amber; three or more are red. These are reply observations, not findings of responsibility. See the [measurement method](measurement-method.md).

## Download samples

The checkbox enables short downloads for the next session. Choose interval, maximum payload, approximate reader rate and optional reference. Defaults: first after one minute, then hourly, up to **5 MiB or 15 seconds**, whichever comes first. There is no upload test.

An uncapped sample can briefly saturate the line. A reader cap reduces load approximately; buffering may still cause bursts. Capped tests cannot establish full capacity. The page estimates daily download payload at the chosen interval.

Mbps includes connection setup, so small transfers can substantially underestimate fast connections. Only complete successful transfers become valid download values; partial attempts remain in details/logs. Overlapping ordinary rounds are marked as own download load.

Reference 0 disables slow-sample assessment. Otherwise a fresh successful uncapped sample below reference × `SlowRatio` (default 0.5) gets a cautious warning. This is not certified broadband measurement or a contractual finding.

## Reports

Choose a **report period** and click **Create report**. Monitoring may continue; export is a snapshot. Large periods can take several minutes. **Open report** displays it, **Download ZIP** saves the bundle.

Reports contain standalone HTML, German/English summaries, target statistics, all main-track segments, prioritized observation sections, gaps, extra-node probes, web/download results and session/topology metadata. Large raw `samples-*.csv` are not automatically attached; retain originals.

HTML works outside LinkLapse and offline. Use Print/PDF after expanding wanted details. HTML uses the viewing browser's timezone; logs and daily filenames use UTC.

Topology uses the last known snapshot before reporting end. Extra-node tracks replay recorded states for the final session in the period; `nodes.csv` covers all included sessions. Session context may contain later snapshots, but those do not become historical topology evidence. Recorded eligibility is retained even for reports starting mid-failure.

Review internal addresses, adapter names and URLs before sharing. Add laptop location, AP distance, known setup, actual usage symptoms, concurrent load and other affected devices. Compare LAN or before/after changes where possible. Files are editable, not cryptographically secured evidence.

## Power and optional update policy

A temporary Windows power request applies during measurement and is released afterwards. The power plan is not permanently changed. Use AC power and an open lid. Manual sleep, lid closure, battery exhaustion, system errors and enforced policies can still interrupt; Modern Standby may limit requests on battery.

The optional **Temporarily pause automatic Windows updates** setting requires Windows administrator approval and a private supported Pro/Enterprise/Education/IoT laptop. On Home use Windows' offered Update pause instead. Ordinary monitoring does not need elevation or change update policy.

The helper backs up `NoAutoUpdate`, sets it to 1 and installs a protected SYSTEM restoration task. **Automatic security updates are paused too.** After the owning process exits, its prior value is restored, normally within roughly a minute; later changes by another actor are preserved. After sudden power loss restoration can only happen after Windows restarts. Two common pending-restart markers prevent setup.

This cannot guarantee against every restart or running update. Catch up on updates and schedule maintenance breaks for long tests. For manual restoration an administrator can run `src\RichtlinieZuruecksetzen.ps1`. Compatibility state is under `%ProgramData%\InternetMonitor-Policy-v1`, task `InternetMonitor-UpdatePolicy-Restore-v1`; do not delete needed recovery state.

## Storage

`data` contains measurements, session metadata, topology and technical run logs. `reports` contains exports. Nothing is automatically deleted. One-second CSV logs can exceed 100 MB/day; check actual growth, keep enough space and archive stopped-run daily files outside `data`.

CSV uses UTF-8 BOM, semicolons and decimal points. Use explicit text/CSV import in Excel and preserve originals. `NotTested` means unscheduled, `NoGateway` missing gateway and `Error:*` local/API failure. Raw ICMP failures are not a general Internet outage percentage.

No passwords, SSIDs, BSSIDs or browser contents are stored. Configured endpoints receive ordinary probes and see connection metadata. LinkLapse does not upload results.

## Troubleshooting

- **Blocked launcher:** extract a trusted ZIP completely. Initial builds are unsigned. Respect organizational application controls; `data\ui-error.log` contains startup errors.
- **Local page disconnected:** open LinkLapse.exe again. The background app may have exited; data remains in its folder.
- **Session will not start:** inspect the dashboard message and worker error logs in `data`. Check folder write access and adapter selection.
- **Signal unavailable:** check driver and Windows privacy/location permissions. Elevation is not a general fix; other probes can continue.
- **Unknown AP:** expected without its confirmed management address. Do not equate AP with gateway.
- **One ping target always silent:** compare other targets and TCP/HTTPS before blaming equipment.
- **Only HTTPS/download fails:** inspect destination, proxy, TLS, DNS and filtering. The download does not use the HTTP system proxy.
- **No report data:** check period and included sessions, or wait for initial samples.
- **CSV schema mismatch:** use a new release folder, preserving old logs separately.

Further targets and intervals live in `config.json`, read when the application starts. See [configuration](configuration.md) and [validation](validation.md).
