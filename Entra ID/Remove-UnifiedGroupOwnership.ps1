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

    function Add-TaskResult {
        param(
            [string]$Task,
            [string]$Status,
            [string]$Message,
            [string]$ErrorMessage = $null,
            [string]$Details = $null
        )
        $results.Add([PSCustomObject]@{
                FunctionName = $function
                Task         = $task
                Status       = $Status
                Message      = $Message
                Details      = $Details
                ErrorMessage = $ErrorMessage
            })
    }

    # Initialize output variables
    $function = $MyInvocation.MyCommand.Name
    $task = "Remove Unified Group ownership"
    $status = "Failure"
    $results = [System.Collections.Generic.List[System.Object]]::new()
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
                    $task = "Migrate sole group ownership to other user"
                    # Add new owner as a member (required)
                    $newOwnerId = $newOwner.Id
                    # If the new owner is not yet a member of the group, add them as a member
                    if ( (Get-MgGroupMember -GroupId $group.Id).Id -notContains $newOwnerId ) {
                        try {
                            $params = @{
                                "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/${newOwnerId}"
                            }
                            New-MgGroupMemberByRef -GroupId $group.Id -BodyParameter $params
                        } catch {
                            $message = "Error occurred attempting to add $($newOwner.UserPrincipalName) to group: $($group.DisplayName)"
                            $errorMessage = $_.Exception.Message
                            Add-TaskResult -Task $task -Status $status -Message $message -ErrorMessage $errorMessage
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
                        $message = "Error occurred attempting to grant $($newOwner.UserPrincipalName) ownership of group: $($group.DisplayName)"
                        $errorMessage = $_.Exception.Message
                        Add-TaskResult -Task $task -Status $status -Message $message -ErrorMessage $errorMessage
                    }
                }
                # After a different user has been granted ownership, or if the group has other owners, remove the user's ownership
                $task = "Remove Unified Group ownership"
                try {
                    Remove-MgGroupOwnerByRef -GroupId $group.Id -DirectoryObjectId $user.Id
                    $removedGroups.Add($group.DisplayName)
                } catch {
                    $message = "Error occurred attempting to remove $UserPrincipalName ownership of group: $($group.DisplayName)"
                    $errorMessage = $_.Exception.Message
                    Add-TaskResult -Task $task -Status $status -Message $message -ErrorMessage $errorMessage
                }
            }
        }
        if ( $assignedOwnership ) {
            $assignedOwnershipString = ($assignedOwnership | Sort-Object) -join ", "
            $status = "Success"
            $message = "Granted $($newOwner.UserPrincipalName) ownership of Unified Group(s): $assignedOwnershipString"
            $errorMessage = $null
            Add-TaskResult -Task $task -Status $status -Message $message -ErrorMessage $errorMessage
        }
        if ( $removedGroups ) {
            $removedGroupsString = ($removedGroups | Sort-Object) -join ", "
            $status = "Success"
            $message = "Removed ${UserPrincipalName}'s ownership of Unified Group(s): $removedGroupsString"
            $errorMessage = $null
            Add-TaskResult -Task $task -Status $status -Message $message -ErrorMessage $errorMessage
        }
    } else {
        $status = "Skipped"
        $message = "User not found: $UserPrincipalName"
        Add-TaskResult -Task $task -Status $status -Message $message -ErrorMessage $errorMessage
    }
    return $results
    
}