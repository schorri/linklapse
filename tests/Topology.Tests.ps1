$ErrorActionPreference='Stop'
$root=Join-Path (Split-Path $PSScriptRoot -Parent) 'src'
. (Join-Path $root 'Common.ps1')
. (Join-Path $root 'Topology.ps1')
. (Join-Path $root 'ReportTopology.ps1')
if(-not ('InternetMonitor.Native' -as [type])){Add-Type -Path @((Join-Path $root 'Monitor.Core.cs'),(Join-Path $root 'Topology.Core.cs'))}
$c=Read-Settings;$scratch=Join-Path $PSScriptRoot ('.work/nodes-'+[guid]::NewGuid().ToString('N'));[IO.Directory]::CreateDirectory($scratch)|Out-Null
$state=New-TopologyState;$path=[pscustomobject]@{InterfaceIndex=4;Adapter='Synthetic Wi-Fi'}
$start=[datetime]::UtcNow.AddMinutes(-10);$session=[guid]::NewGuid().ToString('N')
for($i=0;$i -lt 15;$i++){
    $p=[pscustomobject]@{Address='192.0.2.10';TimestampUtc=$start.AddSeconds($i*5).ToString('o');InterfaceIndex=4;Status=$(if($i -lt 10){'Success'}else{'TimedOut'});Ms=$(if($i -lt 10){2}else{-1})}
    Add-NodeObservation $state $p $path 'AccessPointManagement' 0 $scratch $session $c
}
$n=@((Get-TopologySnapshot $state $c).Nodes)[0]
if(-not $n.Ready -or $n.State -ne 'loss'){throw 'Learned AP management endpoint lost its alarm baseline'}
if($n.Segments[-1].Samples -ne 3){throw 'Repeated-failure span does not retain samples'}
$p.TimestampUtc=$start.AddSeconds(75).ToString('o');$p.InterfaceIndex=9
Add-NodeObservation $state $p $path 'AccessPointManagement' 0 $scratch $session $c
if(@((Get-TopologySnapshot $state $c).Nodes)[0].State -ne 'unknown'){throw 'Different path creates false AP failure'}
$p.TimestampUtc=$start.AddSeconds(200).ToString('o');$p.InterfaceIndex=4;$p.Status='Success';$p.Ms=2
Add-NodeObservation $state $p $path 'AccessPointManagement' 0 $scratch $session $c
if(@((Get-TopologySnapshot $state $c).Nodes)[0].State -ne 'learning'){throw 'Gap failed to reset node baseline'}
# Historical report must use its recorded state, not relearn or use a future path.
$a=@{LastRow=[pscustomobject]@{SessionId=$session};Last=$start.AddSeconds(70)}
$out=Join-Path $scratch ('report-'+$session);[IO.Directory]::CreateDirectory($out)|Out-Null
$future=Get-TopologySnapshot $state $c;$future.LastUpdatedUtc=$start.AddHours(2).ToString('o');$future.Paths=@([pscustomobject]@{Adapter='FUTURE MUST NOT APPEAR'})
Write-AtomicText (Join-Path $scratch ('topology-history-'+$session+'.jsonl')) ($future|ConvertTo-Json -Compress -Depth 16)
$report=Read-ReportTopology $scratch $out $a $start $start.AddSeconds(71) $c
if(@($report.Paths).Count){throw 'Future topology leaked into historical report'}
if(@($report.Nodes)[0].State -ne 'loss' -or -not @($report.Nodes)[0].Ready){throw 'Historical node failure was relearned away'}
Write-Host 'PASS: PS5.1 C# compilation; node learning; persistent failure; mismatched paths; gap reset; recorded-state replay; no future topology.'
