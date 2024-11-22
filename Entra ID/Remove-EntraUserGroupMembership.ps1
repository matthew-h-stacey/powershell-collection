<#
.SYNOPSIS
Remove an Entra ID user from all assigned groups they are currently members of

.EXAMPLE
Remove-EntraUserGroupMembership -UserPrincipalName jsmith@contoso.com
#>

function Remove-EntraUserGroupMembership {

    param(
        [Parameter(Mandatory = $True)]
        [String]$UserPrincipalName	
    )

    # Empty lists to store groups
    $removedGroups = New-Object System.Collections.Generic.List[System.Object]

    try {
        # Locate user before starting
        $user = Get-MgUser -UserId $UserPrincipalName -ErrorAction Stop
        # Get statically assigned security group membership
        $groups = Get-MgUserMemberOf -UserId $UserPrincipalName | Where-Object {
            $_.additionalProperties.mailEnabled -eq $false -and
        ($null -eq $_.additionalProperties.groupTypes -or $_.additionalProperties.groupTypes -notContains "DynamicMembership")
        }
        # Remove user from each group. Add group name to list
        foreach ( $group in $groups ) {
            $groupDisplayName = $group.AdditionalProperties.displayName
            try {
                Remove-MgGroupMemberByRef -GroupId $group.Id -DirectoryObjectId $user.Id
                $removedGroups.Add($groupDisplayName)
            } catch {
                Write-Output "[EntraID Groups] Failed to remove $UserPrincipalName from $groupDisplayName. Error: $($_.Exception.Message)"
            }
        }
        if ( $removedGroups ) {
            $removedGroups = $removedGroups | Sort-Object
            Write-Output "[EntraID Groups] Removed $($UserPrincipalName) from Entra ID group(s): $($removedGroups -join ", ")"
        }
    } catch {
        Write-Output "[EntraID Groups] Failed to locate Entra user: $UserPrincipalName. Please confirm the UserPrincipalName and try again."
        Write-Output $_.Exception.Message
    }    

}