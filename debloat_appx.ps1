<#
.SYNOPSIS
Removes built-in Windows consumer AppX bloat. Run as Intune PLATFORM SCRIPT
(device context, SYSTEM) - ideally during the ESP, before the first login.

.DESCRIPTION
Blocklist-based: removes the listed apps for all existing users AND as
provisioned package, so new profiles never receive them. Everything not on
the list (Store, Calculator, Photos, Snipping Tool, Terminal, Quick Assist,
MSTeams (werk), etc.) is untouched.

Safe to re-run: already-removed packages are simply skipped.
Log: %ProgramData%\DebloatAppx\appx.log
#>

$ErrorActionPreference = 'SilentlyContinue'
$log = "$env:ProgramData\DebloatAppx\appx.log"
New-Item -ItemType Directory -Path (Split-Path $log) -Force | Out-Null
Start-Transcript -Path $log -Append | Out-Null
Write-Output "==== AppX debloat started $(Get-Date -Format s) ===="

$blocklist = @(
    'Clipchamp.Clipchamp'
    'Microsoft.549981C3F5F10'               # Cortana (oud)
    'Microsoft.BingNews'
    'Microsoft.BingSearch'
    'Microsoft.BingWeather'
    'Microsoft.Copilot'
    'Microsoft.GamingApp'                   # Xbox app
    'Microsoft.GetHelp'
    'Microsoft.Getstarted'                  # Tips
    'Microsoft.Messaging'
    'Microsoft.MicrosoftOfficeHub'          # "Microsoft 365"-promo-app
    'Microsoft.MicrosoftSolitaireCollection'
    'Microsoft.MixedReality.Portal'
    'Microsoft.People'
    'Microsoft.SkypeApp'
    'Microsoft.Todos'
    'Microsoft.Wallet'
    'Microsoft.Windows.DevHome'
    'Microsoft.WindowsFeedbackHub'
    'Microsoft.WindowsMaps'
    'Microsoft.Xbox.TCUI'
    'Microsoft.XboxGameOverlay'
    'Microsoft.XboxGamingOverlay'
    'Microsoft.XboxIdentityProvider'
    'Microsoft.XboxSpeechToTextOverlay'
    'Microsoft.ZuneVideo'                   # Films en tv
    'Microsoft.windowscommunicationsapps'   # Mail/Agenda (deprecated)
    'MicrosoftTeams'                        # consumer Teams/Chat (NIET 'MSTeams' = werk-Teams)

    # --- Optioneel: haal het hekje weg als je ze ook kwijt wilt ---
    # 'Microsoft.OutlookForWindows'         # nieuwe Outlook
    # 'Microsoft.YourPhone'                 # Phone Link
    # 'Microsoft.ZuneMusic'                 # Media Player
    # 'Microsoft.WindowsAlarms'             # Klok/wekkers
    # 'Microsoft.PowerAutomateDesktop'
)

foreach ($app in $blocklist) {

    # 1. Verwijderen voor alle bestaande gebruikers
    Get-AppxPackage -AllUsers -Name $app | ForEach-Object {
        try {
            Remove-AppxPackage -AllUsers -Package $_.PackageFullName -ErrorAction Stop
            Write-Output "Removed AppX: $($_.Name)"
        }
        catch { Write-Output "AppX remove failed $($_.Name): $($_.Exception.Message)" }
    }

    # 2. Provisioned package verwijderen -> nieuwe profielen krijgen de app nooit
    Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -eq $app } | ForEach-Object {
        try {
            Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction Stop | Out-Null
            Write-Output "Removed provisioned: $($_.DisplayName)"
        }
        catch { Write-Output "Provisioned remove failed $($_.DisplayName): $($_.Exception.Message)" }
    }
}

# --- Diagnostics: wat is er nog provisioned? --------------------------------
$remaining = (Get-AppxProvisionedPackage -Online).DisplayName | Sort-Object
Write-Output "Remaining provisioned packages: $($remaining -join '; ')"

Write-Output "==== AppX debloat finished $(Get-Date -Format s) ===="
Stop-Transcript | Out-Null
exit 0
