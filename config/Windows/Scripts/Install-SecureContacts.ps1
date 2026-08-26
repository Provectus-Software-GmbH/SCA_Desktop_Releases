# Requires -Version 5.1
<#
.SYNOPSIS
    Automated Deployment & Update script for SecureContacts via Public GitHub Releases.
.DESCRIPTION
    This script queries the latest release of SecureContacts from a public GitHub repository,
    downloads the MSI installer, verifies its integrity (if a .sha256 file is provided), and
    performs a silent installation or update on the local machine.

    Default return-code behavior:
    - Exit Code 0 = Successful install/update
    - Exit Code 1603 = Fatal failure (MSI error or script-level failure such as download or integrity check)
    - MSI Exit Code 3010 is normalized to Exit Code 0 by default for Intune-friendly behavior
    - Any other non-zero exit code from msiexec will be propagated as-is

    Parameters:
    - AppName           : Display name used to identify the installed app in registry
                          (default: Secure Contacts).
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
                            powershell.exe -ExecutionPolicy Bypass -File Install-SecureContacts.ps1 -GitHubToken "github_pat_xxx"

                          The Intune portal encrypts the install command — the token is not
                          visible to end users or shown in plain text on managed devices.
    - MsiPath           : Optional. Installs from a local MSI path instead of downloading from
                          GitHub Releases. Use this when the MSI is bundled into Intune or SCCM
                          package content and devices should not fetch installers at runtime.
    - PassRebootCode    : Optional. When set, preserves MSI exit code 3010 so deployment
                          systems such as SCCM/MECM can detect reboot-required installs.
                          When omitted, MSI exit code 3010 is normalized to exit code 0.
#>
[CmdletBinding(DefaultParameterSetName = 'GitHub')]
param(
    [string]$AppName = "Secure Contacts",

    [Parameter(ParameterSetName = 'GitHub')]
    [string]$PublicReleaseRepo = "Provectus-Software-GmbH/SCA_Desktop_Releases",

    [Parameter(ParameterSetName = 'GitHub')]
    [string]$FileNamePattern   = "*.msi",

    [Parameter(ParameterSetName = 'GitHub')]
    [string]$GitHubToken       = "",  # optional; see .DESCRIPTION for details

    [Parameter(Mandatory = $true, ParameterSetName = 'Local')]
    [string]$MsiPath,

    [switch]$PassRebootCode
)

$ErrorActionPreference = 'Stop'

function Get-MsiPropertyValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$PropertyName
    )

    $windowsInstaller = New-Object -ComObject WindowsInstaller.Installer
    $database = $windowsInstaller.GetType().InvokeMember(
        'OpenDatabase',
        'InvokeMethod',
        $null,
        $windowsInstaller,
        @($Path, 0)
    )

    $query = "SELECT `Value` FROM `Property` WHERE `Property`='$PropertyName'"
    $view = $database.GetType().InvokeMember('OpenView', 'InvokeMethod', $null, $database, ($query))
    $view.GetType().InvokeMember('Execute', 'InvokeMethod', $null, $view, $null) | Out-Null
    $record = $view.GetType().InvokeMember('Fetch', 'InvokeMethod', $null, $view, $null)

    if ($record) {
        return $record.GetType().InvokeMember('StringData', 'GetProperty', $null, $record, 1)
    }

    return $null
}

function Normalize-VersionForComparison {
    param(
        [Parameter(Mandatory = $true)]
        [string]$VersionString
    )

    $parsedVersion = [version]($VersionString -replace '^v', '')
    $build = if ($parsedVersion.Build -ge 0) { $parsedVersion.Build } else { 0 }
    return [version]"$($parsedVersion.Major).$($parsedVersion.Minor).$build"
}

function Write-FailureAndExit {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $true)]
        [int]$ExitCode
    )

    [Console]::Error.WriteLine($Message)
    exit $ExitCode
}

# Build shared API headers; add auth only when a token is supplied
$ApiHeaders = @{ "User-Agent" = "Intune-Deploy-Agent" }
if ($GitHubToken) { $ApiHeaders["Authorization"] = "Bearer $GitHubToken" }

try {
    $InstallSourceLabel = $null
    $TempPath = $null
    $HashAsset = $null

    if ($PSCmdlet.ParameterSetName -eq 'Local') {
        $CandidateMsiPath = $MsiPath
        if (-not [System.IO.Path]::IsPathRooted($MsiPath)) {
            $CandidateMsiPath = Join-Path -Path $PSScriptRoot -ChildPath $MsiPath
        }

        $ResolvedMsiPath = (Resolve-Path -Path $CandidateMsiPath -ErrorAction Stop).Path
        $TargetVersion = Get-MsiPropertyValue -Path $ResolvedMsiPath -PropertyName 'ProductVersion'
        if (-not $TargetVersion) {
            Write-Warning "Could not read ProductVersion from MSI metadata. The install will continue without a pre-install version shortcut."
        }
        $InstallSourceLabel = $ResolvedMsiPath
        Write-Host "Using packaged/local MSI source: $ResolvedMsiPath"
    } else {
        # 1. Fetch latest release metadata from public GitHub API (No auth required)
        Write-Host "Querying latest release from public repo: $PublicReleaseRepo..."
        $ApiUrl = "https://api.github.com/repos/$PublicReleaseRepo/releases/latest"

        # User-Agent header is required; GitHub API rejects requests without one
        $ReleaseData = Invoke-RestMethod -Uri $ApiUrl -Method Get -Headers $ApiHeaders

        # 2. Extract the direct browser download URL for the .msi asset
        $MsiAsset = $ReleaseData.assets | Where-Object { $_.name -like $FileNamePattern } | Select-Object -First 1

        if (-not $MsiAsset) {
            Write-FailureAndExit -Message "No installer matching '$FileNamePattern' found in the latest release." -ExitCode 1603
        }

        $DirectDownloadUrl = $MsiAsset.browser_download_url
        $TargetVersion = $ReleaseData.tag_name
        $InstallSourceLabel = $DirectDownloadUrl
        $HashAsset = $ReleaseData.assets | Where-Object { $_.name -eq "$($MsiAsset.name).sha256" } | Select-Object -First 1
        Write-Host "Found version $TargetVersion at: $DirectDownloadUrl"
    }

    if (-not $TargetVersion) {
        $TargetVersion = Split-Path -Path $InstallSourceLabel -Leaf
    }

    # 2a. Compare target version against installed version before installing
    $UninstallPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    $InstalledApp = Get-ItemProperty -Path $UninstallPaths -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -eq $AppName } | Select-Object -First 1
    if ($InstalledApp -and $InstalledApp.DisplayVersion) {
        try {
            # Compare Major.Minor.Build only so GitHub tags like v0.8.2 and MSI/registry versions like 0.8.2.0 compare equally.
            $targetComparableVersion = Normalize-VersionForComparison -VersionString $TargetVersion
            $installedComparableVersion = Normalize-VersionForComparison -VersionString $InstalledApp.DisplayVersion
            if ($installedComparableVersion -eq $targetComparableVersion) {
                Write-Host "Secure Contacts $($InstalledApp.DisplayVersion) is already installed and up to date. No install needed."
                exit 0
            }
        } catch {
            Write-Warning "Version comparison skipped because the target or installed version could not be parsed. Continuing with install."
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

    if ($PSCmdlet.ParameterSetName -eq 'Local') {
        $TempPath = $ResolvedMsiPath
    } else {
        # 3. Download the MSI directly to a local temporary directory
        $TempPath = Join-Path -Path $env:TEMP -ChildPath "SecureContacts_${TargetVersion}.msi"
        Write-Host "Downloading installer to local cache: $TempPath"
        Invoke-WebRequest -Uri $DirectDownloadUrl -OutFile $TempPath -UseBasicParsing

        # 4. Verify file integrity against a companion .sha256 asset if one is published
        if ($HashAsset) {
            $HashResponse = Invoke-WebRequest -Uri $HashAsset.browser_download_url -UseBasicParsing -Headers $ApiHeaders
            if ($HashResponse.Content -is [byte[]]) {
                $HashContent = [System.Text.Encoding]::UTF8.GetString($HashResponse.Content).Trim()
            } else {
                $HashContent = [string]$HashResponse.Content
                $HashContent = $HashContent.Trim()
            }
            $ExpectedHash = ($HashContent -split '\s+')[0].ToUpper()  # handle both bare-hash and 'hash  filename' formats
            $ActualHash   = (Get-FileHash -Path $TempPath -Algorithm SHA256).Hash.ToUpper()
            if ($ActualHash -ne $ExpectedHash) {
                Remove-Item -Path $TempPath -Force
                Write-FailureAndExit -Message "SHA-256 mismatch for $($MsiAsset.name).`nExpected: $ExpectedHash`nGot:      $ActualHash" -ExitCode 1603
            }
            Write-Host "SHA-256 integrity check passed."
        } else {
            Write-Warning "No .sha256 companion asset found for $($MsiAsset.name) - skipping integrity check."
        }

        # 5. Unblock the downloaded file to remove the Zone Identifier (Mark of the Web) added by Invoke-WebRequest;
        #    without this, SmartScreen silently blocks silent MSI installs with exit code 1603 on local runs.
        #    This is a no-op in Intune/SCCM — the management agent does not attach a Zone Identifier.
        Unblock-File -Path $TempPath
    }

    # 6. Execute silent background installation via msiexec with verbose log for diagnostics
    $LogPath = Join-Path -Path $env:TEMP -ChildPath "SecureContacts_${TargetVersion}_install.log"
    Write-Host "Executing silent MSI installation..."
    $Process = Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$TempPath`" /qn /norestart /l*v `"$LogPath`"" -Wait -PassThru -NoNewWindow

    # 7. Clean up downloaded MSI; keep log only on failure for diagnostics
    if ($PSCmdlet.ParameterSetName -eq 'GitHub' -and (Test-Path $TempPath)) {
        Remove-Item -Path $TempPath -Force
    }

    if ($Process.ExitCode -eq 0) {
        Write-Host "SecureContacts $TargetVersion successfully installed/updated (Exit Code: 0)."
        if (Test-Path $LogPath) { Remove-Item -Path $LogPath -Force }
        exit 0
    } elseif ($Process.ExitCode -eq 3010) {
        Write-Host "SecureContacts $TargetVersion successfully installed/updated and requires a reboot (Exit Code: 3010)."
        if (Test-Path $LogPath) { Remove-Item -Path $LogPath -Force }
        if ($PassRebootCode) {
            exit 3010
        }
        exit 0
    } else {
        Write-FailureAndExit -Message "MSI installation failed with exit code $($Process.ExitCode). Review install log: $LogPath" -ExitCode $Process.ExitCode
    }

} catch {
    Write-FailureAndExit -Message "Deployment script failed: $_" -ExitCode 1603  # Generic failure sentinel; actual MSI exit codes are handled above
}