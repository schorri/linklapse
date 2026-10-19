$ErrorActionPreference='Stop'
$root=Join-Path (Split-Path $PSScriptRoot -Parent) 'src'
$scratch=Join-Path $PSScriptRoot '.work';[IO.Directory]::CreateDirectory($scratch)|Out-Null
foreach($file in Get-ChildItem -LiteralPath $root -Filter '*.ps1') {
    $tokens=$null;$errors=$null
    [Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$tokens,[ref]$errors) | Out-Null
    if($errors.Count){throw ($file.Name+': '+($errors.Message -join '; '))}
}
. (Join-Path $root 'Common.ps1')
$c=Read-Settings
function Sample([int]$i,[string]$session='test') {
    $t=([datetime]'2026-10-19T08:00:00Z').ToUniversalTime().AddSeconds($i)
    return [pscustomobject]@{SchemaVersion=1;TimestampUtc=$t.ToString('o');SessionId=$session;IntervalSeconds=1;SignalPercent=70;WifiState='Connected';InterfaceName='WLAN';InterfaceIndex=4;SpeedActive=0;PathScope='SelectedWifi';Observation=''
        GatewayAddress='192.0.2.1';GatewayStatus='Success';GatewayMs=2;GatewayRouteIfIndex=4
        P1Address='1.1.1.1';P1Status='Success';P1Ms=10;P1RouteIfIndex=4
        P2Address='8.8.8.8';P2Status='Success';P2Ms=15;P2RouteIfIndex=4
        P3Address='9.9.9.9';P3Status='Success';P3Ms=25;P3RouteIfIndex=4
        Tcp1Address='1.1.1.1';Tcp1Status='NotTested';Tcp1Ms=-1;Tcp1RouteIfIndex=4
        Tcp2Address='8.8.8.8';Tcp2Status='NotTested';Tcp2Ms=-1;Tcp2RouteIfIndex=4}
}
function Silence($r,[string[]]$prefixes) {foreach($prefix in $prefixes){$r."${prefix}Status"='TimedOut';$r."${prefix}Ms"=-1}}
# Two permanently silent external targets plus a silent gateway, one healthy external.
$a=New-Aggregate
for($i=0;$i -lt 60;$i++) {$r=Sample $i;Silence $r @('Gateway','P1','P3');Add-Sample $a $r $c}
if($r.P1PingEvaluation -ne 'Unavailable' -or $r.P2PingEvaluation -ne 'Ready' -or $r.GatewayPingEvaluation -ne 'Unavailable'){throw 'Silent/reachable classification wrong'}
if($a.Timeline['Internet'].Open.State -ne 'ok' -or $a.Timeline['Gateway'].Open.State -ne 'unavailable'){throw 'Silent target triggers false alarm'}
if($a.Timeline['Internet'].Open.Label -notlike '1 von 1*2 von 3*'){throw 'Missing denominator/ignored coverage'}
$sum=@(Get-TargetSummary $a | Where-Object Target -like 'P1 *')[0]
if($sum.Sent -ne 60 -or $sum.Lost -ne 60 -or $sum.EvaluatedSent -ne 0){throw 'Raw/qualified evidence mixed'}
if(@($a.Recent.ToArray() | Where-Object lost -gt 0).Count){throw 'Silent targets leak into packet-loss chart'}
Write-View $a (Join-Path $scratch 'learning-silent.html') $false 'Lernprüfung · synthetische Daten' $true @{Settings=$c;Speed='Ausgeschaltet'}
# Persisting outage AFTER qualification must remain alarm-capable forever in this epoch.
$outage=New-Aggregate
$recordedRows=New-Object 'System.Collections.Generic.List[object]'
for($i=0;$i -lt 70;$i++) {$r=Sample $i;if($i -ge 10){Silence $r @('Gateway','P1','P2','P3')};Add-Sample $outage $r $c;$recordedRows.Add($r)}
if($r.P1PingEvaluation -ne 'Ready' -or $r.P1PingWindowReplies -ne 0){throw 'Qualified target silently downgraded during long outage'}
if($outage.Timeline['Internet'].Open.State -ne 'loss' -or $outage.Timeline['Gateway'].Open.State -ne 'loss'){throw 'Real subsequent outage lost'}
if($outage.Timeline['Internet'].Open.Samples -ne 60){throw 'Outage span starts/ends incorrectly'}
$span=([datetimeoffset]::Parse($outage.Timeline['Internet'].Open.LastObservedUtc)-[datetimeoffset]::Parse($outage.Timeline['Internet'].Open.StartUtc)).TotalSeconds
if($span -ne 59){throw 'Wrong minimum outage observation span'}
Write-View $outage (Join-Path $scratch 'learning-outage.html') $false 'Lernprüfung Ausfall · synthetische Daten' $true @{Settings=$c}
$fixture=Join-Path $scratch 'learning-fixture';[IO.Directory]::CreateDirectory($fixture) | Out-Null
$recordedRows.ToArray() | Export-Csv -LiteralPath (Join-Path $fixture 'samples-2026-10-19.csv') -Delimiter ';' -NoTypeInformation -Encoding UTF8
$cut=New-Aggregate
Import-Csv -LiteralPath (Join-Path $fixture 'samples-2026-10-19.csv') -Delimiter ';' -Encoding UTF8 | Select-Object -Skip 10 | ForEach-Object {Add-Sample $cut $_ $c $true}
if($cut.Timeline['Internet'].Open.State -ne 'loss' -or $cut.LastRow.P1PingEvaluation -ne 'Ready'){throw 'Partial report forgot recorded baseline and hid ongoing outage'}
# A long initially silent target may qualify later; no retrospective alarm/history rewrite.
$late=New-Aggregate
for($i=0;$i -lt 28;$i++) {$r=Sample $i;if($i -lt 20){Silence $r @('P1')};Add-Sample $late $r $c}
if($r.P1PingEvaluation -ne 'Ready'){throw 'Continued probing cannot qualify a returning target'}
$sum=@(Get-TargetSummary $late | Where-Object Target -like 'P1 *')[0]
if($sum.EvaluatedLost -ne 0 -or $sum.EvaluatedSent -ne 1){throw 'Learning losses counted retrospectively'}
# New route, target, session, or measurement gap resets qualification for that context.
$r=Sample 28;$r.P1RouteIfIndex=9;$r.PathScope='OtherAdapter';Add-Sample $late $r $c
if($r.P1PingEvaluation -ne 'Learning' -or $r.P2PingEvaluation -ne 'Ready'){throw 'Route reset not target-specific'}
$r=Sample 29;$r.P1Address='8.8.4.4';Add-Sample $late $r $c
if($r.P1PingEvaluation -ne 'Learning'){throw 'Target reset missing'}
$r=Sample 40;Add-Sample $late $r $c
if($r.P2PingEvaluation -ne 'Learning'){throw 'Sleep/gap reset missing'}
$r=Sample 41 'new-session';Add-Sample $late $r $c
if($r.P2PingWindowSamples -ne 1){throw 'Session reset missing'}
# All targets silent: not green and not red. TCP stays independent.
$all=New-Aggregate
for($i=0;$i -lt 20;$i++) {$r=Sample $i;Silence $r @('Gateway','P1','P2','P3');$r.Tcp1Status='Success';$r.Tcp1Ms=16;$r.Tcp2Status='Success';$r.Tcp2Ms=18;Add-Sample $all $r $c}
if($all.Timeline['Internet'].Open.State -ne 'unavailable' -or $all.Timeline['Tcp'].Open.State -ne 'ok'){throw 'Unassessable ping confused with working TCP'}
if(@($all.Recent.ToArray() | Where-Object sent -gt 0).Count){throw 'Unavailable ping chart incorrectly has a denominator'}
Write-View $all (Join-Path $scratch 'learning-all-silent.html') $false 'Alle Ping-Ziele still · synthetische Daten' $true @{Settings=$c}
# Invalid/local errors do not advance the valid-probe window or prove ICMP failure.
$errors=New-Aggregate
for($i=0;$i -lt 20;$i++) {$r=Sample $i;$r.P1Status='Error:PingException';Add-Sample $errors $r $c}
if($r.P1PingWindowSamples -ne 0 -or $r.P1PingAlarmEligible -ne 0){throw 'Local errors trained baseline'}
# Exact 8/10 qualification; seven responses are insufficient.
$threshold=New-Aggregate
for($i=0;$i -lt 10;$i++) {$r=Sample $i;if($i -ge 7){Silence $r @('P1')};Add-Sample $threshold $r $c}
if($r.P1PingEvaluation -eq 'Ready'){throw '7/10 incorrectly qualifies'}
$r=Sample 10;Add-Sample $threshold $r $c
if($r.P1PingEvaluation -eq 'Ready'){throw 'Rolling 7/10 incorrectly qualifies'}
Write-Host 'PASS: PS5.1 parse; 8/10 per-target learning; silent targets excluded from alarms but raw losses retained; one-of-one coverage; post-baseline prolonged failure remains red; later qualification; target/route/gap/session resets; all-silent neutral; independent TCP; local errors excluded.'
