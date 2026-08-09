<#
.SYNOPSIS
    Remediation - removes selected Lenovo bloatware. Runs as SYSTEM via Intune.
.DESCRIPTION
    Removes: Lenovo Now, Lenovo Vantage Service, Lenovo Vantage (AppX).
    KEEPS:   Lenovo Smart Meeting Components (and all other Lenovo hardware apps).

    v2 fix: properly parses the registry UninstallString into exe + arguments
    (Lenovo strings look like  "C:\..\Uninstall.exe" /SILENT ). Reads paths live
    from the registry each run, because Lenovo re-provisions with new versions.
#>

$ErrorActionPreference = 'SilentlyContinue'

$workDir = Join-Path $env:ProgramData 'LenovoDebloat'
New-Item -ItemType Directory -Path $workDir -Force | Out-Null
Start-Transcript -Path (Join-Path $workDir 'debloat.log') -Append | Out-Null
Write-Output "==== Lenovo debloat v2 started $(Get-Date -Format s) as $env:USERNAME ===="

function Invoke-WithTimeout {
    param([string]$FilePath, [string]$Arguments, [int]$TimeoutSec = 300)
    try {
        if ($Arguments) {
            $p = Start-Process -FilePath $FilePath -ArgumentList $Arguments -PassThru -WindowStyle Hidden
        } else {
            $p = Start-Process -FilePath $FilePath -PassThru -WindowStyle Hidden
        }
        if ($p.WaitForExit($TimeoutSec * 1000)) { Write-Output "Exit $($p.ExitCode): $FilePath $Arguments" }
        else { Write-Output "TIMEOUT $($TimeoutSec)s -> killed: $FilePath"; $p.Kill() }
    } catch { Write-Output "ERROR launching $FilePath : $($_.Exception.Message)" }
}

# Split a registry UninstallString into executable path + arguments.
function Split-UninstallString {
    param([string]$Raw)
    $Raw = $Raw.Trim()
    if ($Raw -match '^\s*"([^"]+)"\s*(.*)$') { return @{ Exe = $matches[1]; Args = $matches[2].Trim() } }
    if ($Raw -match '^\s*(\S+\.exe)\s*(.*)$') { return @{ Exe = $matches[1]; Args = $matches[2].Trim() } }
    return @{ Exe = $Raw; Args = '' }
}

$targetNames = @('Lenovo Now', 'Lenovo Vantage Service')
$roots = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
)

# --- 1. Classic installs (Lenovo Now, Vantage Service) -----------------------
Get-ItemProperty $roots |
    Where-Object { $targetNames -contains $_.DisplayName } |
    ForEach-Object {
        $name = $_.DisplayName
        $raw  = if ($_.QuietUninstallString) { $_.QuietUninstallString } else { $_.UninstallString }
        if (-not $raw) { Write-Output "No uninstall string for $name"; return }

        $parsed  = Split-UninstallString $raw
        $exe     = $parsed.Exe
        $exeArgs = $parsed.Args

        if (-not (Test-Path $exe)) { Write-Output "Uninstaller not found for ${name}: $exe"; return }
        Write-Output "Uninstalling: $name  (exe=$exe  args='$exeArgs')"

        $hasSilent = $exeArgs -match '(?i)(/|-)(very)?silent|/qn|/quiet'

        if ($exe -match '(?i)msiexec') {
            $guid = [regex]::Match($raw, '\{[0-9A-Fa-f\-]{36}\}').Value
            if ($guid) { Invoke-WithTimeout 'msiexec.exe' "/x $guid /qn /norestart" 300 }
        }
        elseif ($exe -match '(?i)unins\d+\.exe$') {
            # Inno Setup uninstaller
            $a = if ($hasSilent) { $exeArgs } else { '/VERYSILENT /NORESTART /SUPPRESSMSGBOXES' }
            Invoke-WithTimeout $exe $a 300
        }
        else {
            # Lenovo custom Uninstall.exe -> /silent (verified working)
            $a = if ($hasSilent) { $exeArgs } else { '/silent' }
            Invoke-WithTimeout $exe $a 300
        }
    }

# --- 2. Vantage frontend AppX (installed + provisioned) ----------------------
Get-AppxPackage -AllUsers -Name 'E046963F.LenovoCompanion' | ForEach-Object {
    try { Remove-AppxPackage -AllUsers -Package $_.PackageFullName -ErrorAction Stop; Write-Output "Removed AppX: $($_.Name)" }
    catch { Write-Output "AppX remove failed: $($_.Exception.Message)" }
}
Get-AppxProvisionedPackage -Online |
    Where-Object { $_.DisplayName -like '*LenovoCompanion*' } |
    ForEach-Object {
        try { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction Stop | Out-Null; Write-Output "Removed provisioned: $($_.PackageName)" }
        catch { Write-Output "Provisioned remove failed: $($_.Exception.Message)" }
    }

# --- 3. Diagnostics ----------------------------------------------------------
$remaining = (Get-ItemProperty $roots | Where-Object { $_.DisplayName -like '*Lenovo*' }).DisplayName
Write-Output "Remaining Lenovo entries: $($remaining -join '; ')"

Write-Output "==== Lenovo debloat v2 finished $(Get-Date -Format s) ===="
Stop-Transcript | Out-Null
exit 0
