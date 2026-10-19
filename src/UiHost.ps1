[CmdletBinding()]
param([switch]$NoOpen,[int]$LauncherPid=0,[int]$TestMaxSamples=0,[int]$ExitAfterSeconds=0)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Common.ps1')
. (Join-Path $PSScriptRoot 'UiSettings.ps1')
$data=Join-Path $script:ProjectRoot 'data';[IO.Directory]::CreateDirectory($data)|Out-Null
$instanceFile=Join-Path $data 'ui-instance.json';$stopFile=Join-Path $data 'STOP'
$lock=$null;$hostBridge=$null;$children=$null;$worker=$null;$reportProcess=$null
$phase='idle';$errorText='';$runId='';$runStarted=$null;$stopRequested=$false;$closing=$false;$closingAt=$null
$report=[pscustomobject]@{Status='idle';ViewUrl='';DownloadUrl='';Error=''}
$reportPath='';$reportZip='';$reportId='';$lastJson='';$lastWrite=0L;$measurement=$null
$hostStarted=[datetime]::UtcNow;$workerStdout='';$workerStderr=''
function Get-LatestMeasurement {
    $file=Join-Path $data 'live.json'
    if(Test-Path -LiteralPath $file){
        $ticks=(Get-Item -LiteralPath $file).LastWriteTimeUtc.Ticks
        if($ticks -ne $script:lastWrite){
            try{$json=[IO.File]::ReadAllText($file);$model=$json|ConvertFrom-Json;$script:lastWrite=$ticks;$script:lastJson=$json;$script:measurement=$model}catch{}
        }
    }
    if($script:runStarted -and $script:measurement -and [datetimeoffset]::Parse($script:measurement.generated).UtcDateTime -lt $script:runStarted){return 'null'}
    if($script:lastJson){return $script:lastJson}
    return 'null'
}
function Start-HiddenPowerShell([string]$arguments,[string]$output,[string]$errors){
    $exe=Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/powershell.exe'
    $p=Start-Process -FilePath $exe -ArgumentList $arguments -WorkingDirectory $script:ProjectRoot -WindowStyle Hidden -RedirectStandardOutput $output -RedirectStandardError $errors -PassThru
    try{$children.Track($p)}catch{try{$p.Kill()}catch{};throw}
    return $p
}
function Read-Failure([string]$errorFile,[string]$outFile){
    $text=''
    if(Test-Path -LiteralPath $errorFile){$text=([IO.File]::ReadAllText($errorFile)).Trim()}
    if(-not $text -and (Test-Path -LiteralPath $outFile)){$text=@(Get-Content -LiteralPath $outFile -Tail 12) -join [Environment]::NewLine}
    if($text.Length -gt 2000){$text=$text.Substring($text.Length-2000)}
    return $text
}
try{
    try{$lock=New-Object IO.FileStream((Join-Path $data 'ui.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)}
    catch{
        for($i=0;$i -lt 20;$i++){
            try{$instance=Get-Content -LiteralPath $instanceFile -Raw -Encoding UTF8|ConvertFrom-Json;$owner=Get-Process -Id $instance.ProcessId -ErrorAction Stop
                if($owner.StartTime.ToUniversalTime().Ticks -eq [long]$instance.StartTicks -and $instance.Url -match '^http://127\.0\.0\.1:\d+$'){if(-not $NoOpen){Start-Process $instance.Url};exit 0}
            }catch{}
            Start-Sleep -Milliseconds 100
        }
        throw 'LinkLapse is already opening in this folder. Try again shortly.'
    }
    $config=Read-Settings;$preferences=Get-UiPreferences $config
    $prefFile=Join-Path $data 'ui-preferences.json'
    if(Test-Path -LiteralPath $prefFile){try{$saved=Get-Content -LiteralPath $prefFile -Raw -Encoding UTF8|ConvertFrom-Json;$null=Resolve-UiSettings $saved $config @(Get-UiAdapters);$preferences=$saved;$preferences.PauseUpdates=$false}catch{}}
    $preferredPort=0
    if(Test-Path -LiteralPath $instanceFile){try{$old=Get-Content -LiteralPath $instanceFile -Raw -Encoding UTF8|ConvertFrom-Json;if($old.Url -match '^http://127\.0\.0\.1:(\d+)$'){$preferredPort=[int]$Matches[1]}}catch{}}
    Add-Type -Path (Join-Path $PSScriptRoot 'LocalHost.cs')
    $hostBridge=New-Object LinkLapse.LocalHost($preferredPort);$children=New-Object LinkLapse.ChildProcesses
    $config.Language=$preferences.Language
    Write-View (New-Aggregate) (Join-Path $data 'app.html') $false 'LinkLapse' $false @{Settings=$config;Controller=$true;Token=$hostBridge.Token;Preferences=$preferences}
    Write-AtomicText $instanceFile ([pscustomobject]@{ProcessId=$PID;StartTicks=(Get-Process -Id $PID).StartTime.ToUniversalTime().Ticks;Url=$hostBridge.Url}|ConvertTo-Json)
    if(-not $NoOpen){Start-Process $hostBridge.Url}
    while($true){
        if($LauncherPid -gt 0 -and -not $closing){try{$null=Get-Process -Id $LauncherPid -ErrorAction Stop}catch{$closing=$true;$closingAt=[datetime]::UtcNow;Write-AtomicText $stopFile 'stop'}}
        if($ExitAfterSeconds -gt 0 -and ([datetime]::UtcNow-$hostStarted).TotalSeconds -gt $ExitAfterSeconds){$closing=$true;if(-not $closingAt){$closingAt=[datetime]::UtcNow};Write-AtomicText $stopFile 'stop'}
        if($worker){
            $worker.Refresh()
            if($worker.HasExited){
                $phase=if($worker.ExitCode -eq 0){'finished'}else{'error'}
                if($phase -eq 'error'){$errorText=Read-Failure $workerStderr $workerStdout}
                $worker.Dispose();$worker=$null
            }elseif($stopRequested -or $closing){$phase='stopping'}
            elseif($phase -eq 'starting'){$null=Get-LatestMeasurement;if($measurement -and $measurement.live -and [datetimeoffset]::Parse($measurement.generated).UtcDateTime -ge $runStarted){$phase='running'}}
        }
        if($reportProcess){
            $reportProcess.Refresh()
            if($reportProcess.HasExited){
                if($reportProcess.ExitCode -eq 0){
                    try{
                        $result=Get-Content -LiteralPath $reportResult -Raw -Encoding UTF8|ConvertFrom-Json
                        $resolved=[IO.Path]::GetFullPath($result.Path);$reportsRoot=[IO.Path]::GetFullPath((Join-Path $script:ProjectRoot 'reports'))+[IO.Path]::DirectorySeparatorChar
                        if(-not $resolved.StartsWith($reportsRoot,[StringComparison]::OrdinalIgnoreCase) -or -not [IO.File]::Exists((Join-Path $resolved 'report.html')) -or -not [IO.File]::Exists($reportZip)){throw 'Unexpected report location.'}
                        $reportPath=$resolved
                        $report.Status='ready';$report.ViewUrl='/report/'+$reportId;$report.DownloadUrl='/report/'+$reportId+'.zip'
                    }catch{$report.Status='error';$report.Error=$_.Exception.Message}
                }else{$report.Status='error';$report.Error=Read-Failure $reportErr $reportOut}
                $reportProcess.Dispose();$reportProcess=$null
            }
        }
        if($closing -and ((-not $worker -and -not $reportProcess) -or ([datetime]::UtcNow-$closingAt).TotalSeconds -gt 75)){break}
        $request=$hostBridge.Next(150)
        if(-not $request){continue}
        try{
            switch($request.Method+' '+$request.Path){
                'GET /' {$request.SendFile((Join-Path $data 'app.html'),'text/html; charset=utf-8',$null)}
                'GET /favicon.ico' {if(Test-Path -LiteralPath (Join-Path $PSScriptRoot 'app.ico')){$request.SendFile((Join-Path $PSScriptRoot 'app.ico'),'image/x-icon',$null)}else{$request.Respond(204,'image/x-icon','')}}
                'GET /guide/en' {$request.SendFile((Join-Path $script:ProjectRoot 'docs/guide.html'),'text/html; charset=utf-8',$null)}
                'GET /guide/de' {$request.SendFile((Join-Path $script:ProjectRoot 'docs/guide.de.html'),'text/html; charset=utf-8',$null)}
                'GET /api/state' {
                    $json=Get-LatestMeasurement
                    $control=[ordered]@{Phase=$(if($closing){'closing'}else{$phase});RunId=$runId;Error=$errorText;Preferences=$preferences;Adapters=@(Get-UiAdapters);Report=$report;Version='0.1.0';HostTimeUtc=[datetime]::UtcNow.ToString('o')}
                    $request.Respond(200,'application/json; charset=utf-8','{"control":'+($control|ConvertTo-Json -Depth 8 -Compress)+',"measurement":'+$json+'}')
                }
                'POST /api/start' {
                    if($worker -or $closing){$request.Respond(409,'application/json','{"error":"A measurement is already active or closing."}');break}
                    $value=$request.Body|ConvertFrom-Json
                    $settings=Resolve-UiSettings $value $config @(Get-UiAdapters)
                    $runId=[guid]::NewGuid().ToString('N');$runStarted=[datetime]::UtcNow;$errorText='';$stopRequested=$false
                    if(Test-Path -LiteralPath $stopFile){Remove-Item -LiteralPath $stopFile}
                    $settingsFile=Join-Path $data ('request-'+$runId+'.json');Write-AtomicText $settingsFile ($settings|ConvertTo-Json -Depth 12)
                    $preferences=$value;$saved=$value|ConvertTo-Json|ConvertFrom-Json;$saved.PauseUpdates=$false;Write-AtomicText $prefFile ($saved|ConvertTo-Json)
                    $workerStdout=Join-Path $data ('worker-'+$runId+'.log');$workerStderr=Join-Path $data ('worker-'+$runId+'.error.log')
                    $arguments='-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "'+(Join-Path $PSScriptRoot 'UiWorker.ps1')+'" -SettingsFile "'+$settingsFile+'" -DurationMinutes '+$settings.DurationMinutes+' -OwnerPid '+$PID
                    if($value.PauseUpdates){$arguments+=' -PauseUpdates'}
                    if($TestMaxSamples -gt 0){$arguments+=' -MaxSamples '+$TestMaxSamples}
                    $worker=Start-HiddenPowerShell $arguments $workerStdout $workerStderr;$phase='starting'
                    $request.Respond(200,'application/json','{"ok":true}')
                }
                'POST /api/stop' {
                    if($worker){$stopRequested=$true;$phase='stopping';Write-AtomicText $stopFile 'stop'}
                    $request.Respond(200,'application/json','{"ok":true}')
                }
                'POST /api/report' {
                    if($reportProcess -or $closing){$request.Respond(409,'application/json','{"error":"Report export is already running or the app is closing."}');break}
                    $v=$request.Body|ConvertFrom-Json
                    if(@($v.PSObject.Properties).Count -ne 2 -or $v.Minutes -isnot [int] -and $v.Minutes -isnot [long] -or $v.Minutes -notin @(0,5,60,1440,4320,10080,20160,43200) -or $v.Language -notin @('de','en')){throw 'Invalid report period.'}
                    $until=[datetime]::UtcNow;$since=if($v.Minutes -eq 0){[datetime]'2000-01-01T00:00:00Z'}else{$until.AddMinutes(-$v.Minutes)}
                    $reportId=[guid]::NewGuid().ToString('N');$reportOut=Join-Path $data ('export-'+$reportId+'.log');$reportErr=Join-Path $data ('export-'+$reportId+'.error.log')
                    $report=[pscustomobject]@{Status='running';ViewUrl='';DownloadUrl='';Error=''}
                    $reportResult=Join-Path $data ('export-'+$reportId+'.result.json');$reportZip=Join-Path $data ('report-'+$reportId+'.zip')
                    $reportArguments='-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "'+(Join-Path $PSScriptRoot 'Bericht.ps1')+'" -NoOpen -From "'+$since.ToString('o')+'" -To "'+$until.ToString('o')+'" -Language '+$v.Language+' -ResultFile "'+$reportResult+'" -ArchivePath "'+$reportZip+'"'
                    $reportProcess=Start-HiddenPowerShell $reportArguments $reportOut $reportErr
                    $request.Respond(200,'application/json','{"ok":true}')
                }
                'POST /api/close' {$closing=$true;$closingAt=[datetime]::UtcNow;$stopRequested=$true;Write-AtomicText $stopFile 'stop';$request.Respond(200,'application/json','{"ok":true}')}
                default {
                    if($request.Method -eq 'GET' -and $request.Path -match '^/guide/(guide(\.de)?|configuration|measurement-method|validation)\.html$'){$request.SendFile((Join-Path $script:ProjectRoot ('docs/'+$Matches[1]+'.html')),'text/html; charset=utf-8',$null)}
                    elseif($request.Method -eq 'GET' -and $report.Status -eq 'ready' -and $request.Path -eq '/report/'+$reportId){$request.SendFile((Join-Path $reportPath 'report.html'),'text/html; charset=utf-8',$null)}
                    elseif($request.Method -eq 'GET' -and $report.Status -eq 'ready' -and $request.Path -eq '/report/'+$reportId+'.zip'){$request.SendFile($reportZip,'application/zip','LinkLapse-report.zip')}
                    else{$request.Respond(404,'application/json','{"error":"Not found"}')}
                }
            }
        }catch{$request.Respond(400,'application/json; charset=utf-8',(@{error=$_.Exception.Message}|ConvertTo-Json -Compress))}
    }
}catch{
    Write-AtomicText (Join-Path $data 'ui-error.log') ($_.Exception.Message+[Environment]::NewLine+($_|Out-String));exit 1
}finally{
    if($worker){try{Write-AtomicText $stopFile 'stop'}catch{}}
    if($children){$children.Dispose()}
    if($hostBridge){$hostBridge.Dispose()}
    if($lock){$lock.Dispose()}
}
