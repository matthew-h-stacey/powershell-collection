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
    Write-Log -Message "[INFO] Attempting to do the thing" -LogFile $logFile 
    #>
    
    param (
        [Parameter(Mandatory = $true)]
        [String]
        $Message,

        [Parameter(Mandatory = $true)]
        [String]
        $logFile
    )

    $timeStampMessage = "$((Get-Date -Format "MM/dd/yyyy HH:mm:ss")) $Message"
    Add-Content -Value $timeStampMessage -Path $logFile

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

function Test-LocalAdmin {
    
    <#
    .SYNOPSIS
    Locate a local administrator account. Returns a hash table that shows whether or not the user is present and if it is a local admin

    .EXAMPLE
    Test-LocalAdmin -Username cloud_laps
    #>

    param (
        # The username of the local administrator account
        [Parameter(Mandatory = $true)]
        [String]
        $Username
    )

    # Object to be returned with properties about the user account
    $userAccount = @{}

    # First check to see if the local user exists. Proceed if they are, exit and trigger remediation if not
    $userExists = (Get-LocalUser).Name -Contains $Username

    if ($userExists) {
        $userAccount.isPresent = $True
        $localAdmins = Get-LocalAdmins    
        # Check if the user is local admin, store result as boolean
        $isLocalAdmin = ($localAdmins | ForEach-Object { $_ -like "*\$Username" }) -contains $true
        if ( $isLocalAdmin ) {
            $userAccount.isLocalAdmin = $True
        } else {
            $userAccount.isLocalAdmin = $False
        }
    } else {
        $userAccount.isPresent = $False   
        $userAccount.isLocalAdmin = $False
    }

    $userAccount

}

# Local account used for Windows LAPS
$Username = "cloud_laps"

# Logging
$outputDirectory = "C:\Windows\System32\LogFiles\EndpointManager"
New-Folder -Path $outputDirectory
$logFile = "$outputDirectory\LocalAdminUser.log"

# Execution
$user = Test-LocalAdmin -Username $Username

# Trigger remediation (exit 1) if the user doesn't exist, or exists but is not a local administrator. Otherwise, no remediation is required
if ( $user.IsPresent -eq $False) {
    Write-Log -Message "[INFO] User $Username is not present. Initiating remediation" -LogFile $logFile
    exit 1
}
if ( $user.isLocalAdmin -eq $False) {
    Write-Log -Message "[INFO] User $Username is not a local admin. Initiating remediation" -LogFile $logFile
    exit 1
} else {
    Write-Log "[INFO] User $Username is already a local admin. No remediation needed" -LogFile $logFile
    exit 0
}