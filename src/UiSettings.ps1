function Get-UiAdapters {
    @([Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces() | Where-Object {$_.NetworkInterfaceType -ne 'Loopback'} | ForEach-Object {
        try{$index=$_.GetIPProperties().GetIPv4Properties().Index;if($index -gt 0){[pscustomobject]@{Name=$_.Name;Type=[string]$_.NetworkInterfaceType;Status=[string]$_.OperationalStatus}}}catch{}
    } | Sort-Object Name -Unique)
}
function Resolve-UiSettings($value,$config,$adapters) {
    $required=@('DurationMinutes','Language','SpeedEnabled','SpeedEveryMinutes','SpeedMaxMiB','SpeedMaxMbps','ExpectedMbps','InterfaceName','AccessPointAddress','PauseUpdates')
    $actual=@($value.PSObject.Properties.Name)
    if($actual.Count -ne $required.Count -or @($actual | Where-Object {$_ -notin $required}).Count){throw 'Invalid settings fields.'}
    foreach($field in @('DurationMinutes','SpeedEveryMinutes','SpeedMaxMiB','SpeedMaxMbps','ExpectedMbps')){
        $n=$value.$field
        if($n -isnot [int] -and $n -isnot [long] -and $n -isnot [double] -and $n -isnot [decimal]){throw ('A number is required: '+$field)}
        if([double]::IsNaN([double]$n) -or [double]::IsInfinity([double]$n)){throw 'Finite numbers only.'}
    }
    if($value.DurationMinutes -notin @(0,5,60,1440,4320,10080,20160,43200)){throw 'Unsupported duration.'}
    if($value.Language -isnot [string] -or $value.Language -notin @('de','en')){throw 'Language must be de or en.'}
    if($value.SpeedEnabled -isnot [bool] -or $value.PauseUpdates -isnot [bool]){throw 'Boolean options required.'}
    if($value.SpeedEveryMinutes -notin @(15,30,60,180) -or $value.SpeedMaxMiB -notin @(1,5,10,25,50)){throw 'Unsupported download limits.'}
    if($value.SpeedMaxMbps -lt 0 -or $value.SpeedMaxMbps -gt 10000 -or $value.ExpectedMbps -lt 0 -or $value.ExpectedMbps -gt 100000){throw 'Download reference/cap out of range.'}
    if($value.InterfaceName -isnot [string] -or ($value.InterfaceName -and $value.InterfaceName -notin @($adapters | ForEach-Object Name))){throw 'Select an existing adapter.'}
    if($value.AccessPointAddress -isnot [string]){throw 'AP management address must be text.'}
    if($value.AccessPointAddress){
        if($value.AccessPointAddress -notmatch '^\d{1,3}(\.\d{1,3}){3}$' -or ([Net.IPAddress]::Parse($value.AccessPointAddress)).AddressFamily -ne 'InterNetwork'){throw 'Enter a confirmed IPv4 AP management address or leave it empty.'}
    }
    $result=$config | ConvertTo-Json -Depth 12 | ConvertFrom-Json
    $result.DurationMinutes=$value.DurationMinutes;$result.Language=$value.Language;$result.InterfaceName=$value.InterfaceName
    $result.Speed.Enabled=$value.SpeedEnabled;$result.Speed.EveryMinutes=$value.SpeedEveryMinutes;$result.Speed.MaxMiB=$value.SpeedMaxMiB
    $result.Speed.MaxMbps=$value.SpeedMaxMbps;$result.Speed.ExpectedMbps=$value.ExpectedMbps;$result.Topology.AccessPointAddress=$value.AccessPointAddress
    return $result
}
function Get-UiPreferences($c){
    [pscustomobject]@{DurationMinutes=$c.DurationMinutes;Language=$c.Language;SpeedEnabled=[bool]$c.Speed.Enabled;SpeedEveryMinutes=$c.Speed.EveryMinutes;SpeedMaxMiB=$c.Speed.MaxMiB;SpeedMaxMbps=$c.Speed.MaxMbps;ExpectedMbps=$c.Speed.ExpectedMbps;InterfaceName=$c.InterfaceName;AccessPointAddress=$c.Topology.AccessPointAddress;PauseUpdates=$false}
}
