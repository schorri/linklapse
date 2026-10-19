[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$utf8=New-Object Text.UTF8Encoding($true)
foreach($file in @(Get-ChildItem -LiteralPath $root -Recurse -Filter '*.ps1' -File | Where-Object {$_.FullName -notmatch '[\\/](data|reports|\.git|\.work)[\\/]'})){
    $text=[IO.File]::ReadAllText($file.FullName).Replace("`r`n","`n").Replace("`n","`r`n")
    [IO.File]::WriteAllText($file.FullName,$text,$utf8)
}
$compiler=Join-Path $env:SystemRoot 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
if(-not (Test-Path -LiteralPath $compiler)){$compiler=Join-Path $env:SystemRoot 'Microsoft.NET/Framework/v4.0.30319/csc.exe'}
& $compiler /nologo /target:winexe /optimize+ /platform:anycpu /reference:System.Windows.Forms.dll ('/win32icon:'+(Join-Path $root 'src/app.ico')) ('/out:'+(Join-Path $root 'LinkLapse.exe')) (Join-Path $root 'src/Launcher.cs')
if($LASTEXITCODE -ne 0){throw 'Launcher build failed.'}
Write-Host 'Built LinkLapse.exe. Windows PowerShell scripts use UTF-8 BOM / CRLF.'
