function Remove-UnifiedGroupMembership {

    param(
        [Parameter(Mandatory = $true)]
        [String]$UserPrincipalName
    )

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
    $task = "Remove user from Unified Groups"
    $status = "Failure"
    $results = [System.Collections.Generic.List[System.Object]]::new()

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
            $message = "Failed to remove $UserPrincipalName from UnifiedGroup: $($group.DisplayName)"
            $errorMessage = $_.Exception.Message
            Add-TaskResult -Task $task -Status $status -Message $message -ErrorMessage $errorMessage
        }
    }
    # Output the combined results
    if ( $groupsRemoved ) {
        $groupsRemovedString = ($groupsRemoved | Sort-Object) -join ", "
        $status = "Success"
        $message = "Removed $UserPrincipalName from UnifiedGroup(s): $groupsRemovedString"
        $errorMessage = $null
        Add-TaskResult -Task $task -Status $status -Message $message -ErrorMessage $errorMessage
        return $results
    }

}