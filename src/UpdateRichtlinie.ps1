[CmdletBinding()]
param([ValidateSet('Apply','Watch','Restore','Status','Library')][string]$Mode='Status', [int]$OwnerPid=0)
$ErrorActionPreference='Stop'
$script:PolicyKey='SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'
$script:PolicyValue='NoAutoUpdate'
$script:TaskName='InternetMonitor-UpdatePolicy-Restore-v1'
$script:SecureRoot=Join-Path ([Environment]::GetFolderPath('CommonApplicationData')) 'InternetMonitor-Policy-v1'
function Get-PolicyValue([Microsoft.Win32.RegistryKey]$Root, [string]$Key, [string]$Name) {
    $k=$Root.OpenSubKey($Key)
    try {
        if ($null -eq $k -or $k.GetValueNames() -notcontains $Name) { return [pscustomobject]@{Exists=$false;Value=0;Kind='DWord'} }
        $kind=$k.GetValueKind($Name).ToString()
        if ($kind -ne 'DWord') { throw "Ungewöhnlicher Registry-Typ für $Name ($kind); wird nicht überschrieben." }
        return [pscustomobject]@{Exists=$true;Value=[int]$k.GetValue($Name);Kind=$kind}
    } finally { if ($k) { $k.Dispose() } }
}
function Set-PolicyValue([Microsoft.Win32.RegistryKey]$Root, [string]$Key, [string]$Name, [int]$Value) {
    $k=$Root.CreateSubKey($Key)
    try { $k.SetValue($Name,$Value,[Microsoft.Win32.RegistryValueKind]::DWord) } finally { $k.Dispose() }
}
function Restore-PolicyValue([Microsoft.Win32.RegistryKey]$Root,[string]$Key,[string]$Name,$Original) {
    $now=Get-PolicyValue $Root $Key $Name
    # Never overwrite a later change by IT, Windows or another administrator.
    if (-not $now.Exists -or $now.Value -ne 1) { return 'Conflict: current value was changed elsewhere; left untouched' }
    if ($Original.Exists) { Set-PolicyValue $Root $Key $Name ([int]$Original.Value) }
    else {
        $k=$Root.OpenSubKey($Key,$true)
        try { if ($k) { $k.DeleteValue($Name,$false) } } finally { if ($k) {$k.Dispose()} }
    }
    return 'Restored'
}
function Save-State($State) {
    $file=Join-Path $script:SecureRoot 'state.json'
    $temp=Join-Path $script:SecureRoot ([guid]::NewGuid().ToString('N')+'.tmp')
    try {
        [IO.File]::WriteAllText($temp,($State | ConvertTo-Json -Depth 8),(New-Object Text.UTF8Encoding($true)))
        if (Test-Path -LiteralPath $file) { [IO.File]::Replace($temp,$file,[NullString]::Value) } else { [IO.File]::Move($temp,$file) }
    } finally {if (Test-Path -LiteralPath $temp) {Remove-Item -LiteralPath $temp}}
}
function Assert-SecureFolder {
    $admins=New-Object Security.Principal.SecurityIdentifier('S-1-5-32-544')
    $system=New-Object Security.Principal.SecurityIdentifier('S-1-5-18')
    if (-not [IO.Directory]::Exists($script:SecureRoot)) {
        $acl=New-Object Security.AccessControl.DirectorySecurity
        $acl.SetAccessRuleProtection($true,$false);$acl.SetOwner($admins)
        foreach ($sid in @($admins,$system)) {
            $rule=New-Object Security.AccessControl.FileSystemAccessRule($sid,'FullControl','ContainerInherit,ObjectInherit','None','Allow')
            $acl.AddAccessRule($rule)
        }
        [IO.Directory]::CreateDirectory($script:SecureRoot,$acl) | Out-Null
    }
    $item=Get-Item -LiteralPath $script:SecureRoot -Force
    if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {throw 'Der Richtlinienordner darf keine Verknüpfung sein.'}
    $acl=$item.GetAccessControl()
    if ($acl.GetOwner([Security.Principal.SecurityIdentifier]).Value -notin @($admins.Value,$system.Value)) {throw 'Unsicherer Eigentümer des Richtlinienordners.'}
    foreach ($rule in $acl.GetAccessRules($true,$true,[Security.Principal.SecurityIdentifier])) {
        if ($rule.AccessControlType -eq 'Allow' -and $rule.IdentityReference.Value -notin @($admins.Value,$system.Value)) {throw 'Richtlinienordner hat unerwartete Zugriffsrechte; keine Änderung durchgeführt.'}
    }
}
if ($Mode -eq 'Library') { return }
$mutex=$null;$ownsMutex=$false;$script:FailureCode=1
try {
    $identity=[Security.Principal.WindowsIdentity]::GetCurrent()
    $principal=New-Object Security.Principal.WindowsPrincipal($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {throw 'Für die Richtlinienverwaltung als Administrator ausführen.'}
    $mutex=New-Object Threading.Mutex($false,'Global\InternetMonitor-UpdatePolicy-v1')
    try {$ownsMutex=$mutex.WaitOne(15000)} catch [Threading.AbandonedMutexException] {$ownsMutex=$true}
    if (-not $ownsMutex) {throw 'Eine andere Richtlinienänderung läuft gerade.'}
    Assert-SecureFolder
    $stateFile=Join-Path $script:SecureRoot 'state.json'
    $state=if (Test-Path -LiteralPath $stateFile) {Get-Content -LiteralPath $stateFile -Raw -Encoding UTF8 | ConvertFrom-Json} else {$null}
    if ($Mode -eq 'Status') {
        if ($state) {$state | Format-List} else {Write-Host 'Keine gesicherte Richtliniensitzung vorhanden.'}
        Get-PolicyValue ([Microsoft.Win32.Registry]::LocalMachine) $script:PolicyKey $script:PolicyValue | Format-List
        exit 0
    }
    if ($Mode -eq 'Apply') {
        $edition=(Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name EditionID).EditionID
        if ($edition -notmatch 'Professional|Enterprise|Education|IoT') {$script:FailureCode=10;throw 'Diese Update-Richtlinie wird hier nur für Windows Pro/Enterprise/Education/IoT eingerichtet. Auf Home stattdessen die Windows-Update-Pause verwenden.'}
        $pending=@('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired','HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending')
        foreach ($p in $pending) {if (Test-Path -LiteralPath $p) {$script:FailureCode=11;throw 'Windows meldet bereits einen ausstehenden Neustart. Diesen vor der Messung regulär abschließen; es wird jetzt kein Neustart ausgelöst.'}}
        if ($state -and $state.Active) {$script:FailureCode=12;throw 'Es gibt bereits eine aktive Richtliniensitzung. Erst ZURUECKSETZEN-RICHTLINIE.cmd ausführen.'}
        if ($OwnerPid -le 0) {throw 'Gültiger Besitzerprozess erforderlich.'}
        $owner=Get-Process -Id $OwnerPid -ErrorAction Stop
        $original=Get-PolicyValue ([Microsoft.Win32.Registry]::LocalMachine) $script:PolicyKey $script:PolicyValue
        if ($state) {Copy-Item -LiteralPath $stateFile -Destination (Join-Path $script:SecureRoot ('history-'+[guid]::NewGuid().ToString('N')+'.json'))}
        $state=[pscustomobject][ordered]@{Version=1;Active=$true;AppliedUtc=[datetime]::UtcNow.ToString('o');OwnerPid=$OwnerPid;OwnerStartTicks=$owner.StartTime.ToUniversalTime().Ticks;Original=$original;Outcome='Pending';RestoredUtc=''}
        Save-State $state
        $helper=Join-Path $script:SecureRoot 'PolicyHelper.ps1'
        Copy-Item -LiteralPath $PSCommandPath -Destination $helper -Force
        $hostExe=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
        $action=New-ScheduledTaskAction -Execute $hostExe -Argument ('-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "'+$helper+'" -Mode Watch')
        $trigger=New-ScheduledTaskTrigger -Once -At ([datetime]::Now.AddMinutes(1)) -RepetitionInterval (New-TimeSpan -Minutes 1)
        $settings=New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 2)
        try {
            Register-ScheduledTask -TaskName $script:TaskName -Action $action -Trigger $trigger -Settings $settings -User 'SYSTEM' -RunLevel Highest -Force | Out-Null
            Set-PolicyValue ([Microsoft.Win32.Registry]::LocalMachine) $script:PolicyKey $script:PolicyValue 1
            $read=Get-PolicyValue ([Microsoft.Win32.Registry]::LocalMachine) $script:PolicyKey $script:PolicyValue
            if (-not $read.Exists -or $read.Value -ne 1) {throw 'Richtlinienwert konnte nicht verifiziert werden.'}
            $state.Outcome='Applied: NoAutoUpdate=1; waiting for owner process to end';Save-State $state
        } catch {
            $state.Outcome=Restore-PolicyValue ([Microsoft.Win32.Registry]::LocalMachine) $script:PolicyKey $script:PolicyValue $original
            $state.Active=$false;Save-State $state
            Unregister-ScheduledTask -TaskName $script:TaskName -Confirm:$false -ErrorAction SilentlyContinue
            throw
        }
        Write-Host 'Automatische Windows-Updates per Richtlinie deaktiviert. Rücksetzung nach Ende des Besitzerprozesses innerhalb etwa einer Minute.'
        exit 0
    }
    if (-not $state) {if ($Mode -eq 'Watch') {throw 'Richtliniensicherung fehlt; keine automatische Änderung möglich.'};exit 0}
    if (-not $state.Active) {Unregister-ScheduledTask -TaskName $script:TaskName -Confirm:$false -ErrorAction SilentlyContinue;exit 0}
    if ($Mode -eq 'Watch') {
        $alive=$false
        try {$p=Get-Process -Id $state.OwnerPid -ErrorAction Stop;$alive=($p.StartTime.ToUniversalTime().Ticks -eq [long]$state.OwnerStartTicks)} catch {}
        if ($alive) {exit 0}
    }
    $state.Outcome=Restore-PolicyValue ([Microsoft.Win32.Registry]::LocalMachine) $script:PolicyKey $script:PolicyValue $state.Original
    $state.Active=$false;$state.RestoredUtc=[datetime]::UtcNow.ToString('o');Save-State $state
    Unregister-ScheduledTask -TaskName $script:TaskName -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host ('Richtliniensitzung abgeschlossen: '+$state.Outcome)
} catch {
    [Console]::Error.WriteLine($_.Exception.Message)
    exit $script:FailureCode
} finally {
    if ($mutex) {if ($ownsMutex) {$mutex.ReleaseMutex()};$mutex.Dispose()}
}
