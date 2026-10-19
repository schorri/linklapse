# Shared functions, compatible with Windows PowerShell 5.1. Dot-source only.
$script:ProjectRoot=Split-Path $PSScriptRoot -Parent
$script:Inv = [Globalization.CultureInfo]::InvariantCulture
$script:CsvHeaders=@{}
function Num($Value) {
    if ($null -eq $Value -or "$Value" -eq '') { return -1.0 }
    return [double]::Parse([string]$Value, $script:Inv)
}
function Fmt($Value) { return ([double]$Value).ToString('0.###', $script:Inv) }
function Write-AtomicText([string]$Path, [string]$Text) {
    $temp = $Path + '.' + [guid]::NewGuid().ToString('N') + '.tmp'
    try {
        [IO.File]::WriteAllText($temp, $Text, (New-Object Text.UTF8Encoding($true)))
        if ([IO.File]::Exists($Path)) { [IO.File]::Replace($temp, $Path, [NullString]::Value) }
        else { [IO.File]::Move($temp, $Path) }
    } finally { if ([IO.File]::Exists($temp)) { [IO.File]::Delete($temp) } }
}
function Add-CsvRow([string]$Path, $Row) {
    # UTF-8 BOM + semicolon for German Excel. Each complete row is flushed.
    $exists = [IO.File]::Exists($Path)
    $lines = @($Row | ConvertTo-Csv -Delimiter ';' -NoTypeInformation)
    if ($exists -and -not $script:CsvHeaders.ContainsKey($Path)) {
        $reader=[IO.File]::OpenText($Path)
        try {$header=$reader.ReadLine()} finally {$reader.Dispose()}
        if ($header -ne $lines[0]) {throw "CSV-Spalten passen nicht zur vorhandenen Datei: $Path. Alten Logordner zuerst sichern; nicht mischen."}
    }
    if ($script:CsvHeaders.ContainsKey($Path) -and $script:CsvHeaders[$Path] -ne $lines[0]) {throw "Wechselnde CSV-Spalten: $Path"}
    $script:CsvHeaders[$Path]=$lines[0]
    $stream = New-Object IO.FileStream($Path, [IO.FileMode]::Append, [IO.FileAccess]::Write, [IO.FileShare]::ReadWrite)
    $writer = New-Object IO.StreamWriter($stream, (New-Object Text.UTF8Encoding($true)))
    try {
        if (-not $exists) { $writer.WriteLine($lines[0]) }
        $writer.WriteLine($lines[1]); $writer.Flush()
    } finally { $writer.Dispose() }
}
function Read-Settings([string]$Path='') {
    if(-not $Path){$Path=Join-Path $script:ProjectRoot 'config.json'}
    $c = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($c.DurationMinutes -lt 0 -or $c.DurationMinutes -gt 43200) {throw 'DurationMinutes: 0 (unbegrenzt) oder höchstens 43200 Minuten (30 Tage).'}
    if ($c.IntervalSeconds -lt 1 -or $c.IntervalSeconds -gt 60) { throw 'IntervalSeconds muss zwischen 1 und 60 liegen.' }
    if ($c.PingTimeoutMs -lt 100 -or $c.PingTimeoutMs -ge $c.IntervalSeconds * 1000) { throw 'PingTimeoutMs muss >= 100 und kleiner als das Messintervall in ms sein.' }
    foreach ($key in @('TcpEverySeconds','WebEverySeconds','DashboardEverySeconds')) {
        if ($c.$key -lt 1) { throw "$key muss mindestens 1 sein." }
    }
    if ($c.WebTimeoutMs -lt 500 -or $c.WebTimeoutMs -gt 30000) { throw 'WebTimeoutMs: 500 bis 30000.' }
    if (@($c.InternetTargets).Count -ne 3 -or @($c.TcpTargets).Count -ne 2) { throw 'Genau drei InternetTargets und zwei TcpTargets konfigurieren.' }
    if (@($c.InternetTargets | Select-Object -Unique).Count -ne 3) { throw 'Drei unterschiedliche InternetTargets erforderlich.' }
    foreach ($ip in @($c.InternetTargets) + @($c.TcpTargets | ForEach-Object { $_.Ip })) {
        $parsed = [Net.IPAddress]::Parse($ip)
        if ($parsed.AddressFamily -ne [Net.Sockets.AddressFamily]::InterNetwork) { throw 'Dieses Paket misst IPv4; bitte IPv4-Adressen angeben.' }
    }
    foreach ($t in $c.TcpTargets) { if ($t.Port -lt 1 -or $t.Port -gt 65535) { throw 'Ungültiger TCP-Port.' } }
    foreach ($url in @($c.WebUrls) + @($c.Speed.Url)) {
        if (([uri]$url).Scheme -ne 'https') { throw 'Web- und Speed-URLs müssen HTTPS verwenden.' }
    }
    if (@($c.WebUrls).Count -ne 2) { throw 'Genau zwei WebUrls erforderlich.' }
    if ($c.Speed.EveryMinutes -lt 15 -or $c.Speed.MaxMiB -lt 1 -or $c.Speed.MaxMiB -gt 50 -or $c.Speed.MaxSeconds -lt 2 -or $c.Speed.MaxSeconds -gt 60 -or $c.Speed.MaxMbps -lt 0) {
        throw 'Speed: Intervall >=15 Minuten, Volumen 1..50 MiB, Dauer 2..60 Sekunden, MaxMbps >=0.'
    }
    if ($c.Language -notin @('de','en')) {throw 'Language: de or en.'}
    if ($c.Topology.MaxHops -lt 1 -or $c.Topology.MaxHops -gt 30 -or $c.Topology.TimeoutMs -lt 100 -or $c.Topology.TimeoutMs -gt 1000 -or $c.Topology.DiscoverEveryMinutes -lt 5 -or $c.Topology.ProbeEverySeconds -lt 5 -or $c.Topology.MaxMonitoredHops -lt 0 -or $c.Topology.MaxMonitoredHops -gt 8 -or $c.Topology.HighHopLatencyMs -lt 1) {throw 'Invalid topology limits: hops 1..30, timeout 100..1000 ms, discovery >=5 min, probes >=5 s, monitored hops 0..8.'}
    if ($c.Topology.AccessPointAddress -and ([Net.IPAddress]::Parse($c.Topology.AccessPointAddress)).AddressFamily -ne 'InterNetwork') {throw 'AccessPointAddress must be a known IPv4 management address.'}
    if ($c.Speed.ExpectedMbps -lt 0 -or $c.Speed.SlowRatio -le 0 -or $c.Speed.SlowRatio -ge 1) {throw 'ExpectedMbps >=0; SlowRatio between 0 and 1.'}
    return $c
}
function Select-Duration([double]$Default=0,[string]$Language='de') {
    if($Language -eq 'en'){Write-Host 'Duration: 1=5 minutes, 2=1 hour, 3=24 hours, 4=3 days, 5=7 days, 6=14 days, 7=30 days, 8=Unlimited'}
    else {Write-Host 'Messdauer: 1=5 Minuten, 2=1 Stunde, 3=24 Stunden, 4=3 Tage, 5=7 Tage, 6=14 Tage, 7=30 Tage, 8=Unbegrenzt'}
    $value=if($Language -eq 'en'){Read-Host "Choice (Enter = configuration: $Default minutes, 0 = unlimited)"}else{Read-Host "Auswahl (Enter = Konfiguration: $Default Minuten, 0 = unbegrenzt)"}
    $map=@{'0'=0;'1'=5;'2'=60;'3'=1440;'4'=4320;'5'=10080;'6'=20160;'7'=43200;'8'=0}
    if (-not $value) { return $Default }
    if (-not $map.ContainsKey($value)) { throw 'Ungültige Auswahl. Bitte neu starten und 1 bis 8 wählen.' }
    return [double]$map[$value]
}
function Get-UpdatePolicyStatus {
    $key='HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'
    try { $v=Get-ItemProperty -LiteralPath $key -Name NoAutoUpdate -ErrorAction Stop
        if ($v.NoAutoUpdate -eq 1) { return 'Lokale Richtlinie: automatische Windows-Updates deaktiviert (Neustartschutz nicht absolut)' }
    } catch {}
    return 'Keine aktive NoAutoUpdate-Richtlinie festgestellt'
}
function Get-ProbePath($r,[string]$Prefix) {
    $idx=[int]$r."${Prefix}RouteIfIndex"
    $label=[string]$r."${Prefix}RouteAdapter"
    if ($idx -gt 0) {
        if (-not $label) {$label="Adapter #$idx"}
        $hop=[string]$r."${Prefix}NextHop"
        if($hop -and $hop -ne '0.0.0.0'){$label+=' via '+$hop}
        if ($idx -eq [int]$r.InterfaceIndex) {return "Selected interface: $label (#$idx)"}
        return "Anderer Pfad: $label (#$idx)"
    }
    if ($r.PathScope -eq 'SelectedWifi') {return 'WLAN: '+[string]$r.InterfaceName}
    return 'Route unbekannt'
}
function Get-LayerPath($r,[string]$Layer) {
    $prefixes=switch ($Layer) {'Gateway' {@('Gateway')} 'Internet' {@('P1','P2','P3')} 'Tcp' {@('Tcp1','Tcp2')} default {@()}}
    if ($Layer -eq 'Wifi') {return 'WLAN-Adapter: '+[string]$r.InterfaceName}
    $parts=@(@(foreach ($prefix in $prefixes) {Get-ProbePath $r $prefix}) | Select-Object -Unique)
    return $parts -join ' | '
}
function Get-Observation($r,$c) {return Get-LearnedObservation $r $c}
function New-Aggregate {
    return @{
        Count=0L; Excluded=0L; LoadCount=0L; SignalMissing=0L; First=$null; Last=$null; LastRow=$null
        GapSeconds=0.0; ObservedSeconds=0.0; Gaps=0; Sessions=@{}; Targets=@{}; States=@{}
        Buckets=(New-Object 'System.Collections.Generic.SortedDictionary[long,object]')
        Hours=(New-Object 'System.Collections.Generic.SortedDictionary[long,object]')
        Days=(New-Object 'System.Collections.Generic.SortedDictionary[long,object]')
        Recent=(New-Object 'System.Collections.Generic.Queue[object]')
        Timeline=@{}
        TimelineGaps=(New-Object 'System.Collections.Generic.List[object]')
        CompletedTimeline=(New-Object 'System.Collections.Generic.List[object]')
        Events=(New-Object 'System.Collections.Generic.List[object]'); Open=$null; EventCount=0
    }
}
function Add-TimelineState($a,[string]$Layer,[string]$State,[string]$Label,$r,[double]$MaxMs=-1,[int]$Failed=0,[int]$Succeeded=0) {
    if (-not $a.Timeline.ContainsKey($Layer)) { $a.Timeline[$Layer]=@{Open=$null;Segments=(New-Object 'System.Collections.Generic.List[object]')} }
    $track=$a.Timeline[$Layer]
    $path=Get-LayerPath $r $Layer
    if ($track.Open -and ($track.Open.State -ne $State -or $track.Open.Path -ne $path)) {
        $track.Open.NextObservationUtc=$r.TimestampUtc
        $closed=[pscustomobject]$track.Open;$track.Segments.Add($closed);$a.CompletedTimeline.Add($closed);$track.Open=$null
    }
    if (-not $track.Open) {
        $track.Open=[ordered]@{Layer=$Layer;State=$State;Label=$Label;Path=$path;SessionId=$r.SessionId;StartUtc=$r.TimestampUtc;LastObservedUtc=$r.TimestampUtc
            NextObservationUtc='';Samples=0;FailedProbes=0;SuccessfulProbes=0;MaxMs=-1.0;SignalMin=-1.0;SpeedSamples=0}
    }
    $o=$track.Open;$o.LastObservedUtc=$r.TimestampUtc;$o.Samples++;$o.Label=$Label
    $o.FailedProbes+=$Failed;$o.SuccessfulProbes+=$Succeeded;$o.MaxMs=[math]::Max($o.MaxMs,$MaxMs)
    $signal=Num $r.SignalPercent
    if ($signal -ge 0) {if ($o.SignalMin -lt 0) {$o.SignalMin=$signal} else {$o.SignalMin=[math]::Min($o.SignalMin,$signal)}}
    if ([string]$r.SpeedActive -eq '1') {$o.SpeedSamples++}
    while ($track.Segments.Count -gt 500) {$track.Segments.RemoveAt(0)}
}
function Add-TimelineSample($a,$r,$Settings) {
    $internetThreshold=150;$gatewayThreshold=30;$wifiThreshold=40
    if ($Settings) {$internetThreshold=$Settings.HighInternetLatencyMs;$gatewayThreshold=$Settings.HighGatewayLatencyMs;$wifiThreshold=$Settings.WeakWifiPercent}
    $signal=Num $r.SignalPercent
    if ($r.WifiState -eq 'NotApplicable') {
        Add-TimelineState $a 'Wifi' 'unavailable' 'Wi-Fi not used on this interface' $r
    } elseif ($r.WifiState -eq 'Connected') {
        if ($signal -ge 0 -and $signal -lt $wifiThreshold) {Add-TimelineState $a 'Wifi' 'weak' 'Niedriger WLAN-Signalwert' $r}
        else {Add-TimelineState $a 'Wifi' 'ok' 'WLAN verbunden' $r}
    } elseif ($r.WifiState -in @('Disconnected','Disconnecting','NotReady','Associating','Discovering','Authenticating')) {
        Add-TimelineState $a 'Wifi' 'loss' 'WLAN nicht verbunden' $r
    } else {Add-TimelineState $a 'Wifi' 'unknown' 'WLAN-Zustand nicht verfügbar' $r}
    if ($r.LinkState) {Add-TimelineState $a 'Link' $(if($r.LinkState -eq 'Up'){'ok'}else{'loss'}) ([string]$r.LinkState) $r}
    $g=Num $r.GatewayMs
    if (Test-PingEvaluated $r 'Gateway') {
        if ($r.GatewayStatus -ne 'Success') {Add-TimelineState $a 'Gateway' 'loss' 'Zuvor auswertbares Gateway ohne Ping-Antwort' $r -1 1 0}
        elseif ($g -ge $gatewayThreshold) {Add-TimelineState $a 'Gateway' 'latency' 'Erhöhte Gateway-Latenz' $r $g 0 1}
        else {Add-TimelineState $a 'Gateway' 'ok' 'Gateway antwortet (Ping-Basis gelernt)' $r $g 0 1}
    } elseif ($r.GatewayPingEvaluation -eq 'Learning') {Add-TimelineState $a 'Gateway' 'learning' 'Gateway-Ping: Lernphase' $r}
    else {Add-TimelineState $a 'Gateway' 'unavailable' 'Gateway-Ping hier nicht auswertbar' $r}
    $internet=Get-InternetPingState $r $Settings
    Add-TimelineState $a 'Internet' $internet.State $internet.Label $r $internet.MaxMs $internet.Failed $internet.Ok
    if ($r.Tcp1Status -eq 'NotTested' -and $r.Tcp2Status -eq 'NotTested') {return}
    $success=0;$tested=0;$tcpMax=-1.0
    foreach ($i in @(1,2)) {
        $s=[string]$r."Tcp${i}Status"
        if ($s -notin @('NotTested','')) {$tested++;if ($s -eq 'Success') {$success++;$tcpMax=[math]::Max($tcpMax,(Num $r."Tcp${i}Ms"))}}
    }
    if (-not $tested) {return}
    if ($success -eq $tested) {Add-TimelineState $a 'Tcp' 'ok' 'TCP-Verbindungen erfolgreich' $r $tcpMax 0 $tested}
    elseif ($success -eq 0) {Add-TimelineState $a 'Tcp' 'loss' 'TCP-Verbindungen nicht erfolgreich' $r $tcpMax $tested 0}
    else {Add-TimelineState $a 'Tcp' 'partial' 'Ein TCP-Ziel nicht erreichbar' $r $tcpMax ($tested-$success) $success}
}
function Close-Observation($a, $end, [string]$reason) {
    if ($null -eq $a.Open) { return }
    $o=$a.Open
    $event=[pscustomobject][ordered]@{
        SessionId=$o.Session; StartUtc=$o.Start.ToString('o'); LastObservedUtc=$o.Last.ToString('o')
        NextObservationUtc=$(if ($null -ne $end) { $end.ToString('o') } else { '' })
        MinimumSpanSeconds=(Fmt (($o.Last-$o.Start).TotalSeconds))
        Observation=$o.State; Samples=$o.Count; SpeedActiveSamples=$o.Load; EndReason=$reason
    }
    $a.Events.Add($event); $a.EventCount++; $a.Open=$null
}
function Add-Sample($a, $r, $Settings=$null, [bool]$UseRecordedEvaluation=$false) {
    $a.CompletedTimeline.Clear()
    $time=[datetimeoffset]::Parse($r.TimestampUtc).UtcDateTime
    if ($null -eq $a.First) { $a.First=$time }
    $a.Count++; $a.Last=$time; $a.Sessions[[string]$r.SessionId]=$true
    $interval=Num $r.IntervalSeconds
    $continuous=$false
    if ($null -ne $a.LastRow) {
        $previous=[datetimeoffset]::Parse($a.LastRow.TimestampUtc).UtcDateTime
        $delta=($time-$previous).TotalSeconds
        $continuous=($r.SessionId -eq $a.LastRow.SessionId -and $delta -gt 0 -and $delta -le [math]::Max(3*$interval,3))
        if ($continuous) { $a.ObservedSeconds+=$delta }
        else {
            Close-Observation $a $null 'Messpause/Sitzungswechsel/Uhrsprung'
            $a.Gaps++; if ($delta -gt 0) { $a.GapSeconds+=$delta }
            foreach ($track in $a.Timeline.Values) {
                if ($track.Open) {$closed=[pscustomobject]$track.Open;$track.Segments.Add($closed);$a.CompletedTimeline.Add($closed);$track.Open=$null}
            }
            $a.TimelineGaps.Add([pscustomobject]@{StartUtc=$previous.ToString('o');LastObservedUtc=$time.ToString('o');Seconds=$delta;Reason='Messpause / Sitzungswechsel / Uhrsprung'})
            while ($a.TimelineGaps.Count -gt 200) {$a.TimelineGaps.RemoveAt(0)}
        }
    }
    $recorded=($UseRecordedEvaluation -and [string]$r.PingRuleVersion -eq '1')
    if ($recorded) {
        foreach ($prefix in @('Gateway','P1','P2','P3')) {
            if ($r."${prefix}PingEvaluation" -notin @('Ready','Learning','Unavailable','NoRoute') -or [string]$r."${prefix}PingAlarmEligible" -notin @('0','1')) {$recorded=$false}
        }
    }
    if (-not $recorded) {Update-PingLearning $a $r}
    $effective=$Settings
    if (-not $effective) {$effective=[pscustomobject]@{HighInternetLatencyMs=150;HighGatewayLatencyMs=30;WeakWifiPercent=40}}
    $r.Observation=Get-Observation $r $effective
    Add-TimelineSample $a $r $Settings
    if ((Num $r.SignalPercent) -lt 0) { $a.SignalMissing++ }
    if ([string]$r.SpeedActive -eq '1') { $a.LoadCount++ }
    if ($r.PathScope -notin @('SelectedWifi','SelectedInterface')) { $a.Excluded++ }
    if (-not $a.States.ContainsKey($r.Observation)) { $a.States[$r.Observation]=0L }
    $a.States[$r.Observation]++
    if ($null -ne $a.Open -and ($a.Open.State -ne $r.Observation -or -not $continuous)) { Close-Observation $a $time 'Beobachtung gewechselt' }
    if ($r.Observation -ne 'Unauffällig') {
        if ($null -eq $a.Open) { $a.Open=@{Session=$r.SessionId;State=$r.Observation;Start=$time;Last=$time;Count=0;Load=0} }
        $a.Open.Last=$time; $a.Open.Count++; if ([string]$r.SpeedActive -eq '1') { $a.Open.Load++ }
    }
    $minute=[long][math]::Floor(($time-[datetime]'1970-01-01').TotalMinutes)
    $routeChanged=$false
    if($a.LastRow){foreach($prefix in @('Gateway','P1','P2','P3')){
        foreach($suffix in @('Address','RouteIfIndex','NextHop')){
            if([string]$r."$prefix$suffix" -ne [string]$a.LastRow."$prefix$suffix"){$routeChanged=$true}
        }
    }}
    if (-not $a.Buckets.ContainsKey($minute)) {
        $a.Buckets.Add($minute,@{t=$minute*60000;signal=-1.0;n=0;sent=0;lost=0;gw=-1.0;p1=-1.0;p2=-1.0;p3=-1.0;speed=0;gap=0})
    }
    $b=$a.Buckets[$minute]; $b.n++
    if ($a.LastRow -and (-not $continuous -or $routeChanged)) { $b.gap=1 }
    if ((Num $r.SignalPercent) -ge 0) {
        if ($b.signal -lt 0) { $b.signal=Num $r.SignalPercent } else { $b.signal=[math]::Min($b.signal,(Num $r.SignalPercent)) }
    }
    if ([string]$r.SpeedActive -eq '1') { $b.speed++ }
    foreach ($prefix in @('Gateway','P1','P2','P3','Tcp1','Tcp2')) {
        $target=[string]$r."${prefix}Address"
        $status=[string]$r."${prefix}Status"
        $ms=Num $r."${prefix}Ms"
        if ($target -ne '' -and $status -notlike 'Error:*' -and $status -notin @('NoGateway','NotTested','')) {
            $path=Get-ProbePath $r $prefix
            $key="$prefix / $target / $path"
            if (-not $a.Targets.ContainsKey($key)) { $a.Targets[$key]=@{Sent=0L;Ok=0L;Sum=0.0;Max=-1.0;Hist=@{};LoadedSent=0L;LoadedLost=0L;EvaluatedSent=0L;EvaluatedLost=0L;Evaluation='NotApplicable'} }
            $s=$a.Targets[$key]; $s.Sent++
            if ($prefix -in @('Gateway','P1','P2','P3')) {
                $s.Evaluation=[string]$r."${prefix}PingEvaluation"
                if (Test-PingEvaluated $r $prefix) {$s.EvaluatedSent++;if ($status -ne 'Success') {$s.EvaluatedLost++}}
            }
            if ([string]$r.SpeedActive -eq '1') { $s.LoadedSent++; if ($status -ne 'Success') { $s.LoadedLost++ } }
            if ($status -eq 'Success') {
                $s.Ok++;$s.Sum+=$ms;$s.Max=[math]::Max($s.Max,$ms)
                $h=[int][math]::Round($ms);if (-not $s.Hist.ContainsKey($h)) { $s.Hist[$h]=0L };$s.Hist[$h]++
            }
            if ($prefix -in @('P1','P2','P3') -and (Test-PingEvaluated $r $prefix)) { $b.sent++;if ($status -ne 'Success') { $b.lost++ } }
        }
        # Plot observed responses on Windows-selected routes, with explicit path labeling.
        if ($prefix -in @('Gateway','P1','P2','P3') -and $status -eq 'Success') {
            $name=$prefix.ToLowerInvariant();if ($prefix -eq 'Gateway') { $name='gw' }
            $b[$name]=[math]::Max($b[$name],$ms)
        }
    }
    # Parallel resolutions keep short events visible while bounding long-run HTML size.
    $point=@{t=[long](($time-[datetime]'1970-01-01').TotalMilliseconds);signal=(Num $r.SignalPercent);gw=-1.0;p1=-1.0;p2=-1.0;p3=-1.0;path=$r.PathScope;sent=0;lost=0;speed=[int]$r.SpeedActive;gap=[int]($a.LastRow -and (-not $continuous -or $routeChanged))}
    foreach ($prefix in @('Gateway','P1','P2','P3')) {
        $status=[string]$r."${prefix}Status";$name=$prefix.ToLowerInvariant();if ($prefix -eq 'Gateway') {$name='gw'}
        if ($status -eq 'Success') { $point[$name]=Num $r."${prefix}Ms" }
        if ($prefix -ne 'Gateway' -and (Test-PingEvaluated $r $prefix) -and $status -notlike 'Error:*' -and $status -notin @('NotTested','NoGateway','')) {$point.sent++;if ($status -ne 'Success') {$point.lost++}}
    }
    $a.Recent.Enqueue($point)
    while ($a.Recent.Count -gt 3601 -or ($a.Recent.Count -gt 1 -and $a.Recent.Peek().t -lt $point.t-3600000)) { $a.Recent.Dequeue() | Out-Null }
    foreach ($resolution in @(@{Store=$a.Hours;Size=3600000},@{Store=$a.Days;Size=86400000})) {
        $key=[long][math]::Floor($point.t/$resolution.Size)
        if (-not $resolution.Store.ContainsKey($key)) { $resolution.Store.Add($key,@{t=$key*$resolution.Size;signal=-1.0;gw=-1.0;p1=-1.0;p2=-1.0;p3=-1.0;sent=0L;lost=0L;speed=0L;gap=0}) }
        $target=$resolution.Store[$key]
        foreach ($field in @('gw','p1','p2','p3')) { $target[$field]=[math]::Max($target[$field],$point[$field]) }
        if ($point.signal -ge 0) {if ($target.signal -lt 0) {$target.signal=$point.signal} else {$target.signal=[math]::Min($target.signal,$point.signal)}}
        $target.sent+=$point.sent;$target.lost+=$point.lost;$target.speed+=$point.speed;$target.gap=[math]::Max($target.gap,$point.gap)
    }
    while ($a.Hours.Count -gt 720) { $old=@($a.Hours.Keys)[0];$a.Hours.Remove($old) | Out-Null }
    # Keep minute data for the latest 24 hours; totals retain the complete period.
    while ($a.Buckets.Count -gt 1440) { $old=@($a.Buckets.Keys)[0];$a.Buckets.Remove($old) | Out-Null }
    $a.LastRow=$r
}
function Get-TargetSummary($a) {
    foreach ($key in @($a.Targets.Keys | Sort-Object)) {
        $s=$a.Targets[$key];$p95=-1;$rank=[math]::Ceiling($s.Ok*0.95);$n=0L
        foreach ($k in @($s.Hist.Keys | Sort-Object { [int]$_ })) { $n+=$s.Hist[$k];if ($n -ge $rank -and $s.Ok -gt 0) { $p95=[int]$k;break } }
        [pscustomobject]@{Target=$key;Sent=$s.Sent;Lost=($s.Sent-$s.Ok);LossPercent=[math]::Round(100.0*($s.Sent-$s.Ok)/$s.Sent,2)
            AverageMs=$(if ($s.Ok) { [math]::Round($s.Sum/$s.Ok,1) } else { $null });P95Ms=$(if ($p95 -ge 0) {$p95} else {$null})
            MaxMs=$(if ($s.Ok) {$s.Max} else {$null});LoadedSent=$s.LoadedSent;LoadedLost=$s.LoadedLost;Evaluation=$s.Evaluation;EvaluatedSent=$s.EvaluatedSent;EvaluatedLost=$s.EvaluatedLost
            EvaluatedLossPercent=$(if($s.EvaluatedSent){[math]::Round(100.0*$s.EvaluatedLost/$s.EvaluatedSent,2)}else{$null})}
    }
}
function Write-View($a, [string]$Path, [bool]$Live, [string]$Title, [bool]$Demo=$false, $Extra=$null, [string]$JsonPath='') {
    $events=@($a.Events | Select-Object -Last 200)
    if ($null -ne $a.Open) {
        $o=$a.Open
        $events+= [pscustomobject]@{StartUtc=$o.Start.ToString('o');LastObservedUtc=$o.Last.ToString('o');MinimumSpanSeconds=Fmt (($o.Last-$o.Start).TotalSeconds);Observation=$o.State;Samples=$o.Count;SpeedActiveSamples=$o.Load;EndReason='Offen am Datenende'}
    }
    $payload=[ordered]@{
        title=$Title;live=$Live;demo=$Demo;generated=[datetime]::UtcNow.ToString('o');first=$(if ($a.First) {$a.First.ToString('o')} else {''})
        last=$(if ($a.Last) {$a.Last.ToString('o')} else {''});count=$a.Count;excluded=$a.Excluded;loadCount=$a.LoadCount
        signalMissing=$a.SignalMissing;gapSeconds=$a.GapSeconds;observedSeconds=$a.ObservedSeconds;gaps=$a.Gaps;sessions=$a.Sessions.Count
        lastRow=$a.LastRow;targets=@(Get-TargetSummary $a);states=$a.States;points=@($a.Buckets.Values)
        recent=$a.Recent.ToArray();hours=@($a.Hours.Values);days=@($a.Days.Values)
        events=$events;eventCount=($a.EventCount + [int]($null -ne $a.Open));extra=$Extra
        timeline=@(foreach ($layer in @('Link','Wifi','Gateway','Internet','Tcp')) {
            if ($a.Timeline.ContainsKey($layer)) {
                $track=$a.Timeline[$layer];$segments=@($track.Segments.ToArray())
                if ($track.Open) {$segments+=[pscustomobject]$track.Open}
                [pscustomobject]@{Layer=$layer;Segments=$segments}
            }
        });timelineGaps=$a.TimelineGaps.ToArray()
    }
    $json=$payload | ConvertTo-Json -Depth 18 -Compress
    $json=$json.Replace('<','\u003c').Replace('>','\u003e').Replace('&','\u0026')
    $template=[IO.File]::ReadAllText((Join-Path $script:ProjectRoot 'web/Dashboard.template.html'))
    if($JsonPath){Write-AtomicText $JsonPath $json}
    $refresh=if ($Live) { '<meta http-equiv="refresh" content="5">' } else { '' }
    $logic=[IO.File]::ReadAllText((Join-Path $script:ProjectRoot 'web/Dashboard.logic.js'))
    $controls='';$client=''
    if($Extra -and $Extra.Controller){$controls=[IO.File]::ReadAllText((Join-Path $script:ProjectRoot 'web/App.controls.html'));$client=[IO.File]::ReadAllText((Join-Path $script:ProjectRoot 'web/App.controls.js'))}
    Write-AtomicText $Path ($template.Replace('@@REFRESH@@',$refresh).Replace('@@DATA@@',$json).Replace('@@SCRIPT@@',$logic).Replace('@@CONTROLS@@',$controls).Replace('@@APP_SCRIPT@@',$client))
}

. (Join-Path $PSScriptRoot 'PingLearning.ps1')
