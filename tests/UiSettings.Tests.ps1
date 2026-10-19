$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
. (Join-Path $root 'src/Common.ps1')
. (Join-Path $root 'src/UiSettings.ps1')
$config=Read-Settings
$adapters=@([pscustomobject]@{Name='Test Wi-Fi'})
$good=Get-UiPreferences $config
$resolved=Resolve-UiSettings $good $config $adapters
if($resolved.DurationMinutes -ne 60 -or $resolved.Speed.Enabled){throw 'UI defaults changed unexpectedly.'}
$good.InterfaceName='Test Wi-Fi';$good.AccessPointAddress='192.0.2.10';$good.SpeedEnabled=$true;$good.SpeedMaxMbps=5
$resolved=Resolve-UiSettings $good $config $adapters
if($resolved.InterfaceName -ne 'Test Wi-Fi' -or $resolved.Speed.MaxMbps -ne 5){throw 'Valid UI settings did not reach the worker config.'}
if($config.InterfaceName -or $config.Speed.Enabled){throw 'UI overrides mutated config.json defaults.'}
function Reject($settings){$failed=$false;try{$null=Resolve-UiSettings $settings $config $adapters}catch{$failed=$true};if(-not $failed){throw 'Unsafe/invalid UI settings accepted.'}}
foreach($change in @(@{DurationMinutes=-1},@{DurationMinutes='5'},@{SpeedEnabled='false'},@{PauseUpdates='true'},@{InterfaceName='Unknown adapter'},@{SpeedMaxMbps=-2},@{ExpectedMbps=100001},@{AccessPointAddress='example.invalid'},@{Language='xx'})){
    $v=$good|ConvertTo-Json|ConvertFrom-Json
    foreach($key in $change.Keys){$v.$key=$change[$key]}
    Reject $v
}
$v=$good|ConvertTo-Json|ConvertFrom-Json;$v|Add-Member -NotePropertyName Command -NotePropertyValue 'unexpected';Reject $v
Write-Host 'PASS: typed/limited UI inputs, adapter allowlist, IPv4 address, immutable defaults, no arbitrary commands.'
