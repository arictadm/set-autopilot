<#
.SYNOPSIS
    Sets 125% display scaling as the DEFAULT for all NEW user profiles.
.DESCRIPTION
    DPI scaling is per-user (HKCU\Control Panel\Desktop). To make every new
    profile default to 125%, this writes into the Default User hive
    (C:\Users\Default\NTUSER.DAT). Existing profiles are NOT changed, and the
    setting is only a DEFAULT - the user can change it afterwards.

    Deploy as an Intune PLATFORM SCRIPT (device, SYSTEM) - ideally runs during
    the ESP, before the first user logs in, so their new profile inherits 125%.

    LogPixels values: 96 = 100%, 120 = 125%, 144 = 150%, 168 = 175%
#>

$ErrorActionPreference = 'Stop'
$log = "$env:ProgramData\SetDefaultDPI\dpi.log"
New-Item -ItemType Directory -Path (Split-Path $log) -Force | Out-Null
Start-Transcript -Path $log -Append | Out-Null
Write-Output "==== Set default DPI 125% started $(Get-Date -Format s) ===="

$hive     = "C:\Users\Default\NTUSER.DAT"
$mountKey = "HKU\DefaultDPITemp"

try {
    reg load $mountKey $hive | Out-Null
    Write-Output "Loaded Default User hive."

    $regPath = "Registry::$mountKey\Control Panel\Desktop"
    New-ItemProperty -Path $regPath -Name 'LogPixels'      -Value 120 -PropertyType DWord -Force | Out-Null
    New-ItemProperty -Path $regPath -Name 'Win8DpiScaling' -Value 1   -PropertyType DWord -Force | Out-Null
    Write-Output "Set LogPixels=120 (125%) and Win8DpiScaling=1 in Default hive."
}
catch {
    Write-Output "ERROR: $($_.Exception.Message)"
}
finally {
    # Always unload, and force GC first so the hive isn't locked
    [gc]::Collect(); Start-Sleep -Seconds 2
    reg unload $mountKey | Out-Null
    Write-Output "Unloaded Default User hive."
}

Write-Output "==== finished $(Get-Date -Format s) ===="
Stop-Transcript | Out-Null
exit 0
