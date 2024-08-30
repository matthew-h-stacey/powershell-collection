# Account(s) that should retain local admin privileges
$RetainAdmin = @("cloud_laps", "AzureAD\MattStacey", "AzureAD\CJTarbox", "AzureAD\BenLouis")

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

    .PARAMETER RetainAdmin
    Enter the name(s) of the user who should retain their admin access to the PC after the remediation executes (ex: a Windows LAPS user account). For local user accounts only put the name of the user without a prepended hostname. For Entra accounts, format as AzureAD\JohnSmith

    .EXAMPLE
    Get-UnwantedLocalAdmins -RetainAdmin cloud_laps
    Get-UnwantedLocalAdmins -RetainAdmin @("cloud_laps","AzureAD\JohnSmith")
    #>

    param (
        
        [Parameter(Mandatory = $true)]
        [String[]]
        $RetainAdmin
    )

    # Create a list of users that should be local admins (built-in admin + $RetainAdmin)
    $desiredLocalAdmins = New-Object System.Collections.Generic.List[System.Object]
    $builtInAdmin = Get-LocalUser | Where-Object { $_.Description -like "Built-in account for administering the computer/domain" }
    $desiredLocalAdmins.Add($builtInAdmin.Name)
    foreach ( $admin in $RetainAdmin ) {
        $desiredLocalAdmins.Add($admin)
    }

    # Determine if there are additional local admins
    $localAdmins = Get-LocalAdmins
    $unwantedLocalAdmins = $localAdmins | Where-Object { 
        if ( $_ -like "AzureAD\*" ) {
            # Locate Entra ID/Azure AD accounts that are currently local admins but not in the desired admins list
            $desiredLocalAdmins -notcontains $_
        } else {
            # Locate local admins that are not in the desired admins list
            # Split is used to remove the prepended "HOSTNAME\" for easy comparison
            $userWithoutDomain = $_.Split('\')[1]
            $desiredLocalAdmins -notcontains $userWithoutDomain
        }
        
    }
    $unwantedLocalAdmins

}

# Logging
$outputDirectory = "C:\Windows\System32\LogFiles\EndpointManager"
New-Folder -Path $OutputDirectory
$logFile = "$OutputDirectory\LocalAdminMembership.log"

# Execution
$unwantedAdmins = Get-UnwantedLocalAdmins -RetainAdmin $RetainAdmin
if ( $unwantedAdmins.Length -gt 0 ){
    Write-Log "[INFO] Unwanted local admins found on machine. Initiating remediation" -LogFile $logFile
    exit 1
} elseif  ( $unwantedAdmins.Length -eq 0 ){
    Write-Log "[INFO] No unwanted local admins found on machine. No remediation needed" -LogFile $logFile
    exit 0
} else {
    Write-Log "[ERROR] Unable to determine if unwanted admins are present" -LogFile $logFile
}