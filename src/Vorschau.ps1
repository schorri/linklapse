param([switch]$NoOpen)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Common.ps1')
. (Join-Path $PSScriptRoot 'UiSettings.ps1')
$a=New-Aggregate;$c=Read-Settings;$c.Speed.Enabled=$true;$start=[datetime]::UtcNow.AddMinutes(-12)
for ($i=0;$i -lt 600;$i++) {
    $t=$start.AddSeconds($i + $(if ($i -ge 300) {120} else {0}))
    $s=if ($i -ge 420 -and $i -lt 445) {28} else {76+[int](8*[math]::Sin($i/35))}
    $r=[pscustomobject][ordered]@{
        SchemaVersion=1;TimestampUtc=$t.ToString('o');TimestampLocal=$t.ToLocalTime().ToString('o');SessionId='DEMO_SYNTHETISCH';Sequence=($i+1);IntervalSeconds='1'
        InterfaceName='Wi-Fi (DEMO)';InterfaceIndex=1;NetworkType='Wireless80211';LinkState='Up';WifiState='Connected';WifiError=0;SignalPercent=$s;LinkRxMbps='300';LinkTxMbps='300'
        PathScope='SelectedWifi';GatewayAddress='192.0.2.1';GatewayStatus='Success';GatewayMs='3'
        P1Address='1.1.1.1';P1Status='Success';P1Ms=(Fmt (18+5*[math]::Abs([math]::Sin($i/8))))
        P2Address='8.8.8.8';P2Status='Success';P2Ms=(Fmt (22+7*[math]::Abs([math]::Cos($i/9))))
        P3Address='9.9.9.9';P3Status='Success';P3Ms='25'
        Tcp1Address='1.1.1.1';Tcp1Status='NotTested';Tcp1Ms='-1';Tcp2Address='8.8.8.8';Tcp2Status='NotTested';Tcp2Ms='-1'
        SpeedActive=0;Observation=''
    }
    if ($i%5 -eq 0) { $r.Tcp1Status='Success';$r.Tcp1Ms='20';$r.Tcp2Status='Success';$r.Tcp2Ms='25' }
    if ($i -ge 130 -and $i -le 155) { $r.P1Ms='230';$r.P2Ms='270';$r.P3Ms='210';$r.SpeedActive=1 }
    if ($i -ge 210 -and $i -le 216) {
        $r.P1Status='TimedOut';$r.P1Ms='-1';$r.P2Status='TimedOut';$r.P2Ms='-1';$r.P3Status='TimedOut';$r.P3Ms='-1'
        if ($i%5 -eq 0) {$r.Tcp1Status='TimedOut';$r.Tcp2Status='TimedOut'}
    }
    if ($i -ge 430 -and $i -le 435) { $r.WifiState='Disconnected';$r.SignalPercent=-1;$r.GatewayStatus='TimedOut';$r.GatewayMs='-1' }
    foreach($prefix in @('Gateway','P1','P2','P3','Tcp1','Tcp2')){$r | Add-Member -NotePropertyName ($prefix+'RouteIfIndex') -NotePropertyValue 1 -Force}
    Add-Sample $a $r $c
}
Close-Observation $a $null 'Ende der synthetischen Daten'
$dest=Join-Path $script:ProjectRoot 'docs/assets'
[IO.Directory]::CreateDirectory($dest) | Out-Null
$demoSpeeds=@(
    [pscustomobject]@{StartedUtc=$start.AddSeconds(60).ToString('o');Status='DEMO / Success';Mbps='48.6';Bytes='5242880';RateCapped='False'},
    [pscustomobject]@{StartedUtc=$start.AddSeconds(130).ToString('o');Status='DEMO / Success';Mbps='14.8';Bytes='5242880';RateCapped='False'},
    [pscustomobject]@{StartedUtc=$start.AddSeconds(540).ToString('o');Status='DEMO / Success';Mbps='51.2';Bytes='5242880';RateCapped='False'}
)
$topology=[pscustomobject]@{Version=1;Scanning=$false;DiscoveredUtc=$start.ToString('o');AccessPointAddress='';MaxHops=12;ProbeEverySeconds=5;Nodes=@();Paths=@([pscustomobject]@{InterfaceIndex=1;Adapter='Wi-Fi (DEMO)';Type='Wireless80211';Description='Synthetic Wi-Fi adapter';NextHop='192.0.2.1';RouteError=0;Targets=@('1.1.1.1','8.8.8.8','9.9.9.9');RouteStable=$true;Hops=@([pscustomobject]@{Ttl=1;Address='192.0.2.1';Status='TtlExpired'},[pscustomobject]@{Ttl=2;Address='198.51.100.1';Status='TtlExpired'},[pscustomobject]@{Ttl=3;Address='';Status='TimedOut'})})}
$preferences=Get-UiPreferences $c;$preferences.SpeedEnabled=$false
Write-View $a (Join-Path $dest 'demo.html') $false 'DEMO · Internet-Stabilität' $true @{Web='DEMO: HTTPS-Tests erfolgreich';Speed='DEMO: drei illustrative Download-Proben (abweichend vom stündlichen Standardabstand)';SpeedTests=$demoSpeeds;Settings=$c;Topology=$topology;Controller=$true;Token='demo';Preferences=$preferences}
if (-not $NoOpen) { Start-Process (Join-Path $dest 'demo.html') }
Write-Host ('Synthetische Vorschau: '+(Join-Path $dest 'demo.html'))
