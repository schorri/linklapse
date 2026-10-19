[CmdletBinding()]
param([switch]$NoOpen, [int]$MaxSamples=0, [double]$DurationMinutes=-1, [switch]$ChooseDuration, [switch]$EnableSpeed, [ValidateSet('de','en')][string]$Language='', [string]$SettingsFile='', [int]$OwnerPid=0, [switch]$PreserveStop)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Common.ps1')
$data=Join-Path $script:ProjectRoot 'data'
[IO.Directory]::CreateDirectory($data) | Out-Null
$lock=$null; $webTask=$null; $speedTask=$null; $powerGuard=$null
$webHistory=New-Object 'System.Collections.Generic.List[object]'
$speedHistory=New-Object 'System.Collections.Generic.List[object]'
function Save-WebTask {
    if ($null -eq $script:webTask -or -not $script:webTask.IsCompleted) { return }
    if ($script:webTask.IsFaulted) { throw $script:webTask.Exception }
    foreach ($w in $script:webTask.Result) {
        Add-CsvRow (Join-Path $data ("web-{0}.csv" -f ([datetimeoffset]::Parse($w.StartedUtc).UtcDateTime.ToString('yyyy-MM-dd')))) ([pscustomobject][ordered]@{
            SessionId=$session;StartedUtc=$w.StartedUtc;EndedUtc=$w.EndedUtc;Url=$w.Url;Status=$w.Status;HttpCode=$w.HttpCode;Ms=Fmt $w.Ms
            PathScopeAtStart=$script:webPath;Note='DNS/TCP/TLS/HTTP kombiniert; Web-Pfad kann IPv6/Proxy nutzen'
        })
        $script:webHistory.Add([pscustomobject]@{StartedUtc=$w.StartedUtc;EndedUtc=$w.EndedUtc;Url=$w.Url;Status=$w.Status;HttpCode=$w.HttpCode;Ms=$w.Ms});if($script:webHistory.Count -gt 100){$script:webHistory.RemoveAt(0)}
        $script:lastWeb="$($w.Status) / HTTP $($w.HttpCode)"
    }
    $script:webTask=$null
}
function Save-SpeedTask {
    if ($null -eq $script:speedTask -or -not $script:speedTask.IsCompleted) { return }
    if ($script:speedTask.IsFaulted) { throw $script:speedTask.Exception }
    $s=$script:speedTask.Result
    $speedRow=[pscustomobject][ordered]@{
        SessionId=$session;StartedUtc=$s.StartedUtc;EndedUtc=$s.EndedUtc;Url=$s.Url;Status=$s.Status;Bytes=$s.Bytes;Seconds=Fmt $s.Seconds
        Mbps=Fmt $s.Mbps;RateCapped=$s.Capped;PathScopeAtStart=$script:speedPath;MaxMiB=$c.Speed.MaxMiB;MaxMbps=$c.Speed.MaxMbps
        Note='Einzelner HTTPS-Download inkl. Verbindungsaufbau; kein Leitungskapazitätsnachweis'
    }
    Add-CsvRow (Join-Path $data ("speed-{0}.csv" -f ([datetimeoffset]::Parse($s.StartedUtc).UtcDateTime.ToString('yyyy-MM-dd')))) $speedRow
    $speedHistory.Add($speedRow);if ($speedHistory.Count -gt 100) {$speedHistory.RemoveAt(0)}
    $script:lastSpeed="$($s.Status): $(Fmt $s.Mbps) Mbit/s; $($s.Bytes) Bytes"
    $script:speedTask=$null
}
try {
    try { $lock=New-Object IO.FileStream((Join-Path $data 'monitor.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None) }
    catch { throw 'In diesem Ordner läuft bereits ein Monitor, oder der Datenordner ist nicht beschreibbar.' }
    $c=Read-Settings $SettingsFile
    if($Language){$c.Language=$Language}
    if ($EnableSpeed) {$c.Speed.Enabled=$true}
    if ($DurationMinutes -lt 0) { $DurationMinutes=[double]$c.DurationMinutes }
    if ($ChooseDuration) { $DurationMinutes=Select-Duration $DurationMinutes $c.Language }
    if ($DurationMinutes -lt 0 -or $DurationMinutes -gt 43200) { throw 'DurationMinutes: 0 (unbegrenzt) bis 43200 (30 Tage).' }
    if (-not ('InternetMonitor.Native' -as [type])) { Add-Type -Path @((Join-Path $PSScriptRoot 'Monitor.Core.cs'),(Join-Path $PSScriptRoot 'Topology.Core.cs')) }
    . (Join-Path $PSScriptRoot 'Topology.ps1')
    [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
    $selected=Select-NetworkAdapter $c
    $nic=$selected.Native;$nicId=[guid]$nic.Id;$ifIndex=$selected.Index
    $topology=New-TopologyState
    $powerGuard=New-Object InternetMonitor.PowerGuard
    $session=[guid]::NewGuid().ToString('N');$start=[datetime]::UtcNow
    $ends=if ($DurationMinutes -gt 0) {$start.AddMinutes($DurationMinutes).ToString('o')} else {''}
    $policy=Get-UpdatePolicyStatus
    $meta=[ordered]@{Version='0.1.0';SessionId=$session;StartedUtc=$start.ToString('o');TimeZone=[TimeZoneInfo]::Local.Id;InterfaceName=$nic.Name;InterfaceIndex=$ifIndex;Settings=$c;DurationMinutes=$DurationMinutes;PlannedEndUtc=$ends;PowerRequest=$true;UpdatePolicy=$policy}
    Write-AtomicText (Join-Path $data "session-$session.json") ($meta | ConvertTo-Json -Depth 8)
    $stopFile=Join-Path $data 'STOP'
    if (-not $PreserveStop -and (Test-Path -LiteralPath $stopFile)) { Remove-Item -LiteralPath $stopFile }
    $a=New-Aggregate;$seq=0;$last=$null;$nextTcp=[datetime]::MinValue;$nextWeb=[datetime]::MinValue
    # First optional speed probe is delayed by one minute to establish an unloaded baseline.
    $nextSpeed=$start.AddMinutes(1);$nextView=[datetime]::MinValue;$lastWeb='Noch nicht gemessen';$lastSpeed='Ausgeschaltet'
    if ($c.Speed.Enabled) { $lastSpeed='Erster Test nach einer Minute' }
    $watch=[Diagnostics.Stopwatch]::StartNew();$due=0.0;$opened=$false
    Write-Host "LinkLapse: '$($nic.Name)' (Index $ifIndex)." -ForegroundColor Cyan
    Write-Host 'Beenden: STOPP.cmd doppelklicken oder hier Q drücken. Fenster offen lassen.'
    Write-Host "CSV: $data"
    Write-Host ('Standbyschutz aktiv. Netzteil verwenden. Laufzeit: '+$(if ($ends) {$ends} else {'unbegrenzt'}))
    Write-Host $policy
    while (-not (Test-Path -LiteralPath $stopFile)) {
        if ($DurationMinutes -gt 0 -and $watch.Elapsed.TotalMinutes -ge $DurationMinutes) { break }
        if($OwnerPid -gt 0){try{$owner=Get-Process -Id $OwnerPid -ErrorAction Stop}catch{break}}
        $now=[datetime]::UtcNow
        Save-WebTask;Save-SpeedTask
        $selected=Select-NetworkAdapter $c $selected
        $nic=$selected.Native;$nicId=[guid]$nic.Id;$ifIndex=$selected.Index
        $wifi=New-Object InternetMonitor.WifiReading
        if($selected.Type -eq 'Wireless80211'){$wifi=[InternetMonitor.Native]::Wifi($nicId)}else{$wifi.State='NotApplicable'}
        $current=@($nic)
        Update-Topology $topology $c $data $session @(Get-NetworkAdapters)
        $gateway=''
        if ($current.Count -eq 1) {
            $g=@($current[0].GetIPProperties().GatewayAddresses | Where-Object { $_.Address.AddressFamily -eq 'InterNetwork' -and $_.Address.ToString() -ne '0.0.0.0' })
            if ($g.Count) { $gateway=$g[0].Address.ToString() }
        }
        $adapterNames=@{}
        foreach ($adapter in [Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces()) {
            try {$index=$adapter.GetIPProperties().GetIPv4Properties().Index;if (-not $adapterNames.ContainsKey($index)) {$adapterNames[$index]=$adapter.Name}} catch {}
        }
        $routes=@();$allSelected=$true;$unknown=$false
        foreach ($ip in @($c.InternetTargets)+@($c.TcpTargets | ForEach-Object { $_.Ip })) {
            $route=[InternetMonitor.Native]::Route($ip);$routes+=$route
            if ($route.Error -ne 0) { $unknown=$true;$allSelected=$false }
            elseif ($route.InterfaceIndex -ne $ifIndex) { $allSelected=$false }
        }
        $gatewayRoute=if ($gateway) { [InternetMonitor.Native]::Route($gateway) } else { $null }
        if ($null -eq $gatewayRoute -or $gatewayRoute.Error -ne 0) { $allSelected=$false;$unknown=$true }
        elseif ($gatewayRoute.InterfaceIndex -ne $ifIndex) { $allSelected=$false }
        $scope=if ($allSelected -and $selected.Type -eq 'Wireless80211') {'SelectedWifi'} elseif ($allSelected) {'SelectedInterface'} elseif ($unknown) {'Unknown'} else {'OtherAdapter'}
        $tcpDue=$now -ge $nextTcp
        $speedActive=($null -ne $speedTask)
        if ($c.Speed.Enabled -and $now -ge $nextSpeed -and $null -eq $speedTask) {
            if (@($routes | Where-Object {$_.Error -eq 0}).Count -gt 0) {
                $speedTask=[InternetMonitor.Probes]::Speed($c.Speed.Url,[int]($c.Speed.MaxMiB*1MB),[int]$c.Speed.MaxSeconds,[double]$c.Speed.MaxMbps)
                $script:speedPath=$scope;$speedActive=$true
            } else { $lastSpeed='Übersprungen: keine IPv4-Route erkannt' }
            $nextSpeed=$now.AddMinutes($c.Speed.EveryMinutes)
        }
        if ($now -ge $nextWeb -and $null -eq $webTask) {
            $webTask=[InternetMonitor.Probes]::Web([string[]]$c.WebUrls,[int]$c.WebTimeoutMs)
            $script:webPath=$scope;$nextWeb=$now.AddSeconds($c.WebEverySeconds)
        }
        $results=[InternetMonitor.Probes]::Round([string[]](@($gateway)+@($c.InternetTargets)),[string[]]@($c.TcpTargets | ForEach-Object {$_.Ip}),[int[]]@($c.TcpTargets | ForEach-Object {$_.Port}),[int]$c.PingTimeoutMs,$tcpDue)
        if ($tcpDue) { $nextTcp=$now.AddSeconds($c.TcpEverySeconds) }
        $seq++
        $r=[pscustomobject][ordered]@{
            SchemaVersion=1;TimestampUtc=$now.ToString('o');TimestampLocal=$now.ToLocalTime().ToString('o');SessionId=$session;Sequence=$seq
            IntervalSeconds=Fmt $c.IntervalSeconds;SincePreviousSeconds=$(if ($last) {Fmt (($now-$last).TotalSeconds)} else {''})
            InterfaceName=$nic.Name;InterfaceIndex=$ifIndex;NetworkType=$selected.Type;LinkState=$selected.Status;WifiState=$wifi.State;WifiError=$wifi.Error
            SignalPercent=$wifi.Signal;LinkRxMbps=Fmt $wifi.RxMbps;LinkTxMbps=Fmt $wifi.TxMbps
            PathScope=$scope;GatewayAddress=$gateway;GatewayRouteIfIndex=$(if ($gatewayRoute) {$gatewayRoute.InterfaceIndex} else {0})
            GatewayNextHop=$(if ($gatewayRoute) {$gatewayRoute.NextHop} else {''});GatewayRouteError=$(if ($gatewayRoute) {$gatewayRoute.Error} else {1})
            GatewayStatus=$results[0].Status;GatewayMs=Fmt $results[0].Ms
            P1Address=$c.InternetTargets[0];P1RouteIfIndex=$routes[0].InterfaceIndex;P1NextHop=$routes[0].NextHop;P1RouteError=$routes[0].Error;P1Status=$results[1].Status;P1Ms=Fmt $results[1].Ms
            P2Address=$c.InternetTargets[1];P2RouteIfIndex=$routes[1].InterfaceIndex;P2NextHop=$routes[1].NextHop;P2RouteError=$routes[1].Error;P2Status=$results[2].Status;P2Ms=Fmt $results[2].Ms
            P3Address=$c.InternetTargets[2];P3RouteIfIndex=$routes[2].InterfaceIndex;P3NextHop=$routes[2].NextHop;P3RouteError=$routes[2].Error;P3Status=$results[3].Status;P3Ms=Fmt $results[3].Ms
            Tcp1Address=$c.TcpTargets[0].Ip;Tcp1Port=$c.TcpTargets[0].Port;Tcp1RouteIfIndex=$routes[3].InterfaceIndex;Tcp1NextHop=$routes[3].NextHop
            Tcp1Status=$(if ($tcpDue) {$results[4].Status} else {'NotTested'});Tcp1Ms=$(if ($tcpDue) {Fmt $results[4].Ms} else {'-1'})
            Tcp2Address=$c.TcpTargets[1].Ip;Tcp2Port=$c.TcpTargets[1].Port;Tcp2RouteIfIndex=$routes[4].InterfaceIndex;Tcp2NextHop=$routes[4].NextHop
            Tcp2Status=$(if ($tcpDue) {$results[5].Status} else {'NotTested'});Tcp2Ms=$(if ($tcpDue) {Fmt $results[5].Ms} else {'-1'})
            GatewayRouteAdapter=$(if ($gatewayRoute) {$adapterNames[$gatewayRoute.InterfaceIndex]} else {''})
            P1RouteAdapter=$adapterNames[$routes[0].InterfaceIndex];P2RouteAdapter=$adapterNames[$routes[1].InterfaceIndex];P3RouteAdapter=$adapterNames[$routes[2].InterfaceIndex]
            Tcp1RouteAdapter=$adapterNames[$routes[3].InterfaceIndex];Tcp2RouteAdapter=$adapterNames[$routes[4].InterfaceIndex]
            SpeedActive=[int]$speedActive;PowerSource=[InternetMonitor.PowerGuard]::Source();StandbyRequest=1;Observation=''
        }
        Add-Sample $a $r $c
        Add-CsvRow (Join-Path $data ("samples-{0}.csv" -f $now.ToString('yyyy-MM-dd'))) $r
        $last=$now
        if ($now -ge $nextView) {
            Write-View $a (Join-Path $data 'session.html') $true 'Internet-Stabilität · laufende Sitzung' $false @{Web=$lastWeb;Speed=$lastSpeed;SpeedTests=$speedHistory.ToArray();WebTests=$webHistory.ToArray();Topology=(Get-TopologySnapshot $topology $c);Settings=$c;Standby='Aktiver Windows-Energiebedarf angefordert';UpdatePolicy=(Get-UpdatePolicyStatus);PlannedEndUtc=$ends;DurationMinutes=$DurationMinutes} -JsonPath (Join-Path $data 'live.json')
            Write-AtomicText (Join-Path $data ('topology-'+$session+'.json')) (Get-TopologySnapshot $topology $c | ConvertTo-Json -Depth 16)
            $nextView=$now.AddSeconds($c.DashboardEverySeconds)
            Write-Host ("{0} | WLAN {1}% | {2} | {3}" -f $now.ToLocalTime().ToString('HH:mm:ss'),$wifi.Signal,$scope,$r.Observation)
            if (-not $opened -and -not $NoOpen) { Start-Process (Join-Path $data 'session.html');$opened=$true }
        }
        # Closed events can be reconstructed from CSV; retain 200 for the live table.
        if ($a.Events.Count -gt 200) {
            $remove=$a.Events.Count-200;$a.Events.RemoveRange(0,$remove)
        }
        if ($MaxSamples -gt 0 -and $seq -ge $MaxSamples) { break }
        try { if (-not [Console]::IsInputRedirected -and [Console]::KeyAvailable) { if ([Console]::ReadKey($true).Key -eq 'Q') { break } } } catch {}
        $due+=$c.IntervalSeconds
        # Do not send catch-up bursts after sleep, slow disk or delayed probes.
        if ($watch.Elapsed.TotalSeconds -gt $due) { $due=$watch.Elapsed.TotalSeconds }
        $remaining=$due-$watch.Elapsed.TotalSeconds
        if ($remaining -gt 0) { Start-Sleep -Milliseconds ([int]($remaining*1000)) }
    }
    Close-Observation $a $null 'Monitor beendet; Erholung nicht belegt'
    Write-Host 'Monitor beendet. Für den vollständigen Zeitraum BERICHT.cmd starten.' -ForegroundColor Green
} catch {
    Write-Host ("FEHLER: " + $_.Exception.Message) -ForegroundColor Red
    $_ | Out-String | Add-Content -LiteralPath (Join-Path $data 'Fehler.log') -Encoding UTF8
    exit 1
} finally {
    # Finish already started requests within their configured deadlines and preserve their results.
    foreach ($task in @($webTask,$speedTask,$topology.TraceTask,$topology.ProbeTask)) { if ($null -ne $task) { try { $task.Wait(65000) | Out-Null } catch {} } }
    try {
        Save-WebTask;Save-SpeedTask
        if($topology){Update-Topology $topology $c $data $session @(Get-NetworkAdapters) -Finish;Write-AtomicText (Join-Path $data ('topology-'+$session+'.json')) (Get-TopologySnapshot $topology $c | ConvertTo-Json -Depth 16)}
        if ($a -and $a.Count -gt 0) { Write-View $a (Join-Path $data 'session.html') $false 'Internet-Stabilität · beendete Sitzung' $false @{Web=$lastWeb;Speed=$lastSpeed;SpeedTests=$speedHistory.ToArray();WebTests=$webHistory.ToArray();Topology=(Get-TopologySnapshot $topology $c);Settings=$c;Standby='Freigegeben nach Messende';UpdatePolicy=(Get-UpdatePolicyStatus);PlannedEndUtc=$ends;DurationMinutes=$DurationMinutes} -JsonPath (Join-Path $data 'live.json') }
    } catch { Write-Warning $_.Exception.Message }
    if ($powerGuard) { $powerGuard.Dispose() }
    if ($lock) { $lock.Dispose() }
}
