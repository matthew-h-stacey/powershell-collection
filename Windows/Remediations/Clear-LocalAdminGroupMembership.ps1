# Remove all members of a group except the specified user

$GroupName = "Administrators"
$Except = "BCS365_TEST"

function Write-Log {
    Param ([string]$logstring)
    Add-Content $logFile -Value "$(Get-Date -Format "MM/dd/yyyy HH:mm") $logstring"
}

# Logging
$OutputDirectory = "C:\Windows\System32\LogFiles\EndpointManager"
$LogFile = "$OutputDirectory\Clear-LocalGroupMembership.log" 

# Build a list of users who should not be removed from the group
$ExcludedUsers = New-Object System.Collections.Generic.List[System.Object]
$BuiltInAdmin = Get-LocalUser | ?{$_.Description -like "Built-in account for administering the computer/domain"}
$ExcludedUsers.Add($BuiltInAdmin.Name)
$ExcludedUsers.Add($Except)

# Retrieve the current local administrators
$LocalAdmins = ([ADSI]"WinNT://./Administrators").psbase.Invoke('Members') | % {
 ([ADSI]$_).InvokeGet('AdsPath')
}
$LocalAdmins = $LocalAdmins -replace 'WinNT://', '' -replace '/', '\' | ?{$_ -notlike "S-1*"}

# If the user in the group is not in $ExcludedUsers, remove them from the group
# All output is sent to $LogFile
foreach ($Member in $LocalAdmins) {

    $MemberName = $Member.split("\")[1] 
    if ( $ExcludedUsers -contains $MemberName  ) {
        Write-Log "[INFO] ${GroupName}: Skipped $MemberName"
    }
    if ( $ExcludedUsers -notcontains $MemberName ) {
        try {
            Remove-LocalGroupMember -Group $GroupName -Member $Member -ErrorAction Stop
            Write-Log "[INFO] ${GroupName}: Removed $($Member)" 
        }
        catch {
            Write-Log "[ERROR] ${GroupName}: Failed to remove $($Member.Name) from group. Error: $($_.Exception.Message)" 
        }
    }
}