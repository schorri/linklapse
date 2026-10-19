[CmdletBinding()]
param([int]$Days=7, [string]$From='', [string]$To='', [string]$DataDirectory='', [switch]$NoOpen, [switch]$ChoosePeriod, [ValidateSet('de','en')][string]$Language='', [string]$ResultFile='', [string]$ArchivePath='')
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Common.ps1')
try {
    if (-not $DataDirectory) { $DataDirectory=Join-Path $script:ProjectRoot 'data' }
    $c=Read-Settings;if($Language){$c.Language=$Language}
    . (Join-Path $PSScriptRoot 'ReportTopology.ps1')
    $periodMinutes=-1
    if ($ChoosePeriod) {$periodMinutes=Select-Duration ($Days*1440) $c.Language}
    $until=[datetime]::UtcNow
    if ($To) { $until=[datetimeoffset]::Parse($To).UtcDateTime }
    $since=$until.AddDays(-$Days)
    if ($periodMinutes -eq 0) {$since=[datetime]'2000-01-01T00:00:00Z'}
    elseif ($periodMinutes -gt 0) {$since=$until.AddMinutes(-$periodMinutes)}
    if ($From) { $since=[datetimeoffset]::Parse($From).UtcDateTime }
    if ($since -ge $until -or $Days -lt 1) { throw 'Ungültiger Zeitraum: Beginn muss vor Ende liegen; Days muss >=1 sein.' }
    $files=@(Get-ChildItem -LiteralPath $DataDirectory -Filter 'samples-????-??-??.csv' -File | Sort-Object Name)
    if (-not $files.Count) { throw 'Keine Mess-CSV vorhanden. Zuerst START.cmd starten.' }
    $out=Join-Path $script:ProjectRoot ('reports\'+[datetime]::Now.ToString('yyyy-MM-dd_HHmmss')+'_'+[guid]::NewGuid().ToString('N').Substring(0,6))
    [IO.Directory]::CreateDirectory($out) | Out-Null
    $a=New-Aggregate;$skipped=0;$inputs=New-Object 'System.Collections.Generic.List[object]'
    $eventFile=Join-Path $out 'Ereignisse.csv'
    $gapFile=Join-Path $out 'Messpausen.csv'
    $lastRow=$null;$sessionSettings=@{}
    Write-Host 'Bericht wird aus den CSV-Daten erstellt. Bei vielen Tagen kann dies einige Minuten dauern.' -ForegroundColor Cyan
    foreach ($file in $files) {
        $day=[datetime]::ParseExact($file.BaseName.Substring(8),'yyyy-MM-dd',$script:Inv)
        if ($day -gt $until.Date -or $day -lt $since.Date) { continue }
        $inputs.Add([pscustomobject]@{File=$file.Name;LengthAtRead=$file.Length;LastWriteUtc=$file.LastWriteTimeUtc.ToString('o')})
        Write-Host ('Lese '+$file.Name)
        Import-Csv -LiteralPath $file.FullName -Delimiter ';' -Encoding UTF8 | ForEach-Object {
            $r=$_
            # A snapshot can meet the writer between header and completed final row.
            if (-not $r.TimestampUtc -or -not $r.Observation -or $r.SchemaVersion -ne '1' -or -not $r.SessionId) { $skipped++;return }
            $t=[datetimeoffset]::Parse($r.TimestampUtc).UtcDateTime
            if ($t -lt $since -or $t -ge $until) { return }
            if ($lastRow) {
                $previous=[datetimeoffset]::Parse($lastRow.TimestampUtc).UtcDateTime
                $delta=($t-$previous).TotalSeconds
                if ($r.SessionId -ne $lastRow.SessionId -or $delta -le 0 -or $delta -gt [math]::Max(3*(Num $r.IntervalSeconds),3)) {
                    Add-CsvRow $gapFile ([pscustomobject][ordered]@{PreviousSampleUtc=$previous.ToString('o');NextSampleUtc=$t.ToString('o');SpanSeconds=Fmt $delta;PreviousSession=$lastRow.SessionId;NextSession=$r.SessionId;Meaning='Messlücke/Sitzungswechsel/Uhrsprung; keine belegte Netzstörung'})
                }
            }
            $before=$a.EventCount
            if (-not $sessionSettings.ContainsKey($r.SessionId)) {
                $sessionFile=Join-Path $DataDirectory ('session-'+$r.SessionId+'.json')
                $sessionSettings[$r.SessionId]=$null
                if (Test-Path -LiteralPath $sessionFile) {$sessionSettings[$r.SessionId]=(Get-Content -LiteralPath $sessionFile -Raw -Encoding UTF8 | ConvertFrom-Json).Settings}
            }
            Add-Sample $a $r $sessionSettings[$r.SessionId] $true
            foreach ($segment in $a.CompletedTimeline) {Add-CsvRow (Join-Path $out 'Zeitspuren.csv') $segment}
            # Write all events, retaining only the latest 200 for the HTML table.
            if ($a.EventCount -gt $before) {
                foreach ($event in @($a.Events | Select-Object -Last ($a.EventCount-$before))) { Add-CsvRow $eventFile $event }
            }
            if ($a.Events.Count -gt 200) { $a.Events.RemoveAt(0) }
            $lastRow=$r
        }
    }
    if ($a.Count -eq 0) { throw 'Im gewählten Zeitraum liegen keine vollständigen Messwerte.' }
    foreach ($track in $a.Timeline.Values) {if ($track.Open) {Add-CsvRow (Join-Path $out 'Zeitspuren.csv') ([pscustomobject]$track.Open)}}
    if ($null -ne $a.Open) { Close-Observation $a $null 'Datenende; Erholung nicht belegt';Add-CsvRow $eventFile $a.Events[$a.Events.Count-1] }
    if (-not (Test-Path -LiteralPath $eventFile)) { [IO.File]::WriteAllText($eventFile,'"SessionId";"StartUtc";"LastObservedUtc";"NextObservationUtc";"MinimumSpanSeconds";"Observation";"Samples";"SpeedActiveSamples";"EndReason"'+[Environment]::NewLine,(New-Object Text.UTF8Encoding($true))) }
    if (-not (Test-Path -LiteralPath $gapFile)) { [IO.File]::WriteAllText($gapFile,'"PreviousSampleUtc";"NextSampleUtc";"SpanSeconds";"PreviousSession";"NextSession";"Meaning"'+[Environment]::NewLine,(New-Object Text.UTF8Encoding($true))) }
    @(Get-TargetSummary $a) | Export-Csv -LiteralPath (Join-Path $out 'Zielstatistik.csv') -Delimiter ';' -NoTypeInformation -Encoding UTF8
    $webTests=New-Object 'System.Collections.Generic.List[object]';$webStats=@{};$speeds=New-Object 'System.Collections.Generic.List[object]';$speedCount=0;$webCount=0
    foreach ($kind in @('web','speed')) {
        foreach ($f in @(Get-ChildItem -LiteralPath $DataDirectory -Filter "$kind-????-??-??.csv" -File | Sort-Object Name)) {
            Import-Csv -LiteralPath $f.FullName -Delimiter ';' -Encoding UTF8 | ForEach-Object {
                $v=$_
                if (-not $v.StartedUtc -or -not $v.Status) { return }
                $t=[datetimeoffset]::Parse($v.StartedUtc).UtcDateTime
                if ($t -lt $since -or $t -ge $until) { return }
                Add-CsvRow (Join-Path $out "$kind.csv") $v
                if ($kind -eq 'web') {
                    $webCount++;$webTests.Add($v);if($webTests.Count -gt 100){$webTests.RemoveAt(0)}
                    if (-not $webStats.ContainsKey($v.Url)) { $webStats[$v.Url]=@{Url=$v.Url;Total=0;Ok=0} }
                    $s=$webStats[$v.Url];$s.Total++;if ($v.Status -eq 'Success') { $s.Ok++ }
                } else {
                    $speedCount++;$speeds.Add($v);if ($speeds.Count -gt 100) { $speeds.RemoveAt(0) }
                }
            }
        }
    }
    $extra=@{Web="$webCount HTTPS-Tests im gewählten Zeitraum; Details in web.csv, sofern vorhanden.";WebStats=@($webStats.Values)
        Speed="$speedCount abgeschlossene Download-Proben; vollständige Details in speed.csv, sofern vorhanden.";SpeedTests=$speeds.ToArray()}
    $extra.Settings=$c;$extra.WebTests=$webTests.ToArray();$extra.Topology=Read-ReportTopology $DataDirectory $out $a $since $until $c
    Write-View $a (Join-Path $out 'report.html') $false 'Störungsbericht · Internet-Stabilität' $false $extra
    $summary=New-Object Text.StringBuilder
    [void]$summary.AppendLine('STÖRUNGSBERICHT – LOKALE BEOBACHTUNGEN')
    [void]$summary.AppendLine('Erstellt: '+[datetimeoffset]::Now.ToString('o'))
    [void]$summary.AppendLine('Angefragter Zeitraum (UTC, Ende exklusiv): '+$since.ToString('o')+' bis '+$until.ToString('o'))
    [void]$summary.AppendLine('Tatsächliche Daten: '+$a.First.ToString('o')+' bis '+$a.Last.ToString('o'))
    [void]$summary.AppendLine("Messrunden: $($a.Count); Sitzungen: $($a.Sessions.Count); Beobachtungsabschnitte: $($a.EventCount)")
    [void]$summary.AppendLine("Messrunden mit abweichendem/unklarem Pfad (weiter ausgewertet): $($a.Excluded); Signal fehlt: $($a.SignalMissing); unter eigener Speedlast: $($a.LoadCount)")
    [void]$summary.AppendLine("Fortlaufende Messfolge: $(Fmt $a.ObservedSeconds) Sekunden. Lücken/Sitzungswechsel: $($a.Gaps), Spannen zusammen $(Fmt $a.GapSeconds) Sekunden.")
    [void]$summary.AppendLine("Unvollständige/inkompatible Zeilen ausgelassen: $skipped. Dies ist eine Momentaufnahme; Messung kann weiterlaufen.")
    [void]$summary.AppendLine('')
    [void]$summary.AppendLine('ZIELSTATISTIK – ROHDATEN UND GEWERTETE PING-PROBEN NACH LERNPHASE')
    foreach ($t in @(Get-TargetSummary $a)) { [void]$summary.AppendLine("$($t.Target): $($t.Lost)/$($t.Sent) ohne Erfolg ($(Fmt $t.LossPercent)%); Mittel $($t.AverageMs) ms, P95 $($t.P95Ms) ms, Maximum $($t.MaxMs) ms. Unter Speedlast: $($t.LoadedLost)/$($t.LoadedSent). Ping-Bewertung: $($t.Evaluation); nach Freigabe $($t.EvaluatedLost)/$($t.EvaluatedSent) ohne Antwort. Rohdatenfehlanteil ist kein Alarm.") }
    [void]$summary.AppendLine('')
    [void]$summary.AppendLine('Logs ab Version 1.4 behalten im Bericht ihren beim Messen gespeicherten Lernstatus; alte Logs werden innerhalb des ausgewählten Zeitraums neu gelernt. Ping-Lernregel: 8 Antworten in einem gleitenden Fenster von 10 gültigen Proben je Ziel/Sitzung/Route. Vor Freigabe kein Ping-Störungsalarm. Nach Freigabe bleibt ein Ziel auch bei anhaltenden Ausfällen alarmfähig. Ziel-, Pfad-, Sitzungswechsel und Messlücken starten neu. Am Messbeginn bestehende Störungen können dadurch nicht von blockiertem ICMP unterschieden werden; TCP/HTTPS und Rohdaten bleiben sichtbar.')
    [void]$summary.AppendLine('BEOBACHTUNGEN – PROBENZAHLEN, KEINE AUSFALLDAUERN')
    foreach ($k in @($a.States.Keys | Sort-Object)) { [void]$summary.AppendLine("${k}: $($a.States[$k])") }
    [void]$summary.AppendLine('')
    [void]$summary.AppendLine('Ein fehlender ICMP-Ping ist kein Beweis eines Internetausfalls. TCP/HTTPS-Ergebnisse und frühere Erreichbarkeit des Gateways gemeinsam prüfen. Nur bei passender WLAN-Route umfasst der Gateway-Pfad WLAN, Access Point und Teile des Gebäudenetzes. Bei abweichendem Pfad ist dieser Zusammenhang nicht belegt. Nur bei vergleichbarem Messpfad ist bei weiter antwortendem Gateway und mehreren ausfallenden externen Diensten ein Problem dahinter plausibel, die verantwortliche Stelle aber nicht bewiesen. Gateway ist nicht automatisch Access Point. Messlücken sind keine belegten Netzstörungen. Kein Anspruch auf eine amtliche Breitbandmessung.')
    [void]$summary.AppendLine('Einzelne auffällige Probe: mindestens 0 Sekunden beobachtete Spanne. Anfang, Ende und Erholung liegen zwischen Proben oder bleiben unbekannt. Ereignisse.csv enthält alle Beobachtungsabschnitte; Messpausen.csv die Lücken. Rohdaten und session-JSON aufbewahren. Diagramme skalieren von Einzelproben über Minuten und Stunden bis zu Tageswerten; Tabellenstatistik umfasst den gesamten gewählten Zeitraum.')
    Write-AtomicText (Join-Path $out 'Zusammenfassung.txt') $summary.ToString()
    $english=@"
LINKLAPSE 0.1.0 - LOCAL OBSERVATIONS
Requested UTC interval (end exclusive): $($since.ToString('o')) to $($until.ToString('o'))
Actual data: $($a.First.ToString('o')) to $($a.Last.ToString('o'))
Measurement rounds: $($a.Count); sessions: $($a.Sessions.Count); gaps: $($a.Gaps).
Open report.html and select English. The HTML contains the per-target raw/evaluated statistics, timelines and method. CSV field names are stable across UI languages.
Zeitspuren.csv contains all main-track segments; nodes.csv contains all extra-node probes in this interval. Topology.json contains the latest available path snapshot before the report end and replayed node states from this interval for the final session. Older sessions and path snapshots are included in Sitzungen. A snapshot is not a complete historical device inventory.
Missing ICMP replies alone do not prove an Internet outage or identify a responsible party. Device roles and physical topology are not reliably recoverable from traceroute. Observed segment spans are lower bounds between matching samples; a single sample has a zero-second span. Gaps are missing observations, not established network faults. Short download samples include connection setup and cannot establish full connection capacity.
Review IP addresses, adapter names, URLs and system metadata before sharing. This is a local snapshot, not cryptographically secured evidence or a certified broadband measurement.
"@
    Write-AtomicText (Join-Path $out 'ReportSummary.en.txt') $english
    $manifest=[ordered]@{Version='0.1.0';GeneratedUtc=[datetime]::UtcNow.ToString('o');RequestedFromUtc=$since.ToString('o');RequestedToUtc=$until.ToString('o');InputFiles=$inputs.ToArray();SkippedRows=$skipped;Sessions=@($a.Sessions.Keys);Snapshot=$true;Note='Rohdaten lokal aufbewahren; keine kryptografische Beweissicherung.'}
    Write-AtomicText (Join-Path $out 'Berichtsgrundlage.json') ($manifest | ConvertTo-Json -Depth 8)
    $sessionDir=Join-Path $out 'Sitzungen';[IO.Directory]::CreateDirectory($sessionDir) | Out-Null
    foreach ($id in $a.Sessions.Keys) { foreach($name in @("session-$id.json","topology-$id.json","topology-history-$id.jsonl")){ $file=Join-Path $DataDirectory $name;if(Test-Path -LiteralPath $file){Copy-Item -LiteralPath $file -Destination $sessionDir} } }
    Write-Host "Bericht fertig: $out" -ForegroundColor Green
    if (-not $NoOpen) { Start-Process (Join-Path $out 'report.html') }
    if($ArchivePath){Add-Type -AssemblyName System.IO.Compression.FileSystem;[IO.Compression.ZipFile]::CreateFromDirectory($out,$ArchivePath)}
    if($ResultFile){Write-AtomicText $ResultFile (@{Path=$out;Archive=$ArchivePath}|ConvertTo-Json -Compress)}
    Write-Output $out
} catch { Write-Host $_.Exception.Message -ForegroundColor Red;throw }
