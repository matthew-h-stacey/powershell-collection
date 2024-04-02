<#
.SYNOPSIS
	Creates a local admin on a workstation

.DESCRIPTION
	This script will check for the presence of a user, add them to Administrators if they are not an admin, or create a new account and them to Administrators

.EXAMPLE
	Create-LocalAdmin -Username cloud_laps -Description "Local account used for Windows LAPS"

.NOTES
	Author: Matt Stacey (BCS)
	Date:   April 1, 2024
#>

param (
    # Parameter help description
    [Parameter(Mandatory=$true)]
    [String]
    $Username,

    # Parameter help description
    [Parameter(Mandatory=$true)]
    [String]
    $Description
)

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
    } else {
        # Path already exists, continue
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

function Get-RandomPassword {

    <#
    .SYNOPSIS
    Generate a random password

    .EXAMPLE
    $password = Get-RandomPassword -Length 32
    $password = (ConvertTo-SecureString (Get-RandomPassword -Length $PasswordLength) -AsPlainText -Force)
    #>

    param (
        [Parameter(Mandatory)]
        [int] $Length
    )
    
    $charSet = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()'.ToCharArray()
    $password = -join (Get-Random -InputObject $charSet -Count 32)
    $password

}

function Get-LocalAdmins {

    <#
    .SYNOPSIS
    Retrieve a list of local admins (not including SID objects which are commonly unrecognized user accounts or Azure AD roles/groups)
    
    .EXAMPLE
    $localAdmins = Get-LocalAdmins
    #>

    # Retrieve the current local administrators. ADSI call versus Get-LocalGroupMember due to the command not parsing correctly on Entra-ID joined PCs if Azure AD roles/groups are present
    $localAdmins = ([ADSI]"WinNT://./Administrators").psbase.Invoke('Members') | ForEach-Object {
        ([ADSI]$_).InvokeGet('AdsPath')
    }
    $localAdminList = $localAdmins -replace 'WinNT://', '' -replace '/', '\' | Where-Object { $_ -notlike "S-1*" }
    $localAdminList

}

function Set-LocalAdmin {

    <#
    .SYNOPSIS
    Check to see if the desired local account exists. If it does, add it to the local administrators group. If not, create the account and add it

    .EXAMPLE
    Set-LocalAdmin -UserName cloud_laps -Description "Windows LAPS-managed user account"
    
    #>

    param(
        # Local account used for Windows LAPS
        [Parameter(Mandatory = $true)]
        [String]
        $Username,

        # Description for user account
        [Parameter(Mandatory = $true)]
        [String]
        $Description
    )

    $userExists = (Get-LocalUser).Name -Contains $Username
    if ($userExists ) {
        # Check if the user is local admin
        $localAdmins = Get-LocalAdmins
        $isLocalAdmin = ($localAdmins | ForEach-Object { $_ -like "*\$Username" }) -contains $true
        if (-not $isLocalAdmin) {
            try {
                Add-LocalGroupMember -Group Administrators -Member $Username
                Write-Log "[INFO] Added $Username to Administrators" -LogFile $logFile
                exit 0
            } catch {
                Write-Log "[ERROR] An error occurred when attempting to add $Username to Administrators. Error: $($_.Exception.Message)" -LogFile $logFile
                exit 1
            }
        } else {
            Write-Log "[INFO] User $Username is already a local admin. Exiting remediation" -LogFile $logFile
            exit 0
        }
    } else {
        $password = (ConvertTo-SecureString (Get-RandomPassword -Length 32) -AsPlainText -Force)
        $params = @{
            Name        = $Username
            Password    = $password
            Description = $Description
        }

        try { 
            New-LocalUser @params
            Add-LocalGroupMember -Group Administrators -Member $Username
            Write-Log "[INFO] Successfully created a new local admin account: $Username" -LogFile $logFile
            exit 0
        } catch {
            Write-Log "[ERROR] An error occurred when attempting to create local administrator: $Username. Error: $($_.Exception.Message)" -LogFile $logFile
            exit 1
        } 
    }

}


# Logging
$outputDirectory = "C:\Windows\System32\LogFiles\GroupPolicy"
New-Folder -Path $outputDirectory
$logFile = "$OutputDirectory\Windows_LAPS_user.log"
Write-Log "[INFO] Starting Create-LocalAdmin. Username: $Username"  -LogFile $logFile

# Execution
Set-LocalAdmin -Username $Username -Description $Description