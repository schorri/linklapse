# Eligibility is learned per session, literal target, route identity and measurement continuity.
# Never downgrade an established target merely because it stops answering.
function Update-PingLearning($a,$r) {
    if (-not $a.ContainsKey('PingLearning')) {$a.PingLearning=@{}}
    $now=[datetimeoffset]::Parse($r.TimestampUtc).UtcDateTime
    foreach ($prefix in @('Gateway','P1','P2','P3')) {
        $path=Get-ProbePath $r $prefix
        $routeError=[int]$r."${prefix}RouteError"
        $known=($path -ne 'Route unbekannt' -and $routeError -eq 0 -and [string]$r."${prefix}Address" -ne '')
        $identity=[string]$r.SessionId+'|'+[string]$r."${prefix}Address"+'|'+$path+'|'+[string]$r."${prefix}NextHop"
        $state=$a.PingLearning[$prefix]
        $gap=$false
        if ($state) {$elapsed=($now-$state.LastTime).TotalSeconds;$gap=($elapsed -le 0 -or $elapsed -gt [math]::Max(3*(Num $r.IntervalSeconds),3))}
        if (-not $state -or $state.Identity -ne $identity -or $gap) {
            $state=@{Prefix=$prefix;Identity=$identity;Path=$path;Address=[string]$r."${prefix}Address";Ready=$false;Window=(New-Object 'System.Collections.Generic.Queue[int]');LastTime=$now;Evaluation='Learning'}
            $a.PingLearning[$prefix]=$state
        }
        $state.LastTime=$now
        $status=[string]$r."${prefix}Status"
        $valid=($status -ne '' -and $status -notlike 'Error:*' -and $status -notin @('NoGateway','NotTested'))
        if ($known -and $valid) {
            $state.Window.Enqueue([int]($status -eq 'Success'))
            while ($state.Window.Count -gt 10) {$state.Window.Dequeue() | Out-Null}
            $replies=0;foreach($n in $state.Window){$replies+=$n}
            if (-not $state.Ready -and $state.Window.Count -ge 10 -and $replies -ge 8) {$state.Ready=$true}
        } else {$replies=0;foreach($n in $state.Window){$replies+=$n}}
        if (-not $known) {$evaluation='NoRoute'}
        elseif ($state.Ready) {$evaluation='Ready'}
        elseif ($state.Window.Count -ge 10) {$evaluation='Unavailable'}
        else {$evaluation='Learning'}
        $state.Evaluation=$evaluation
        $state.WindowReplies=$replies
        foreach ($field in ([ordered]@{
            PingEvaluation=$evaluation;PingAlarmEligible=[int]($known -and $state.Ready -and $valid)
            PingWindowSamples=$state.Window.Count;PingWindowReplies=$replies
        }).GetEnumerator()) {$r | Add-Member -MemberType NoteProperty -Name ($prefix+$field.Key) -Value $field.Value -Force}
    }
    $r | Add-Member -MemberType NoteProperty -Name PingRuleVersion -Value 1 -Force
}
function Test-PingEvaluated($r,[string]$Prefix) {return [int]$r."${Prefix}PingAlarmEligible" -eq 1}
function Get-InternetPingState($r,$Settings) {
    $threshold=150;if($Settings){$threshold=$Settings.HighInternetLatencyMs}
    $ok=0;$failed=0;$high=0;$max=-1.0;$eligible=0;$learning=0;$unavailable=0;$errors=0
    for($i=1;$i -le 3;$i++) {
        $prefix='P'+$i;$s=[string]$r."${prefix}Status"
        if($r."${prefix}PingEvaluation" -eq 'Learning'){$learning++}
        if($r."${prefix}PingEvaluation" -in @('Unavailable','NoRoute')){$unavailable++}
        if($s -like 'Error:*'){$errors++}
        if(-not (Test-PingEvaluated $r $prefix)){continue}
        $eligible++
        if($s -eq 'Success') {$ok++;$ms=Num $r."${prefix}Ms";$max=[math]::Max($max,$ms);if($ms -ge $threshold){$high++}}
        else {$failed++}
    }
    $ignored=3-$eligible
    if($failed -ge 2){$state='loss';$label="$failed von $eligible auswertbaren Ping-Zielen ohne Antwort"}
    elseif($failed -eq 1){$state='partial';$label="1 von $eligible auswertbaren Ping-Zielen ohne Antwort"}
    elseif($high -gt 0){$state='latency';$label="Erhöhte Latenz bei $high von $eligible auswertbaren Ping-Zielen"}
    elseif($eligible -gt 0){$state='ok';$label="$ok von $eligible auswertbaren Ping-Zielen antworten"}
    elseif($learning -gt 0){$state='learning';$label='Ping-Lernphase: Erreichbarkeit wird geprüft'}
    else {$state='unavailable';$label='Internet-Ping hier nicht auswertbar'}
    if($ignored -gt 0 -and $eligible -gt 0){$label+="; $ignored von 3 Zielen ohne Bewertung"}
    return [pscustomobject]@{State=$state;Label=$label;MaxMs=$max;Failed=$failed;Ok=$ok;Eligible=$eligible;Ignored=$ignored;Errors=$errors}
}
function Get-LearnedObservation($r,$c) {
    if($r.LinkState -and $r.LinkState -ne 'Up'){return 'Network interface disconnected'}
    if($r.WifiState -in @('Disconnected','Disconnecting','NotReady','Associating','Discovering','Authenticating')){return 'WLAN nicht verbunden'}
    $internet=Get-InternetPingState $r $c
    if($internet.State -in @('loss','partial','latency')){return $internet.Label}
    if((Test-PingEvaluated $r 'Gateway') -and $r.GatewayStatus -ne 'Success'){return 'Zuvor auswertbares Gateway ohne Ping-Antwort'}
    if((Test-PingEvaluated $r 'Gateway') -and (Num $r.GatewayMs) -ge $c.HighGatewayLatencyMs){return 'Hohe Gateway-Latenz'}
    if($internet.State -in @('learning','unavailable')){return $internet.Label}
    if((Num $r.SignalPercent) -ge 0 -and (Num $r.SignalPercent) -lt $c.WeakWifiPercent){return 'Niedriger WLAN-Signalwert'}
    if($internet.Ignored -gt 0){return $internet.Label}
    return 'Unauffällig'
}
