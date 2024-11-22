function Remove-UnifiedGroupOwnership {

    param(
        [Parameter(Mandatory = $True)]
        [String]$UserPrincipalName
    )

    function Get-EntraGlobalAdmin {

        <#
        .SYNOPSIS
        This function returns a UPN for a global administrator that can be used as a replacement owner if the user does not have a manager
        #>

        # Get Global Admin role
        $uri = "https://graph.microsoft.com/beta/directoryRoles?filter=DisplayName+eq+'Global+Administrator'"
        $globalAdminRoleRequest = Invoke-MgGraphRequest -Method GET -Uri $uri
        $globalAdminRole = $globalAdminRoleRequest.Value
        
        # Retrieve users assigned Global Admin role
        $filter = "roleDefinitionId eq " + "'" + $globalAdminRole.Id + "'"
        $globalAdmins = [array](Get-MgRoleManagementDirectoryRoleAssignment -Filter $filter -ExpandProperty "principal")
        
        # Retrieve first Global Admin in the array
        $globalAdmin = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/users/$($globalAdmins[0].Principal.Id)"

        return $globalAdmin

    }

    $assignedOwnership = New-Object System.Collections.Generic.List[System.Object]
    $removedGroups = New-Object System.Collections.Generic.List[System.Object]
        
    # Retrieve user object
    $user = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/users/$UserPrincipalName"

    if ( $user ) {
        # Retrieve all groups
        $groupsResponse = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/groups?filter=groupTypes/any(c:c+eq+'Unified')"
        $groups = $groupsResponse.Value

        try {
            $manager = Get-MgUser -UserId (Get-MgUserManager -UserId $UserPrincipalName -ErrorAction Stop).Id 
        } catch {
            # User does not have a manager
        }        
        if (-not $manager) { 
            $newOwner = Get-EntraGlobalAdmin
        } else {
            $newOwner = $manager
        }

        foreach ( $group in $groups ) {
            $ownersResponse = Invoke-MgGraphRequest -Method GET -Uri ("https://graph.microsoft.com/v1.0/groups/" + $group.Id + "/owners")
            $owners = $ownersResponse.Value

            # process groups that the user has ownership of
            if ( $owners.UserPrincipalName -contains $UserPrincipalName ) {
                # The user being offboarded is the only owner of the group. Ownership needs to be re-assigned
                if ( $owners.length -eq 1 ) {
                    # Add new owner as a member (required)
                    $newOwnerId = $newOwner.Id
                    if ( (Get-MgGroupMember -GroupId $group.Id).Id -notContains $newOwnerId ) {
                        try {
                            $params = @{
                                "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/${newOwnerId}"
                            }
                            New-MgGroupMemberByRef -GroupId $group.Id -BodyParameter $params
                        } catch {
                            Write-Output "[UnifiedGroup ownership removal] Error occurred attempting to add $($newOwner.UserPrincipalName) to group: $($group.DisplayName). Error:"
                            Write-Output $_.Exception.Message
                        }
                    }
                    # Add new owner as an owner
                    try {
                        $params = @{
                            "@odata.id" = "https://graph.microsoft.com/v1.0/users/${NewOwnerId}"
                        }
                        New-MgGroupOwnerByRef -GroupId $group.Id -BodyParameter $params
                        $assignedOwnership.Add($group.DisplayName)
                    } catch {
                        Write-Output "[UnifiedGroup ownership removal] Error occurred attempting to grant $($newOwner.UserPrincipalName) ownership of group: $($group.DisplayName). Error:"
                        Write-Output $_.Exception.Message
                    }

                }
                # After a different user has been granted ownership, or if the group has other owners, remove the user's ownership
                try {
                    Remove-MgGroupOwnerByRef -GroupId $group.Id -DirectoryObjectId $user.Id
                    $removedGroups.Add($group.DisplayName)
                } catch {
                    Write-Output "[UnifiedGroup ownership removal] Error occurred attempting to remove $UserPrincipalName ownership of group: $($group.DisplayName). Error:"
                    Write-Output $_.Exception.Message
                }
            }
        }

        $removedGroups = $removedGroups | Sort-Object
        $assignedOwnership = $assignedOwnership | Sort-Object

        if ( $assignedOwnership ) {
            Write-Output "[UnifiedGroup ownership removal] Granted $($newOwner.UserPrincipalName) ownership of Unified Group(s): $($assignedOwnership -join ", ")"
        }
        
        if ( $removedGroups ) {
            Write-Output "[UnifiedGroup ownership removal] Removed ${UserPrincipalName}'s ownership of Unified Group(s): $($removedGroups -join ", ")"
        }
    }
}