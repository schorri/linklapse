# Replay recorded states. Never relearn node eligibility when a report starts mid-incident.
function Read-ReportTopology($DataDirectory,$Out,$a,$since,$until,$c) {
    $session=[string]$a.LastRow.SessionId;$snapshot=$null
    $history=Join-Path $DataDirectory ('topology-history-'+$session+'.jsonl')
    if(Test-Path -LiteralPath $history){
        Get-Content -LiteralPath $history -Encoding UTF8 | ForEach-Object {
            try{$s=$_ | ConvertFrom-Json;if([datetimeoffset]::Parse($s.LastUpdatedUtc).UtcDateTime -le $until){$snapshot=$s}}catch{}
        }
    }
    if(-not $snapshot){$snapshot=[pscustomobject]@{Version=1;Paths=@();Nodes=@();Scanning=$false;DiscoveredUtc='';LastUpdatedUtc=$a.Last.ToString('o');AccessPointAddress=$c.Topology.AccessPointAddress;MaxHops=$c.Topology.MaxHops;ProbeEverySeconds=$c.Topology.ProbeEverySeconds}}
    $states=@{}
    foreach($file in @(Get-ChildItem -LiteralPath $DataDirectory -Filter 'nodes-????-??-??.csv' -File | Sort-Object Name)){
        Import-Csv -LiteralPath $file.FullName -Delimiter ';' -Encoding UTF8 | ForEach-Object {
            $r=$_
            if(-not $r.TimestampUtc -or -not $r.Evaluation){return}
            $t=[datetimeoffset]::Parse($r.TimestampUtc).UtcDateTime
            if($t -lt $since -or $t -ge $until){return}
            Add-CsvRow (Join-Path $Out 'nodes.csv') $r
            if($r.SessionId -ne $session){return}
            $key=$r.InterfaceIndex+'|'+$r.Address+'|'+$r.Role
            if(-not $states.ContainsKey($key)){$states[$key]=@{Segments=(New-Object 'System.Collections.Generic.List[object]');Open=$null;Last=$null}}
            $v=$states[$key];$gap=$false
            if($v.Last){$gap=($t-[datetimeoffset]::Parse($v.Last.TimestampUtc).UtcDateTime).TotalSeconds -gt 3*$snapshot.ProbeEverySeconds}
            if($v.Open -and ($gap -or $v.Open.State -ne $r.Evaluation)){$v.Segments.Add([pscustomobject]$v.Open);$v.Open=$null}
            if(-not $v.Open){$v.Open=@{State=$r.Evaluation;StartUtc=$r.TimestampUtc;LastObservedUtc=$r.TimestampUtc;Samples=0;FailedProbes=0;SuccessfulProbes=0}}
            $v.Open.LastObservedUtc=$r.TimestampUtc;$v.Open.Samples++
            if($r.Status -eq 'Success'){$v.Open.SuccessfulProbes++}else{$v.Open.FailedProbes++}
            if($v.Segments.Count -gt 200){$v.Segments.RemoveAt(0)}
            $v.Last=$r
        }
    }
    $snapshot.Nodes=@(foreach($v in $states.Values){$r=$v.Last;[pscustomobject]@{Address=$r.Address;Role=$r.Role;InterfaceIndex=[int]$r.InterfaceIndex;Adapter=$r.Adapter;Ttl=[int]$r.Ttl;Ready=([int]$r.PingReady -eq 1);State=$r.Evaluation;Ms=(Num $r.Ms);LastUtc=$r.TimestampUtc;StateStartedUtc=$r.StateStartedUtc;RawProbes=[long]$r.RawProbes;RawLost=[long]$r.RawLost;Segments=@($v.Segments.ToArray())+@($(if($v.Open){[pscustomobject]$v.Open}))}})
    Write-AtomicText (Join-Path $Out 'Topology.json') ($snapshot | ConvertTo-Json -Depth 16)
    return $snapshot
}
