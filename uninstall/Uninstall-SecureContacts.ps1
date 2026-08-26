[CmdletBinding()]
param(
    [ValidateSet('ApplicationOnly', 'CompletePurge')]
    [string]$Mode = 'ApplicationOnly',
    [switch]$WhatIf,
    [string]$LogPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:AppNames = @('SecureContacts', 'Secure Contacts')
$script:MainProcessName = 'SecureContacts.exe'
$script:MonitorProcessName = 'TeamsCallMonitor.exe'
$script:DataDirectoryName = 'SecureContacts\Data'
$script:PolicyKey = 'HKLM:\SOFTWARE\Policies\ProvectusSoftwareGmbH\SecureContactsDesktop'
$script:SuccessfulMsiExitCodes = @(0, 1641, 3010)
$script:RunId = [guid]::NewGuid().ToString()
$script:LogWriter = $null

function Write-Event {
    param(
        [ValidateSet('Info', 'Warning', 'Error')]
        [string]$Level,
        [string]$Action,
        [string]$Result,
        [string]$Reason,
        [string]$Target = '',
        [hashtable]$Data = @{}
    )

    $event = [ordered]@{
        timestamp = [DateTime]::UtcNow.ToString('o')
        runId = $script:RunId
        mode = $Mode
        whatIf = [bool]$WhatIf
        level = $Level
        action = $Action
        result = $Result
        reason = $Reason
        target = $Target
    }

    foreach ($key in $Data.Keys) {
        $event[$key] = $Data[$key]
    }

    $line = $event | ConvertTo-Json -Compress -Depth 6
    Write-Output $line
    if ($script:LogWriter) {
        $script:LogWriter.WriteLine($line)
        $script:LogWriter.Flush()
    }
}

function Stop-WithError {
    param(
        [int]$Code,
        [string]$Action,
        [string]$Reason,
        [string]$Target = ''
    )

    Write-Event -Level Error -Action $Action -Result Failed -Reason $Reason -Target $Target
    exit $Code
}

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-OptionalPropertyValue {
    param(
        [object]$InputObject,
        [string]$PropertyName
    )

    $property = $InputObject.PSObject.Properties[$PropertyName]
    if ($property) {
        return $property.Value
    }
    return $null
}

function Get-UninstallEntries {
    $paths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )

    @(
        Get-ItemProperty -Path $paths -ErrorAction SilentlyContinue |
            Where-Object {
                $displayName = $_.PSObject.Properties['DisplayName']
                $displayName -and [string]$displayName.Value -in $script:AppNames
            }
    )
}

function Get-RegisteredApplication {
    $entries = @(Get-UninstallEntries)
    if ($entries.Count -gt 1) {
        $productCodes = @($entries | ForEach-Object { [string]$_.PSChildName } | Sort-Object -Unique)
        if ($productCodes.Count -gt 1) {
            Stop-WithError 80 'uninstall_preflight' 'multiple_installations_found' ($productCodes -join ',')
        }
    }

    if ($entries.Count -eq 0) {
        Write-Event -Level Info -Action uninstall_discovery -Result AlreadyAbsent -Reason not_registered | Out-Host
        return $null
    }

    $entry = $entries | Select-Object -First 1
    $productCode = [string]$entry.PSChildName
    $installLocation = [string](Get-OptionalPropertyValue -InputObject $entry -PropertyName 'InstallLocation')
    if ([string]::IsNullOrWhiteSpace($installLocation)) {
        $uninstallString = [string](Get-OptionalPropertyValue -InputObject $entry -PropertyName 'UninstallString')
        if ($uninstallString -match '^\s*"([^"]+\.exe)"' -or $uninstallString -match '^\s*(\S+\.exe)') {
            $installLocation = Split-Path -Parent $matches[1]
        }
    }

    if ([string]::IsNullOrWhiteSpace($installLocation)) {
        if ($productCode -notmatch '^\{[0-9A-Fa-f-]+\}$') {
            Stop-WithError 80 'uninstall_preflight' 'install_location_missing' ([string]$entry.PSPath)
        }
        Write-Event -Level Warning -Action uninstall_discovery -Result Validated -Reason msi_install_location_unavailable -Target ([string]$entry.PSPath) -Data @{ productCode = $productCode } | Out-Host
    } else {
        $installLocation = [IO.Path]::GetFullPath($installLocation.TrimEnd('\'))
        Write-Event -Level Info -Action uninstall_discovery -Result Validated -Reason exact_application_match -Target $installLocation -Data @{
            productCode = $productCode
            displayVersion = [string](Get-OptionalPropertyValue -InputObject $entry -PropertyName 'DisplayVersion')
        } | Out-Host
    }
    return [pscustomobject]@{
        Entry = $entry
        InstallLocation = $installLocation
        ProductCode = $productCode
    }
}

function Test-SafeInstallPath {
    param([string]$InstallLocation)

    if ([string]::IsNullOrWhiteSpace($InstallLocation) -or $InstallLocation -eq [IO.Path]::GetPathRoot($InstallLocation)) {
        return $false
    }

    $item = Get-Item -LiteralPath $InstallLocation -Force -ErrorAction SilentlyContinue
    if (-not $item) {
        return $true
    }
    return (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0)
}

function Get-VerifiedProcesses {
    param([string]$InstallLocation)

    $names = @($script:MainProcessName, $script:MonitorProcessName)
    $processes = @(Get-CimInstance Win32_Process -Filter "Name = '$($script:MainProcessName)' OR Name = '$($script:MonitorProcessName)'" -ErrorAction SilentlyContinue)
    $verified = @()
    foreach ($process in $processes) {
        if ($process.Name -notin $names -or [string]::IsNullOrWhiteSpace($process.ExecutablePath)) {
            continue
        }

        $processPath = [IO.Path]::GetFullPath($process.ExecutablePath)
        $underInstall = $processPath.StartsWith($InstallLocation.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)
        if ($underInstall) {
            $verified += [pscustomobject]@{
                Id = [int]$process.ProcessId
                Name = $process.Name
                Path = $processPath
            }
        }
    }
    return $verified
}

function Stop-VerifiedProcesses {
    param([string]$InstallLocation)

    $processes = @(Get-VerifiedProcesses -InstallLocation $InstallLocation)
    if ($processes.Count -eq 0) {
        Write-Event -Level Info -Action process_termination -Result AlreadyAbsent -Reason no_verified_application_processes
        return
    }

    if ($WhatIf) {
        foreach ($process in $processes) {
            Write-Event -Level Info -Action process_termination -Result Planned -Reason verified_process -Target $process.Path -Data @{ processId = $process.Id; processName = $process.Name }
        }
        return
    }

    foreach ($processName in @($script:MainProcessName, $script:MonitorProcessName)) {
        $currentProcesses = @(Get-VerifiedProcesses -InstallLocation $InstallLocation | Where-Object Name -eq $processName)
        foreach ($process in $currentProcesses) {
            Write-Event -Level Info -Action process_termination -Result Planned -Reason verified_process -Target $process.Path -Data @{ processId = $process.Id; processName = $process.Name }
            try {
                Stop-Process -Id $process.Id -Force -ErrorAction Stop
            } catch {
                $stillRunning = @(Get-VerifiedProcesses -InstallLocation $InstallLocation | Where-Object { $_.Id -eq $process.Id })
                if ($stillRunning.Count -gt 0) {
                    throw
                }
            }
        }
    }

    $deadline = [DateTime]::UtcNow.AddSeconds(10)
    do {
        Start-Sleep -Milliseconds 250
        $remaining = @(Get-VerifiedProcesses -InstallLocation $InstallLocation)
    } while ($remaining.Count -gt 0 -and [DateTime]::UtcNow -lt $deadline)

    if ($remaining.Count -gt 0) {
        Stop-WithError 81 'process_termination' 'verified_processes_survived' (($remaining | ForEach-Object { "$($_.Name):$($_.Id)" }) -join ',')
    }
    Write-Event -Level Info -Action process_termination -Result Verified -Reason all_verified_processes_absent
}

function Get-EligibleProfiles {
    $profiles = @(Get-CimInstance Win32_UserProfile -ErrorAction Stop | Where-Object {
        -not $_.Special -and -not [string]::IsNullOrWhiteSpace($_.LocalPath)
    })
    $eligible = @()
    foreach ($profile in $profiles) {
        $profilePath = [IO.Path]::GetFullPath($profile.LocalPath.TrimEnd('\'))
        if ($profilePath -match '(?i)^[A-Z]:\\Users\\(?:Default|Default User|Public|All Users)$') {
            continue
        }
        if ($profilePath -notmatch '(?i)^[A-Z]:\\Users\\[^\\]+$') {
            Stop-WithError 80 'profile_preflight' 'unsafe_profile_path' $profilePath
        }
        $item = Get-Item -LiteralPath $profilePath -Force -ErrorAction Stop
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            Stop-WithError 80 'profile_preflight' 'profile_is_reparse_point' $profilePath
        }
        $eligible += [pscustomobject]@{ LocalPath = $profilePath; Sid = $profile.SID }
    }
    return $eligible
}

function Get-DataTarget {
    param([string]$ProfilePath)

    $profileRoot = [IO.Path]::GetFullPath($ProfilePath.TrimEnd('\'))
    $target = [IO.Path]::GetFullPath((Join-Path $profileRoot "AppData\Local\$($script:DataDirectoryName)"))
    $prefix = $profileRoot.TrimEnd('\') + '\'
    if (-not $target.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
        Stop-WithError 80 'data_preflight' 'target_outside_profile' $target
    }

    $current = $profileRoot
    foreach ($component in $target.Substring($profileRoot.Length).TrimStart('\').Split('\')) {
        $current = Join-Path $current $component
        $item = Get-Item -LiteralPath $current -Force -ErrorAction SilentlyContinue
        if ($item -and (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) {
            Stop-WithError 80 'data_preflight' 'target_contains_reparse_point' $current
        }
    }
    return $target
}

function Remove-DataForProfiles {
    $profiles = @(Get-EligibleProfiles)
    foreach ($profile in $profiles) {
        $target = Get-DataTarget -ProfilePath $profile.LocalPath
        $item = Get-Item -LiteralPath $target -Force -ErrorAction SilentlyContinue
        if (-not $item) {
            Write-Event -Level Info -Action data_removal -Result AlreadyAbsent -Reason target_not_present -Target $target -Data @{ userSid = $profile.Sid }
            continue
        }

        Write-Event -Level Info -Action data_removal -Result Planned -Reason verified_data_target -Target $target -Data @{ userSid = $profile.Sid }
        if (-not $WhatIf) {
            Remove-Item -LiteralPath $target -Recurse -Force -ErrorAction Stop
            if (Test-Path -LiteralPath $target) {
                Stop-WithError 82 'data_removal' 'target_still_present' $target
            }
            Write-Event -Level Info -Action data_removal -Result Removed -Reason target_absent_after_removal -Target $target -Data @{ userSid = $profile.Sid }
        }
    }
}

function Invoke-RegisteredUninstaller {
    param($Application)

    $entry = $Application.Entry
    $productCode = $Application.ProductCode
    if ($productCode -match '^\{[0-9A-Fa-f-]+\}$') {
        $filePath = Join-Path $env:SystemRoot 'System32\msiexec.exe'
        $arguments = @('/x', $productCode, '/qn', '/norestart')
    } else {
        $command = [string](Get-OptionalPropertyValue -InputObject $entry -PropertyName 'QuietUninstallString')
        if ([string]::IsNullOrWhiteSpace($command)) { $command = [string](Get-OptionalPropertyValue -InputObject $entry -PropertyName 'UninstallString') }
        if ($command -notmatch '^\s*"([^"]+)"\s*(.*)$') {
            Stop-WithError 80 'uninstall_preflight' 'uninstaller_command_not_supported' $command
        }
        $filePath = $matches[1]
        $arguments = $matches[2]
    }

    Write-Event -Level Info -Action application_uninstall -Result Planned -Reason registered_uninstaller -Target $filePath -Data @{ arguments = ($arguments -join ' ') }
    if ($WhatIf) { return }

    $process = Start-Process -FilePath $filePath -ArgumentList $arguments -Wait -PassThru -ErrorAction Stop
    if ($productCode -match '^\{[0-9A-Fa-f-]+\}$' -and $process.ExitCode -notin $script:SuccessfulMsiExitCodes) {
        Stop-WithError 82 'application_uninstall' 'msi_uninstall_failed' ([string]$process.ExitCode)
    }
    if ($productCode -notmatch '^\{[0-9A-Fa-f-]+\}$' -and $process.ExitCode -ne 0) {
        Stop-WithError 82 'application_uninstall' 'uninstaller_failed' ([string]$process.ExitCode)
    }
    Write-Event -Level Info -Action application_uninstall -Result Completed -Reason accepted_exit_code -Data @{ exitCode = $process.ExitCode }
}

function Verify-ApplicationAbsent {
    param($Application)

    if ($WhatIf) { return }
    $remaining = @(Get-UninstallEntries)
    if ($remaining.Count -gt 0) {
        Stop-WithError 83 'uninstall_verification' 'application_still_registered' $Application.ProductCode
    }
    if ([string]::IsNullOrWhiteSpace($Application.InstallLocation)) {
        Write-Event -Level Info -Action uninstall_verification -Result Verified -Reason application_unregistered_install_location_unavailable
    } elseif ((Test-Path -LiteralPath (Join-Path $Application.InstallLocation $script:MainProcessName)) -or (Test-Path -LiteralPath $Application.InstallLocation)) {
        Write-Event -Level Warning -Action uninstall_verification -Result Residual -Reason install_directory_or_files_remain -Target $Application.InstallLocation
    } else {
        Write-Event -Level Info -Action uninstall_verification -Result Verified -Reason application_unregistered_and_directory_absent
    }
}

try {
    if (-not (Test-IsAdministrator)) {
        Stop-WithError 77 'runtime_preflight' 'administrator_required'
    }

    if ($LogPath) {
        $logDirectory = Split-Path -Parent ([IO.Path]::GetFullPath($LogPath))
        New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
        $script:LogWriter = New-Object IO.StreamWriter($LogPath, $true, (New-Object Text.UTF8Encoding($false)))
    }

    Write-Event -Level Info -Action uninstall -Result Started -Reason operation_started
    $application = Get-RegisteredApplication
    if ($application) {
        if (-not [string]::IsNullOrWhiteSpace($application.InstallLocation) -and -not (Test-SafeInstallPath -InstallLocation $application.InstallLocation)) {
            Stop-WithError 80 'uninstall_preflight' 'unsafe_install_path' $application.InstallLocation
        }
        if (-not [string]::IsNullOrWhiteSpace($application.InstallLocation)) {
            Stop-VerifiedProcesses -InstallLocation $application.InstallLocation
        } else {
            Write-Event -Level Warning -Action process_termination -Result Skipped -Reason install_location_unavailable
        }
        Invoke-RegisteredUninstaller -Application $application
        Verify-ApplicationAbsent -Application $application
    }

    if ($Mode -eq 'CompletePurge') {
        Remove-DataForProfiles
    } else {
        Write-Event -Level Info -Action data_removal -Result Preserved -Reason application_only_mode
    }

    if (-not $WhatIf -and (Test-Path -LiteralPath $script:PolicyKey)) {
        Write-Event -Level Info -Action policy_verification -Result Preserved -Reason managed_policy_untouched -Target $script:PolicyKey
    }
    Write-Event -Level Info -Action uninstall -Result Success -Reason operation_complete
    exit 0
} catch {
    Write-Event -Level Error -Action uninstall -Result Failed -Reason $_.Exception.Message
    exit 82
} finally {
    if ($script:LogWriter) {
        $script:LogWriter.Dispose()
    }
}
