function Clear-PrintSpoolerFiles {
    <#
    .SYNOPSIS
    Clear the print spooler files and restart the print spooler service.

    .EXAMPLE
    Clear-PrintSpoolerFiles
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

    # Logging setup
    $logFolderPath = "c:\ProgramData\NinjaRMMAgent\toolboxlogs"
    $logFile = "$logFolderPath\ClearPrintSpooler.log"
    New-Folder $logFolderPath

    # Stop the spooler service
    $spoolerSvc = Get-Service -Name spooler
    if ( $spoolerSvc.Status -eq 'Running' ) {
        try {
            Stop-Service -Name spooler -Force
            Write-Log -Message "[INFO] Stopped print spooler service" -LogFile $LogFile
        } catch {
            Write-Log -Message "[ERROR] Unable to stop the print spooler service. Error was: $_" -LogFile $LogFile
            exit 1
        }
    }
    # Remove all files in the print spooler directory
    $spooledFiles = Get-ChildItem -Path $env:windir\System32\spool\PRINTERS\
    if ( $spooledFiles.Count -gt 0 ) {
        try {
            Remove-Item -Path $env:windir\System32\spool\PRINTERS\*.* -Force -Recurse
            $filesRemoved = $spooledFiles.Count - ((Get-ChildItem -Path $env:windir\System32\spool\PRINTERS\).Count)
            Write-Log -Message "[INFO] Cleared print spooler files (quantity: $filesRemoved)" -LogFile $LogFile
        } catch {
            Write-Log -Message "[ERROR] Unable to clear print spooler files. Error was: $_" -LogFile $LogFile
            exit 1
        }
    } else {
        Write-Log -Message "[INFO] No print spooler files found to clear" -LogFile $LogFile
    }
    # Start the spooler service
    Start-Service -Name spooler
    Write-Log -Message "[INFO] Started print spooler service" -LogFile $LogFile

}