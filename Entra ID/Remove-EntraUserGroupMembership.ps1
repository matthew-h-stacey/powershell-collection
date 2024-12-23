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

    # Helper function
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
                Task         = $Task
                Status       = $Status
                Message      = $Message
                Details      = $Details
                ErrorMessage = $ErrorMessage
            })
    }

    # Initialize output variables
    $function = $MyInvocation.MyCommand.Name
    $task = "Remove user from Entra security groups"
    $status = "Failure"
    $results = [System.Collections.Generic.List[System.Object]]::new()
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
                $message = "Failed to remove $UserPrincipalName from $groupDisplayName"
                $errorMessage = $_.Exception.Message
                Add-TaskResult -Task $task -Status $status -Message $message -ErrorMessage $errorMessage -Details @($user, $group)
            }
        }
        if ( $removedGroups ) {
            $removedGroupsString = ($removedGroups | Sort-Object) -join ', '
            $status = "Success"
            $message = "Removed $UserPrincipalName from Entra ID group(s): $removedGroupsString"
            $errorMessage = $null
            Add-TaskResult -Task $task -Status $status -Message $message -ErrorMessage $errorMessage
        }
    } catch {
        $message = "Failed to locate Entra user: $UserPrincipalName. Please confirm the UserPrincipalName and try again"
        $errorMessage = $_.Exception.Message
        Add-TaskResult -Task $task -Status $status -Message $message -ErrorMessage $errorMessage
    }
    return $results

}