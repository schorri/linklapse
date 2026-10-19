$ErrorActionPreference='Stop'
& (Join-Path $PSScriptRoot 'PingLearning.Tests.ps1')
& (Join-Path $PSScriptRoot 'Topology.Tests.ps1')
& (Join-Path $PSScriptRoot 'UiSettings.Tests.ps1')
Write-Host 'All offline PowerShell checks passed. No network probes or policy changes were requested.'
