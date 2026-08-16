# Requires -Version 5.1
<#
.SYNOPSIS
    Automated Deployment & Update script for SecureContacts via Public GitHub Releases.
.DESCRIPTION
    This script queries the latest release of SecureContacts from a public GitHub repository,
    downloads the MSI installer, verifies its integrity (if a .sha256 file is provided), and
    performs a silent installation or update on the local machine.

    Intune Requirements:
    - Exit Code 0 = Successful install/update
    - Exit Code 3010 = Successful install/update requiring reboot
    - Exit Code 1603 = Fatal failure (MSI error or script-level failure such as download or integrity check)
    - Any other non-zero exit code from msiexec will be propagated as-is

    Parameters:
    - PublicReleaseRepo : GitHub owner/repo slug (default: Provectus-Software-GmbH/SCA_Desktop_Releases)
    - FileNamePattern   : Glob pattern to select the MSI asset from the release (default: *.msi)
    - GitHubToken       : Optional. For most deployments this parameter is not needed.
                          GitHub's API allows 60 requests/hour per IP address without a token.
                          In practice this limit is only a concern in environments where all
                          devices share a single internet connection — for example, a large
                          office behind a traditional corporate web proxy with no split-tunnel.
                          Home office, direct internet, and split-tunnel VPN setups each have
                          their own IP and are unaffected.
                          
                          The token only needs read access to public repositories — no extra
                          permissions required. To create one (takes about 2 minutes):
                            1. Sign in to GitHub and go to:
                               https://github.com/settings/personal-access-tokens/new
                            2. Enter a name (e.g. "SCA Intune Deploy") and set an expiry date.
                            3. Under "Repository access" choose "Public repositories (read-only)".
                            4. Leave all permission dropdowns at "No access" and click Generate token.
                            5. Copy the token value (it starts with github_pat_).

                          Pass the token in the Intune Win32 app Install command:
                            powershell.exe -ExecutionPolicy Bypass -File Deploy-SecureContacts.ps1 -GitHubToken "github_pat_xxx"

                          The Intune portal encrypts the install command — the token is not
                          visible to end users or shown in plain text on managed devices.
#>
[CmdletBinding()]
param(
    [string]$PublicReleaseRepo = "Provectus-Software-GmbH/SCA_Desktop_Releases",
    [string]$FileNamePattern   = "*.msi",
    [string]$GitHubToken       = ""  # optional; see .DESCRIPTION for details
)

$ErrorActionPreference = 'Stop'

# Build shared API headers; add auth only when a token is supplied
$ApiHeaders = @{ "User-Agent" = "Intune-Deploy-Agent" }
if ($GitHubToken) { $ApiHeaders["Authorization"] = "Bearer $GitHubToken" }

try {
    # 1. Fetch latest release metadata from public GitHub API (No auth required)
    Write-Host "Querying latest release from public repo: $PublicReleaseRepo..."
    $ApiUrl = "https://api.github.com/repos/$PublicReleaseRepo/releases/latest"
    
    # User-Agent header is required; GitHub API rejects requests without one
    $ReleaseData = Invoke-RestMethod -Uri $ApiUrl -Method Get -Headers $ApiHeaders

    # 2. Extract the direct browser download URL for the .msi asset
    $MsiAsset = $ReleaseData.assets | Where-Object { $_.name -like $FileNamePattern } | Select-Object -First 1

    if (-not $MsiAsset) {
        Write-Error "No installer matching '$FileNamePattern' found in the latest release."
        exit 1603
    }

    $DirectDownloadUrl = $MsiAsset.browser_download_url
    $TargetVersion = $ReleaseData.tag_name
    Write-Host "Found version $TargetVersion at: $DirectDownloadUrl"

    # 2a. Compare release version against installed version before downloading
    $UninstallPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    $InstalledApp = Get-ItemProperty -Path $UninstallPaths -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like "*Secure Contacts*" } | Select-Object -First 1
    if ($InstalledApp -and $InstalledApp.DisplayVersion) {
        try {
            $releaseVer    = [version]($TargetVersion.TrimStart('v'))
            $installedVer  = [version]$InstalledApp.DisplayVersion
            # Compare Major.Minor.Build only; registry adds a 4th .0 that GitHub tags omit
            $installedShort = [version]"$($installedVer.Major).$($installedVer.Minor).$($installedVer.Build)"
            if ($installedShort -eq $releaseVer) {
                Write-Host "Secure Contacts $($InstalledApp.DisplayVersion) is already installed and up to date. No download needed."
                exit 0
            }
        } catch {
            # Non-parseable DisplayVersion - fall through to install
        }
    }

    # 2b. Kill any running instance before updating to avoid locked-file failures during MSI upgrade
    $AppProcesses = @(
        (Get-Process -Name "SecureContacts" -ErrorAction SilentlyContinue),
        (Get-Process -Name "SecContacts" -ErrorAction SilentlyContinue),
        (Get-Process | Where-Object { $_.MainWindowTitle -like "*Secure Contacts*" } -ErrorAction SilentlyContinue)
    ) | Where-Object { $_ }
    
    if ($AppProcesses) {
        Write-Host "Stopping running Secure Contacts instance(s) before update..."
        $AppProcesses | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
    }

    # 3. Download the MSI directly to a local temporary directory
    $TempPath = Join-Path -Path $env:TEMP -ChildPath "SecureContacts_$TargetVersion.msi"
    Write-Host "Downloading installer to local cache: $TempPath"
    Invoke-WebRequest -Uri $DirectDownloadUrl -OutFile $TempPath -UseBasicParsing

    # 4. Verify file integrity against a companion .sha256 asset if one is published
    $HashAsset = $ReleaseData.assets | Where-Object { $_.name -eq "$($MsiAsset.name).sha256" } | Select-Object -First 1
    if ($HashAsset) {
        $HashContent  = (Invoke-WebRequest -Uri $HashAsset.browser_download_url -UseBasicParsing -Headers $ApiHeaders).Content.Trim()
        $ExpectedHash = ($HashContent -split '\s+')[0].ToUpper()  # handle both bare-hash and 'hash  filename' formats
        $ActualHash   = (Get-FileHash -Path $TempPath -Algorithm SHA256).Hash.ToUpper()
        if ($ActualHash -ne $ExpectedHash) {
            Remove-Item -Path $TempPath -Force
            Write-Error "SHA-256 mismatch for $($MsiAsset.name).`nExpected: $ExpectedHash`nGot:      $ActualHash"
            exit 1603
        }
        Write-Host "SHA-256 integrity check passed."
    } else {
        Write-Warning "No .sha256 companion asset found for $($MsiAsset.name) - skipping integrity check."
    }

    # 5. Unblock the downloaded file to remove the Zone Identifier (Mark of the Web) added by Invoke-WebRequest;
    #    without this, SmartScreen silently blocks silent MSI installs with exit code 1603 on local runs.
    #    This is a no-op in Intune/SCCM — the management agent does not attach a Zone Identifier.
    Unblock-File -Path $TempPath

    # 6. Execute silent background installation via msiexec with verbose log for diagnostics
    $LogPath = Join-Path -Path $env:TEMP -ChildPath "SecureContacts_$TargetVersion_install.log"
    Write-Host "Executing silent MSI installation..."
    $Process = Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$TempPath`" /qn /norestart /l*v `"$LogPath`"" -Wait -PassThru -NoNewWindow

    # 7. Clean up downloaded MSI; keep log only on failure for diagnostics
    if (Test-Path $TempPath) { Remove-Item -Path $TempPath -Force }

    if ($Process.ExitCode -eq 0 -or $Process.ExitCode -eq 3010) {
        Write-Host "SecureContacts $TargetVersion successfully installed/updated (Exit Code: $($Process.ExitCode))."
        if (Test-Path $LogPath) { Remove-Item -Path $LogPath -Force }
        exit 0
    } else {
        Write-Error "MSI installation failed with exit code $($Process.ExitCode). Review install log: $LogPath"
        exit $Process.ExitCode
    }

} catch {
    Write-Error "Deployment script failed: $_"
    exit 1603  # Generic failure sentinel; actual MSI exit codes are handled above
}