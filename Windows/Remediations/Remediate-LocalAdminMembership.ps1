# Local account used for Windows LAPS
$RetainAdmin = "cloud_laps"

# Logging
$OutputDirectory = "C:\Windows\System32\LogFiles\EndpointManager"
$LogFile = "$OutputDirectory\LocalAdminMembership.log" 
Write-Log "[INFO] Starting Remediate-LocalAdminMembership. Retain username: $RetainAdmin"

function Write-Log {
    Param ([string]$logstring)
    Add-Content $logFile -Value "$(Get-Date -Format "MM/dd/yyyy HH:mm:ss") $logstring"
}

function Remediate-LocalAdminMembership {
    # Parameter help description
    param (
        [Parameter(Mandatory = $true)]
        [String]
        $RetainAdmin
    )

    # Build a list of users who should not be removed from the group
    $ExcludedUsers = New-Object System.Collections.Generic.List[System.Object]
    $BuiltInAdmin = Get-LocalUser | Where-Object { $_.Description -like "Built-in account for administering the computer/domain" }
    $ExcludedUsers.Add($BuiltInAdmin.Name)
    $ExcludedUsers.Add($RetainAdmin)

    # Retrieve the current local administrators
    $LocalAdmins = ([ADSI]"WinNT://./Administrators").psbase.Invoke('Members') | ForEach-Object {
 ([ADSI]$_).InvokeGet('AdsPath')
    }
    $LocalAdmins = $LocalAdmins -replace 'WinNT://', '' -replace '/', '\' | Where-Object { $_ -notlike "S-1*" }

    # If the user in the group is not in $ExcludedUsers, remove them from the group
    # All output is sent to $LogFile
    foreach ($Member in $LocalAdmins) {

        $MemberName = $Member.split("\")[1] 
        if ( $ExcludedUsers -contains $MemberName  ) {
            Write-Log "[INFO] Administrators: Skipped $MemberName"
        }
        if ( $ExcludedUsers -notcontains $MemberName ) {
            try {
                Remove-LocalGroupMember -Group Administrators -Member $Member -ErrorAction Stop
                Write-Log "[INFO] Administrators: Removed $($Member)" 
            }
            catch {
                Write-Log "[ERROR] Administrators: Failed to remove $($Member.Name) from group. Error: $($_.Exception.Message)" 
            }
        }
    }

}

# Execution
try {
    Remediate-LocalAdminMembership -RetainAdmin $RetainAdmin
    Write-Output "[INFO] Remediation executed successfully. Check log file for output ($LogFile)"
}
catch {
    Write-Output "[ERROR] Failed to execute remediation. Error: $($_.Exception.Message)"
}