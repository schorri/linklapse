function Get-NetworkAdapters {
    $all=@()
    foreach($n in [Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces()) {
        try {
            if($n.NetworkInterfaceType -eq 'Loopback'){continue}
            $index=$n.GetIPProperties().GetIPv4Properties().Index
            if($index -le 0 -or @($all | Where-Object Index -eq $index).Count){continue}
            $all+=[pscustomobject]@{Index=$index;Name=$n.Name;Description=$n.Description;Type=[string]$n.NetworkInterfaceType;Status=[string]$n.OperationalStatus;Id=$n.Id;Native=$n}
        } catch {}
    }
    return $all
}
function Select-NetworkAdapter($c,$Previous=$null) {
    $adapters=@(Get-NetworkAdapters)
    if($c.InterfaceName) {
        $matches=@($adapters | Where-Object Name -eq $c.InterfaceName)
        if($matches.Count -ne 1){throw 'InterfaceName does not identify exactly one IPv4 adapter.'}
        return $matches[0]
    }
    $route=[InternetMonitor.Native]::Route([string]$c.InternetTargets[1])
    $match=@($adapters | Where-Object Index -eq $route.InterfaceIndex)
    if($route.Error -eq 0 -and $match.Count){return $match[0]}
    if($Previous){$match=@($adapters | Where-Object Index -eq $Previous.Index);if($match.Count){return $match[0]}}
    $active=@($adapters | Where-Object Status -eq 'Up')
    if($active.Count){return $active[0]}
    if($adapters.Count){return $adapters[0]}
    throw 'No usable IPv4 adapter found.'
}
function New-TopologyState {
    return @{Signature='';Paths=@();TraceTask=$null;ProbeTask=$null;ProbeContext='';NodeStates=@{};LastDiscoveryUtc='';NextDiscovery=[datetime]::MinValue;NextProbe=[datetime]::MinValue;Scanning=$false}
}
function Save-TopologyHistory($state,$c,$data,$session) {
    $snapshot=Get-TopologySnapshot $state $c
    Add-Content -LiteralPath (Join-Path $data ('topology-history-'+$session+'.jsonl')) -Value ($snapshot | ConvertTo-Json -Depth 16 -Compress) -Encoding UTF8
}
function Add-NodeObservation($state,$probe,$path,$role,$ttl,$data,$session,$c) {
    $key=[string]$path.InterfaceIndex+'|'+$probe.Address+'|'+$role
    if(-not $state.NodeStates.ContainsKey($key)) {
        $state.NodeStates[$key]=@{Address=$probe.Address;Role=$role;InterfaceIndex=$path.InterfaceIndex;Adapter=$path.Adapter;Ttl=$ttl;Window=(New-Object 'System.Collections.Generic.Queue[int]');Ready=$false;Failures=0;Count=0;Lost=0;State='learning';Ms=-1;LastUtc='';StartedUtc=$probe.TimestampUtc;StateStartedUtc=$probe.TimestampUtc;Segments=(New-Object 'System.Collections.Generic.List[object]');Open=$null}
    }
    $s=$state.NodeStates[$key];$old=$s.State
    if($s.ContainsKey('ProbeNextHop') -and $s.ProbeNextHop -ne [string]$probe.NextHop){$s.Ready=$false;$s.Window.Clear();$s.Failures=0;$s.StateStartedUtc=$probe.TimestampUtc}
    $s.ProbeNextHop=[string]$probe.NextHop
    if($s.LastUtc){
        $gap=([datetimeoffset]::Parse($probe.TimestampUtc)-[datetimeoffset]::Parse($s.LastUtc)).TotalSeconds
        if($gap -le 0 -or $gap -gt 3*$c.Topology.ProbeEverySeconds){
            $s.Ready=$false;$s.Window.Clear();$s.Failures=0;$s.StateStartedUtc=$probe.TimestampUtc
            if($s.Open){$s.Segments.Add([pscustomobject]$s.Open);$s.Open=$null}
        }
    }
    $s.LastUtc=$probe.TimestampUtc;$s.Ms=$probe.Ms;$s.Count++
    if($probe.Status -ne 'Success'){$s.Lost++}
    if($probe.InterfaceIndex -ne $path.InterfaceIndex -or $probe.Status -eq 'RouteChanged') {$s.State='unknown';$s.Ready=$false;$s.Window.Clear();$s.Failures=0}
    elseif($probe.Status -like 'Error:*'){$s.State='unknown'}
    else {
        $ok=$probe.Status -eq 'Success';$s.Window.Enqueue([int]$ok);while($s.Window.Count -gt 10){$s.Window.Dequeue() | Out-Null}
        $replies=0;foreach($v in $s.Window){$replies+=$v}
        if($s.Window.Count -ge 10 -and $replies -ge 8){$s.Ready=$true}
        if($ok){$s.Failures=0}else{$s.Failures++}
        if(-not $s.Ready){$s.State=if($s.Window.Count -ge 10){'unavailable'}else{'learning'}}
        elseif(-not $ok){$s.State=if($s.Failures -ge 3){'loss'}else{'partial'}}
        elseif($probe.Ms -ge $c.Topology.HighHopLatencyMs){$s.State='latency'}
        else{$s.State='ok'}
    }
    if($s.State -ne $old){$s.StateStartedUtc=$probe.TimestampUtc}
    if($s.Open -and $s.Open.State -ne $s.State){$s.Segments.Add([pscustomobject]$s.Open);$s.Open=$null}
    if(-not $s.Open){$s.Open=@{State=$s.State;StartUtc=$probe.TimestampUtc;LastObservedUtc=$probe.TimestampUtc;Samples=0;FailedProbes=0;SuccessfulProbes=0}}
    $s.Open.LastObservedUtc=$probe.TimestampUtc;$s.Open.Samples++
    if($probe.Status -eq 'Success'){$s.Open.SuccessfulProbes++}else{$s.Open.FailedProbes++}
    while($s.Segments.Count -gt 200){$s.Segments.RemoveAt(0)}
    Add-CsvRow (Join-Path $data ('nodes-'+([datetimeoffset]::Parse($probe.TimestampUtc).UtcDateTime.ToString('yyyy-MM-dd'))+'.csv')) ([pscustomobject][ordered]@{
        SessionId=$session;TimestampUtc=$probe.TimestampUtc;Address=$probe.Address;Role=$role;InterfaceIndex=$path.InterfaceIndex;ProbeRouteIfIndex=$probe.InterfaceIndex;ProbeNextHop=[string]$probe.NextHop;Adapter=$path.Adapter
        Status=$probe.Status;Ms=Fmt $probe.Ms;Evaluation=$s.State;PingReady=[int]$s.Ready;RawProbes=$s.Count;RawLost=$s.Lost;StateStartedUtc=$s.StateStartedUtc;Ttl=$ttl
    })
}
function Update-Topology($state,$c,$data,$session,$adapters,[switch]$Finish) {
    $now=[datetime]::UtcNow
    $paths=@();$routeKeys=@{}
    foreach($ip in $c.InternetTargets) {
        $route=[InternetMonitor.Native]::Route($ip)
        $adapter=@($adapters | Where-Object Index -eq $route.InterfaceIndex | Select-Object -First 1)
        $key=[string]$route.InterfaceIndex+'|'+$route.NextHop+'|'+$route.Error
        if($routeKeys.ContainsKey($key)){$routeKeys[$key].Targets+=@($ip);continue}
        $path=[pscustomobject]@{Key=$key;InterfaceIndex=$route.InterfaceIndex;Adapter=$(if($adapter.Count){$adapter[0].Name}else{''});Type=$(if($adapter.Count){$adapter[0].Type}else{'Unknown'});Description=$(if($adapter.Count){$adapter[0].Description}else{''});NextHop=$route.NextHop;RouteError=$route.Error;Targets=@($ip);Hops=@();RouteStable=$false}
        $routeKeys[$key]=$path;$paths+=@($path)
    }
    $signature=(@($paths | ForEach-Object Key) -join ';')+'|'+$c.Topology.AccessPointAddress
    if($state.Signature -ne $signature) {
        $state.Signature=$signature;$state.Paths=$paths;$state.NodeStates=@{};$state.LastDiscoveryUtc='';$state.NextDiscovery=[datetime]::MinValue;$state.NextProbe=[datetime]::MinValue
        Save-TopologyHistory $state $c $data $session
    }
    if($state.TraceTask -and $state.TraceTask.IsCompleted) {
        if(-not $state.TraceTask.IsFaulted -and $state.TraceContext -eq $state.Signature) {
            foreach($trace in $state.TraceTask.Result) {
                $matching=@($state.Paths | Where-Object {$_.Targets -contains $trace.Target -and $_.InterfaceIndex -eq $trace.InterfaceIndex -and $_.NextHop -eq $trace.NextHop})
                if($matching.Count -and $trace.RouteStable){$matching[0].Hops=@($trace.Hops);$matching[0].RouteStable=$true}
            }
            $state.LastDiscoveryUtc=$now.ToString('o')
            Save-TopologyHistory $state $c $data $session
            Write-AtomicText (Join-Path $data ('topology-'+$session+'.json')) (Get-TopologySnapshot $state $c | ConvertTo-Json -Depth 12)
        }
        $state.TraceTask=$null;$state.Scanning=$false
    }
    if($state.ProbeTask -and $state.ProbeTask.IsCompleted) {
        if(-not $state.ProbeTask.IsFaulted -and $state.ProbeContext -eq $state.Signature) {
            foreach($probe in $state.ProbeTask.Result) {
                foreach($path in $state.Paths) {
                    if($path.RouteError -ne 0){continue}
                    if($path.Type -eq 'Wireless80211' -and $c.Topology.AccessPointAddress -and $probe.Address -eq $c.Topology.AccessPointAddress){Add-NodeObservation $state $probe $path 'AccessPointManagement' 0 $data $session $c}
                    if($probe.Address -eq $path.NextHop -and $path.NextHop -ne '0.0.0.0'){Add-NodeObservation $state $probe $path 'Gateway' 1 $data $session $c}
                    foreach($hop in @($path.Hops | Where-Object {$_.Status -eq 'TtlExpired' -and $_.Address -ne $path.NextHop} | Select-Object -First $c.Topology.MaxMonitoredHops | Where-Object Address -eq $probe.Address)) {
                        Add-NodeObservation $state $probe $path 'RouterHop' $hop.Ttl $data $session $c
                    }
                }
            }
        }
        $state.ProbeTask=$null
    }
    if($c.Topology.Enabled -and -not $Finish -and -not $state.TraceTask -and $now -ge $state.NextDiscovery) {
        $targets=@($state.Paths | Where-Object RouteError -eq 0 | ForEach-Object {$_.Targets[0]})
        if($targets.Count){$state.TraceTask=[InternetMonitor.TopologyProbes]::Discover([string[]]$targets,[int]$c.Topology.MaxHops,[int]$c.Topology.TimeoutMs);$state.TraceContext=$signature;$state.Scanning=$true}
        $state.NextDiscovery=$now.AddMinutes($c.Topology.DiscoverEveryMinutes)
    }
    if($c.Topology.Enabled -and -not $Finish -and -not $state.ProbeTask -and $now -ge $state.NextProbe) {
        $ips=@()
        foreach($path in $state.Paths) {
            if($path.RouteError -ne 0){continue}
            if($path.NextHop -and $path.NextHop -ne '0.0.0.0'){$ips+=@($path.NextHop)}
            $ips+=@($path.Hops | Where-Object {$_.Status -eq 'TtlExpired' -and $_.Address -and $_.Address -ne $path.NextHop} | Select-Object -First $c.Topology.MaxMonitoredHops | ForEach-Object Address)
        }
        if($c.Topology.AccessPointAddress){$ips+=@($c.Topology.AccessPointAddress)}
        $ips=@($ips | Select-Object -Unique)
        if($ips.Count){$state.ProbeTask=[InternetMonitor.TopologyProbes]::Probe([string[]]$ips,[int]$c.PingTimeoutMs);$state.ProbeContext=$signature}
        $state.NextProbe=$now.AddSeconds($c.Topology.ProbeEverySeconds)
    }
}
function Get-TopologySnapshot($state,$c) {
    $nodes=@(foreach($s in $state.NodeStates.Values){[pscustomobject]@{Address=$s.Address;Role=$s.Role;InterfaceIndex=$s.InterfaceIndex;Adapter=$s.Adapter;Ttl=$s.Ttl;Ready=$s.Ready;State=$s.State;Ms=$s.Ms;LastUtc=$s.LastUtc;StateStartedUtc=$s.StateStartedUtc;RawProbes=$s.Count;RawLost=$s.Lost;Segments=@($s.Segments.ToArray())+@($(if($s.Open){[pscustomobject]$s.Open}))}})
    return [pscustomobject]@{Version=1;Scanning=$state.Scanning;DiscoveredUtc=$state.LastDiscoveryUtc;Paths=@($state.Paths);Nodes=$nodes;AccessPointAddress=$c.Topology.AccessPointAddress;MaxHops=$c.Topology.MaxHops;ProbeEverySeconds=$c.Topology.ProbeEverySeconds;LastUpdatedUtc=[datetime]::UtcNow.ToString('o')}
}
