function Start-DeviceSync {
    <#
    .SYNOPSIS
    Run gpupdate /force and sync the device with Microsoft Intune.

    .EXAMPLE
    Start-DeviceSync
    #>

    function New-Folder {

        <#
    .SYNOPSIS
    Determine if a folder already exists, or create it  if not.

    .EXAMPLE
    New-Folder C:\TempPath
    #>

        param(
            [Parameter(Mandatory = $True)]
            [String]
            $Path
        )
        if (-not (Test-Path -LiteralPath $Path)) {
            try {
                New-Item -Path $Path -ItemType Directory -ErrorAction Stop | Out-Null
            } catch {
                Write-Error -Message "Unable to create directory '$Path'. Error was: $_" -ErrorAction Stop
            }
        }

    }
    function Write-Log {

        <#
    .SYNOPSIS
        Log to a specific file/folder path with timestamps

    .EXAMPLE
        Write-Log -Message "[INFO] Attempting to do the thing" -LogFile C:\Scripts\MyScript.log
        Write-Log -Message "[INFO] Attempting to do the thing" -LogFile $LogFile
    #>

        param (
            [Parameter(Mandatory = $true)]
            [String]
            $Message,

            [Parameter(Mandatory = $true)]
            [String]
            $LogFile
        )

        $timeStampMessage = "$((Get-Date -Format "MM/dd/yyyy HH:mm:ss")) $Message"
        Add-Content -Value $timeStampMessage -Path $LogFile

    }

    function Get-IntuneEnrollmentStatus {
        <#
        .SYNOPOSIS
        This function checks if the device is enrolled in Microsoft Intune by looking for the IntuneManagementExtension.log file
        and Intune-issued certificates.

        .DESCRIPTION
        First, the function checks for the presence of the IntuneManagementExtension.log file in the specified path. If the file
        exists and was modified within the last 7 days, it then checks for certificates issued by Microsoft Intune MDM. If those
        certificates are found and are valid, it indicates that the device is enrolled in Intune.

        .EXAMPLE
        if ( Get-IntuneEnrollmentStatus ) {
            # device is enrolled in Intune
            # do Intune-related tasks here
        }

        #>
        [CmdletBinding()]
        param ()

        $intuneEnrolled = $false

        # Check if the IntuneManagementExtension.log file exists and is recent
        if (Test-Path -Path "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log") {
            $intuneLog = Get-Item -Path "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log"
            $today = Get-Date
            $timespan = New-TimeSpan -Start $intuneLog.LastWriteTime -End $today
            if ($timespan.TotalDays -lt 7) {
                # Check for Intune issued certificates
                $intuneIssuedCerts = Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object { $_.Issuer -like "*Microsoft Intune MDM*" }
                $intuneEnrolled = ($intuneIssuedCerts | ForEach-Object { (New-TimeSpan -Start $today -End $_.NotAfter).TotalDays -gt 1 }) -contains $true
            }
        }

        return $intuneEnrolled
    }

    # Logging setup
    $logFolderPath = "c:\ProgramData\NinjaRMMAgent\toolboxlogs"
    $logFile = "$logFolderPath\DeviceSync.log"
    New-Folder $logFolderPath

    #
    gpupdate /force | Out-Null
    Write-Log -Message "[INFO] Executed 'gpupdate /force'" -LogFile $LogFile

    # Additional tasks for Intune-enrolled devices
    if ( Get-IntuneEnrollmentStatus ) {
        # Restart the Intune Management Extension service
        if ( Get-Service -Name IntuneManagementExtension -ErrorAction SilentlyContinue ) {
            try {
                Restart-Service -Name IntuneManagementExtension -ErrorAction Stop
                Write-Log -Message "[INFO] Restarted IntuneManagementExtension service" -LogFile $LogFile
            } catch {
                Write-Log -Message "[ERROR] Failed to restart IntuneManagementExtension service. Error: $_" -LogFile $LogFile
            }
        } else {
            Write-Log -Message "[WARNING] IntuneManagementExtension service not found" -LogFile $LogFile
        }

        # start device enroller process to sync information to Intune
        $enrollmentID = Get-ScheduledTask | Where-Object { $_.TaskPath -like "*Microsoft*Windows*EnterpriseMgmt\*" } | Select-Object -ExpandProperty TaskPath -Unique | Where-Object { $_ -like "*-*-*" } | Split-Path -Leaf
        if ( $enrollmentID ) {
            Start-Process -FilePath "C:\Windows\system32\deviceenroller.exe" -Wait -ArgumentList "/o $enrollmentID /c /b"
        }
        Write-Log -Message "[INFO] Initiated deviceenroller update" -LogFile $LogFile

        # alternative approach to sync information to Intune, execute the PushLaunch task
        $pushLaunchTask = Get-ScheduledTask | Where-Object { $_.TaskName -eq 'PushLaunch' }
        if ( $pushLaunchTask ) {
            $pushLaunchTask | Start-ScheduledTask
            Write-Log -Message "[INFO] Started PushLaunch scheduled task" -LogFile $LogFile
        }
    }

}

Start-DeviceSync