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

function Get-LocalAdmins {

    <#
    .SYNOPSIS
    Retrieve a list of local admins, excluding: Domain Admins, SID objects which are commonly unrecognized user accounts or Azure AD roles/groups
    
    .EXAMPLE
    $localAdmins = Get-LocalAdmins
    #>

    # Retrieve the current local administrators. Uses an ADSI call versus Get-LocalGroupMember due to the command not parsing correctly on Entra-ID joined PCs if Azure AD roles/groups are present
    $localAdmins = ([ADSI]"WinNT://./Administrators").psbase.Invoke('Members') | ForEach-Object {
        ([ADSI]$_).InvokeGet('AdsPath')
    }
    $localAdminList = $localAdmins -replace 'WinNT://', '' -replace '/', '\' | Where-Object { $_ -notlike "S-1*" -and $_ -notlike "*Domain Admins" }
    $localAdminList

}

function Get-UnwantedLocalAdmins {

    <#
    .SYNOPSIS
    Return a list of all local admins except for $RetainAdmin

    .EXAMPLE
    Get-UnwantedLocalAdmins -RetainAdmin cloud_laps
    #>

    param (
        # Enter the name of the user who should retain their admin access to the PC after the remediation executes (ex: a Windows LAPS user account)
        [Parameter(Mandatory = $true)]
        [String]
        $RetainAdmin
    )

    # Create a list of users that should be local admins (built-in admin + $RetainAdmin)
    $desiredLocalAdmins = New-Object System.Collections.Generic.List[System.Object]
    $builtInAdmin = Get-LocalUser | Where-Object { $_.Description -like "Built-in account for administering the computer/domain" }
    $desiredLocalAdmins.Add($builtInAdmin.Name)
    $desiredLocalAdmins.Add($RetainAdmin)

    # Determine if there are additional local admins
    $localAdmins = Get-LocalAdmins
    $unwantedLocalAdmins = $localAdmins | Where-Object { 
        $MemberWithoutDomain = $_.Split('\')[1]
        $desiredLocalAdmins -notcontains $MemberWithoutDomain
    }
    $unwantedLocalAdmins

}

# Local account used for Windows LAPS
$RetainAdmin = "cloud_laps"

# Logging
$outputDirectory = "C:\Windows\System32\LogFiles\EndpointManager"
New-Folder -Path $OutputDirectory
$logFile = "$OutputDirectory\LocalAdminMembership.log"

# Execution
$userExists = (Get-LocalUser).Name -Contains $RetainAdmin
if ( $userExists ) {
    $UnwantedLocalAdmins = Get-UnwantedLocalAdmins -RetainAdmin $RetainAdmin
    if ($UnwantedLocalAdmins.Count -gt 0) {
        Write-Log "[INFO] $retainAdmin is not the only local administrator. Initiating remediation" -LogFile $logFile
        exit 1
    } elseif ($UnwantedLocalAdmins.Count -eq 0) {
        Write-Log "[INFO] $retainAdmin is the only local administrators. No remediation needed" -LogFile $logFile
        exit 0
    }
} else {
    Write-Log "[ERROR] Unable to locate user: $RetainAdmin. Remediation cannot proceed" -LogFile $logFile
}