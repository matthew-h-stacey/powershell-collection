<#
.PARAMETER CurrentGroupDisplayName
The display name of the current Entra security group that is being copied

.PARAMETER NewGroupDisplayName
The display name of the new privileged Entra securrity group to create

.SYNOPSIS
This script copies an Entra security group and makes a new privileged
security group with the same members and include/excludes it from the
same Conditional Access Policies

.DESCRIPTION
Order of operations as follows:
1. Search for the existing and new group
2. If the new group does not exist, create it
3. Mirror group membership from current to new group
4. Mirror Conditional Access policy inclusion/exclusion from the current to new group 
#>

param (
    [Parameter(Mandatory = $true)]
    [string]
    $CurrentGroupDisplayName,

    [Parameter(Mandatory = $true)]
    [string]
    $NewGroupDisplayName
)

$ErrorActionPreference = "Stop"

# The groups referenced in this script
$groups = Get-MgGroup -Filter "DisplayName in ('$CurrentGroupDisplayName', '$NewGroupDisplayName')" -ExpandProperty Members
$currentGroup = $groups | Where-Object { $_.DisplayName -eq $CurrentGroupDisplayName }
$newGroup = $groups | Where-Object { $_.DisplayName -eq $NewGroupDisplayName }

# Verify the current group can be located
if ( -not $currentGroup ) {
    return "[WARNING] No group found with display name: $CurrentGroupDisplayName. Please confirm name provided is correct and try again."
}
if ( $currentGroup -is [array] -and $currentGroup.Count -gt 1) {
    return "[WARNING] Multiple groups found with this display name. Please rename the duplicate group and try again."
}

# Create the new privileged group if it does not exist
if ( -not $newGroup ) {
    $groupParams = @{
        DisplayName        = $NewGroupDisplayName
        MailEnabled        = $false
        MailNickname       = $NewGroupDisplayName.Replace(" ", "")
        SecurityEnabled    = $true
        IsAssignableToRole = $true
    }
    try {
        $newGroup = New-MgGroup @groupParams
        Write-Output "[INFO] Created new priviledged security group: $NewGroupDisplayName"
        if (-not $newGroup -or -not $newGroup.Id) {
            return "[ERROR] Failed to create new priviledged group. Exiting script"
        }
    } catch {
        return "[ERROR] Failed to create new priviledged group. Error: $($_.Exception.Message)"
    }
}

# Add all the members from the original group to the new one. If the user is already a member, do nothing
foreach ( $member in $currentGroup.Members ) {
    if ( $newGroup.Members.Id -notcontains $member ) {
        $params = @{
            "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$($member.Id)"
        }
        try {
            New-MgGroupMemberByRef -GroupId $newGroup.Id -BodyParameter $params
        } catch {
            if ($_.Exception.Message -match "One or more added object references already exist") {
                # User is already a member, suppress error
            } else {
                Write-Output "[ERROR] Failed to add member $($member.Id) to $NewGroupDisplayName. Error: $($_.Exception.Message)"
            }
        }
    }
}

$cas = Get-MgIdentityConditionalAccessPolicy
foreach ( $ca in $cas ) {
    # Find CAs the selected group is included in
    # If the new group is not already included in the CA, include it
    if ( $ca.Conditions.users.IncludeGroups -contains $currentGroup.Id) {
        Write-Output "$($currentGroup.DisplayName) is included in CA: $($ca.DisplayName)"
        if ( $ca.Conditions.users.IncludeGroups -notContains $newGroup.Id) {
            $params = @{
                Conditions = @{
                    Users = @{
                        IncludeGroups = $ca.Conditions.Users.IncludeGroups + @($newGroup.Id)
                        ExcludeGroups = $ca.Conditions.Users.ExcludeGroups
                    }
                }
            }
            try {
                Update-MgIdentityConditionalAccessPolicy -ConditionalAccessPolicyId $ca.Id -Conditions $params.Conditions
                Write-Output "Included $($newGroup.DisplayName) in CA policy: $($ca.DisplayName)"
            } catch {
                Write-Output "[ERROR] Failed to include $($newGroup.DisplayName) in CA policy: $($ca.DisplayName). Error: $($_.Exception.Message)"
            }
        }
    }
    # Find CAs the selected group is excluded from
    # If the new group is not already excluded from the CA, exclude it
    if ( $ca.Conditions.users.ExcludeGroups -contains $currentGroup.Id) {
        Write-Output "$($currentGroup.DisplayName) is excluded from CA: $($ca.DisplayName)"
        if ( $ca.Conditions.users.ExcludeGroups -notContains $newGroup.Id) {
            $params = @{
                Conditions = @{
                    Users = @{
                        IncludeGroups = $ca.Conditions.Users.IncludeGroups
                        ExcludeGroups = $ca.Conditions.Users.ExcludeGroups + @($newGroup.Id)
                    }
                }
            }
            try {
                Update-MgIdentityConditionalAccessPolicy -ConditionalAccessPolicyId $ca.Id -Conditions $params.Conditions
                Write-Output "Excluded $($newGroup.DisplayName) from CA policy: $($ca.DisplayName)"
            } catch {
                Write-Output "[ERROR] Failed to exclude $($newGroup.DisplayName) from CA policy: $($ca.DisplayName). Error: $($_.Exception.Message)"
            }
        }
    }
}