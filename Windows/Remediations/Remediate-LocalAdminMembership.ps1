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

    # Retrieve the current local administrators. ADSI call versus Get-LocalGroupMember due to the command not parsing correctly on Entra-ID joined PCs if Azure AD roles/groups are present
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

function Update-LocalAdminMembership {
    param (
        [Parameter(Mandatory = $true)]
        [String[]]
        $RetainAdmin
    )

    # Build a list of users who should not be removed from local admins
    $excludedUsers = New-Object System.Collections.Generic.List[System.Object]
    $builtInAdmin = Get-LocalUser | Where-Object { $_.Description -like "Built-in account for administering the computer/domain" }
    $excludedUsers.Add($builtInAdmin.Name)
    foreach ( $admin in $RetainAdmin ) {
        $excludedUsers.Add($admin)
    }

    # If the user in the group is not in $excludedUsers, remove them from the group
    # All output is sent to $LogFile
    $unwantedLocalAdmins = Get-UnwantedLocalAdmins -RetainAdmin $RetainAdmin
    foreach ($admin in $unwantedLocalAdmins) {
        try {
            Remove-LocalGroupMember -Group Administrators -Member $admin -ErrorAction Stop
            Write-Log "[INFO] Administrators: Removed $($admin)" -LogFile $logFile
        } catch {
            Write-Log "[ERROR] Administrators: Failed to remove $($admin.Name) from group. Error: $($_.Exception.Message)" -LogFile $logFile
        }
    }

}

# Local account used for Windows LAPS
$RetainAdmin = @("cloud_laps", "AzureAD\MattStacey", "AzureAD\CJTarbox", "AzureAD\BenLouis")

# Logging
$outputDirectory = "C:\Windows\System32\LogFiles\EndpointManager"
$logFile = "$OutputDirectory\LocalAdminMembership.log" 

# Execution
Update-LocalAdminMembership -RetainAdmin $RetainAdmin