function Remove-UnifiedGroupMembership {

    # WIP

    # Objective: Remove a user from from all UnifiedGroups (365 Groups and Teams)

    param(
        [Parameter(Mandatory = $true)]
        [String]$UserPrincipalName
    )

    # List to store the groups that the user are removed from
    $groupsRemoved = New-Object System.Collections.Generic.List[System.Object]

    $userObject = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/users/$UserPrincipalName"
    $groupMembership = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/users/$UserPrincipalName/memberof" | Select-Object -ExpandProperty Value | Where-Object { $_.GroupTypes -eq "Unified" } | Select-Object DisplayName, Id, GroupTypes

    # Iterate through all joined groups and remove the user
    foreach ( $group in $groupMembership ) {
        try {
            $Uri = "https://graph.microsoft.com/v1.0/groups/$($group.Id)/members/$($userObject.Id)" + '/$ref'
            Invoke-MgGraphRequest -Method DELETE -Uri $Uri
            $groupsRemoved.Add($group.DisplayName)
        } catch {
            Write-Output "[UnifiedGroup] Failed to remove $UserPrincipalName from UnifiedGroup: $($group.DisplayName). Error:"
            Write-Output $_.Exception.Message
        }
    }

    if ( $groupsRemoved ) {
        $groupsRemovedString = ($groupsRemoved | Sort-Object) -join ", "
        Write-Output "[UnifiedGroup] Removed $UserPrincipalName from UnifiedGroup(s): $groupsRemovedString"
    }

}