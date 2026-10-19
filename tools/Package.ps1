[CmdletBinding()]
param([string]$DestinationDirectory='',[switch]$Force)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
if(-not $DestinationDirectory){$DestinationDirectory=Join-Path $root 'dist'}
$destination=[IO.Path]::GetFullPath($DestinationDirectory);[IO.Directory]::CreateDirectory($destination)|Out-Null
if(-not [IO.File]::Exists((Join-Path $root 'LinkLapse.exe'))){throw 'Run tools\Build.ps1 first.'}
$config=Get-Content -LiteralPath (Join-Path $root 'config.json') -Raw -Encoding UTF8|ConvertFrom-Json
if($config.InterfaceName -or $config.Topology.AccessPointAddress){throw 'Release config contains a personal adapter/AP. Restore public defaults before packaging.'}
$rootNames=@('README.md','README.de.md','LICENSE','CHANGELOG.md','CONTRIBUTING.md','SECURITY.md','config.json','.gitignore','.gitattributes','START.cmd')
$sourceFiles=@(Get-ChildItem -LiteralPath $root -Recurse -File -Force | Where-Object {
    $relative=$_.FullName.Substring($root.Length+1);$parts=$relative -split '[\\/]'
    ($relative -in $rootNames -or $parts[0] -in @('src','web','tests','tools','docs','.github')) -and
    -not @($parts | Where-Object {$_ -in @('.work','data','reports','.git','node_modules')}).Count -and
    $_.Extension -notin @('.tmp','.zip','.log','.sha256')
} | Sort-Object FullName)
foreach($file in $sourceFiles){if($file.Extension -eq '.ps1'){$b=[IO.File]::ReadAllBytes($file.FullName);if($b.Length -lt 3 -or $b[0] -ne 239 -or $b[1] -ne 187 -or $b[2] -ne 191){throw ('UTF-8 BOM required: '+$file.Name)}}}
$runtimeFiles=@($sourceFiles | Where-Object {
    $relative=$_.FullName.Substring($root.Length+1);$parts=$relative -split '[\\/]'
    $relative -in $rootNames -or $parts[0] -in @('src','web') -or
    ($parts[0] -eq 'docs' -and $parts[1] -notin @('releases','maintainers') -and $_.Name -notin @('social-preview.png'))
})+@(Get-Item -LiteralPath (Join-Path $root 'LinkLapse.exe'))
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$hashes=New-Object 'System.Collections.Generic.List[string]'
foreach($bundle in @(@{Name='LinkLapse-Windows-v0.1.0.zip';Files=$runtimeFiles},@{Name='LinkLapse-GitHub-v0.1.0.zip';Files=$sourceFiles})){
    $path=Join-Path $destination $bundle.Name
    if([IO.File]::Exists($path)){if(-not $Force){throw ('Destination exists: '+$path)};Remove-Item -LiteralPath $path}
    $stream=New-Object IO.FileStream($path,[IO.FileMode]::CreateNew)
    try{$zip=New-Object IO.Compression.ZipArchive($stream,[IO.Compression.ZipArchiveMode]::Create,$true)
        try{foreach($file in $bundle.Files){$entry='LinkLapse/'+$file.FullName.Substring($root.Length+1).Replace('\','/');[IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip,$file.FullName,$entry,[IO.Compression.CompressionLevel]::Optimal)|Out-Null}}
        finally{$zip.Dispose()}
    }finally{$stream.Dispose()}
    $hashes.Add((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()+'  '+$bundle.Name)
    Write-Host ($bundle.Name+': '+$bundle.Files.Count+' files')
}
[IO.File]::WriteAllText((Join-Path $destination 'SHA256SUMS.txt'),($hashes -join [Environment]::NewLine)+[Environment]::NewLine,(New-Object Text.UTF8Encoding($false)))
