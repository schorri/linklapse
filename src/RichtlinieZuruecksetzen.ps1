$ErrorActionPreference='Stop'
try {
    $exe=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $helper=Join-Path $PSScriptRoot 'UpdateRichtlinie.ps1'
    $adminArguments='-NoLogo -NoProfile -ExecutionPolicy Bypass -File "'+$helper+'" -Mode Restore'
    $p=Start-Process -FilePath $exe -Verb RunAs -WindowStyle Hidden -ArgumentList $adminArguments -Wait -PassThru
    if ($p.ExitCode -ne 0) {throw 'Rücksetzung fehlgeschlagen. UpdateRichtlinie.ps1 -Mode Status als Administrator prüfen.'}
    Write-Host 'Rücksetzung abgeschlossen. Spätere Änderungen anderer Stellen bleiben unberührt. Vorher bereits deaktivierte Updates bleiben wie ursprünglich deaktiviert.'
} catch {Write-Host $_.Exception.Message -ForegroundColor Red;exit 1}
