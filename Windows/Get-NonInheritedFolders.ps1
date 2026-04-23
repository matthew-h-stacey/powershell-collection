function Get-NonInheritedFolders {
    <#
    .DESCRIPTION
    Recursively checks a specified folder path for any directories with inheritance disabled and outputs the results to a specified output directory/file. Also logs any errors encountered during processing.

    .PARAMETER Path
    The root folder path to check for non-inherited permissions.

    .PARAMETER OutputDirectory
    The folder path where the output file (inheritancedisabled.txt) and error log (errors.txt) will be saved.

    .EXAMPLE
    Get-NonInheritedFolders -Path 'C:\MyFolder' -OutputDirectory 'C:\Output'
    This command will check the 'C:\MyFolder' directory and all its subdirectories for non-inherited permissions and save the results to 'C:\Output\inheritancedisabled.txt' and any errors to 'C:\Output\errors.txt'.
    #>

    param (
        # Folder to check
        [Parameter(Mandatory = $true)]
        [String]
        $Path,

        # Output folder/file for results
        [Parameter(Mandatory = $true)]
        [String]
        $OutputDirectory
    )

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

    # Output file setup
    $null = New-Item -Path $OutputDirectory -ItemType Directory -Force -ErrorAction SilentlyContinue
    $logFile = "$OutputDirectory\inheritancedisabled.txt"
    $errorLog = "$OutputDirectory\errors.txt"


    $dirs = Get-ChildItem -Path $Path -Directory -Recurse -ErrorAction SilentlyContinue -ErrorVariable +gciFailures
    foreach ( $gciFailure in $gciFailures ) {
        $errorMessage = "Unable to access directory: $($gciFailure.TargetObject). Error: $($gciFailure.Exception.Message)"
        Write-Output $errorMessage
        Write-Log -Message $errorMessage -LogFile $errorLog
    }

    foreach ( $dir in $dirs ) {
        try {
            $acl = Get-Acl $dir.FullName -ErrorAction Stop
            if ( $acl.AreAccessRulesProtected -eq $true ) {
                # Inheritance disabled
                $logMessage = "Inheritance disabled on: $($dir.FullName)"
                Write-Output $logMessage
                Write-Log -Message $logMessage -LogFile $logFile
            } else {
                # Inheritance enabled
            }
        } catch {
            $errorMessage = "Unable to process ACL on directory: $($dir.FullName). Error: $($_.Exception.Message)"
            Write-Output $errorMessage
            Write-Log -Message $errorMessage -LogFile $errorLog
        }
    }

}