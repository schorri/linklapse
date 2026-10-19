# Contributing

Small, tested changes are welcome. Include the problem, resulting behavior and what you checked. For a bug report, give the version, Windows edition, connection type and steps to reproduce. Replace private addresses and names with examples.

Run `tools\Build.ps1`, `tests\Run.ps1`, `node tests\Diagnostics.Tests.cjs` and `node tests\Bridge.Tests.cjs`. Windows PowerShell 5.1 / .NET Framework 4.8 is the runtime target. Node is for developer checks only. `src\Vorschau.ps1 -NoOpen` regenerates the synthetic demo; review both languages, a narrow viewport, dialogs and print after UI changes.

Preserve these distinctions: raw vs evaluated ping; service reachability vs ICMP; physical roles vs visible hops; observed spans vs exact outage duration. A qualified endpoint must remain evaluable during later persistent failure. Keep API inputs typed and bounded, routes allowlisted, loopback binding explicit and mutations protected by token and origin checks.

Do not commit `data`, `reports`, private screenshots or policy backups. Fixtures should use documentation/test addresses. Optional update-policy integration belongs on an authorized private test system, never a managed work device.

The normal interface should stay simple: open, choose, start. Put detailed explanations in the guide. Add translations for new user-facing text. The MIT license applies to contributions.
