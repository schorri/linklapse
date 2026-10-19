[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$SettingsFile,[double]$DurationMinutes=60,[switch]$PauseUpdates,[int]$OwnerPid=0,[int]$MaxSamples=0)
$ErrorActionPreference='Stop'
$project=Split-Path $PSScriptRoot -Parent
$stopFile=Join-Path $project 'data/STOP'
try{
    if($PauseUpdates){
        $exe=Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/powershell.exe'
        $helper=Join-Path $PSScriptRoot 'UpdateRichtlinie.ps1'
        $arguments='-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "'+$helper+'" -Mode Apply -OwnerPid '+$PID
        $admin=Start-Process -FilePath $exe -Verb RunAs -WindowStyle Hidden -ArgumentList $arguments -Wait -PassThru
        if($admin.ExitCode -ne 0){throw ('Update policy setup failed (code '+$admin.ExitCode+'). Check Windows edition, pending restart and permissions. No measurement was started.')}
    }
    if(Test-Path -LiteralPath $stopFile){exit 0}
    & (Join-Path $PSScriptRoot 'Monitor.ps1') -NoOpen -DurationMinutes $DurationMinutes -SettingsFile $SettingsFile -OwnerPid $OwnerPid -PreserveStop -MaxSamples $MaxSamples
    if($LASTEXITCODE){exit $LASTEXITCODE}
}catch{[Console]::Error.WriteLine($_.Exception.Message);exit 1}
