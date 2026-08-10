<#
.SYNOPSIS
    Offline Autopilot hardware-hash harvester for USB use during OOBE.
.DESCRIPTION
    Reads the device serial number + hardware hash straight from WMI. No internet,
    no PowerShell Gallery install, no Microsoft Graph sign-in (so it sidesteps the
    WAM window-handle problem entirely). Writes an Intune-ready CSV next to this
    script on the USB stick, and also appends the row to a combined CSV so you can
    register several devices in one import.

    USE AT OOBE:
      1. On the target device press Shift+F10 (opens a command prompt).
      2. Plug in the USB stick, find its drive letter (e.g. run: wmic logicaldisk get name)
      3. Run:  powershell -ExecutionPolicy Bypass -File D:\Get-AutopilotHash.ps1
         (replace D: with your USB drive letter)  -- or just run Collect-AutopilotHash.cmd

    Default Group Tag is sec-security. Override with -GroupTag "something-else".

    THEN: take the USB to a PC with portal access and import the CSV in Intune:
      Devices > Enrollment > Devices > Import.
#>

param(
    [string]$GroupTag = 'sec-security'
)

$ErrorActionPreference = 'Stop'

# This script's folder = the USB folder, so the CSV lands on the stick.
$outDir = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($outDir)) { $outDir = (Get-Location).Path }

try {
    Write-Host "Collecting Autopilot hardware hash..." -ForegroundColor Cyan

    $serial = (Get-CimInstance -ClassName Win32_BIOS).SerialNumber
    if ($serial) { $serial = $serial.Trim() }

    $hash = (Get-CimInstance -Namespace 'root/cimv2/mdm/dmmap' `
                -ClassName MDM_DevDetail_Ext01 `
                -Filter "InstanceID='Ext' AND ParentID='./DevDetail'").DeviceHardwareData

    if ([string]::IsNullOrWhiteSpace($hash)) {
        throw "Hardware hash came back empty. Run in an elevated / OOBE (Shift+F10) session."
    }

    # Intune import columns. 'Windows Product ID' may stay empty - Intune matches
    # on serial + hash. Group Tag is the 4th column.
    $header = 'Device Serial Number,Windows Product ID,Hardware Hash,Group Tag'
    $row    = "$serial,,$hash,$GroupTag"

    # 1. Per-device CSV (safe filename with the serial).
    $safeSerial = ($serial -replace '[^A-Za-z0-9\-]', '_')
    $perDevice  = Join-Path $outDir "AutopilotHash_$safeSerial.csv"
    Set-Content -Path $perDevice -Value $header, $row -Encoding ASCII

    # 2. Combined CSV for bulk import (header once, then append each device).
    $combined = Join-Path $outDir 'AutopilotHashes.csv'
    if (-not (Test-Path $combined)) {
        Set-Content -Path $combined -Value $header -Encoding ASCII
    }
    Add-Content -Path $combined -Value $row -Encoding ASCII

    Write-Host ""
    Write-Host "  Serial    : $serial"   -ForegroundColor Green
    Write-Host "  Group Tag : $GroupTag" -ForegroundColor Green
    Write-Host "  Saved     : $perDevice" -ForegroundColor Green
    Write-Host "  Appended  : $combined"  -ForegroundColor Green
    Write-Host ""
    Write-Host "Next: import the CSV in Intune > Devices > Enrollment > Devices > Import." -ForegroundColor Cyan
}
catch {
    Write-Host "FAILED: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Tip: at OOBE press Shift+F10 (that prompt is already elevated) and re-run." -ForegroundColor Yellow
    exit 1
}
