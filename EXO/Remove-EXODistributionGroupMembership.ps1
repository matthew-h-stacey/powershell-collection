function Remove-EXODistributionGroupMembership {
    param(
        [Parameter(Mandatory = $true)]
        [String]
        $UserPrincipalName
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
    $task = "Remove Exchange distribution group membership"
    $status = "Failure"
    $results = [System.Collections.Generic.List[System.Object]]::new()
    $removedDistributionGroups = New-Object System.Collections.Generic.List[System.Object]
    
    $mailbox = Test-EXOMailbox -UserPrincipalName $UserPrincipalName
    if ( $mailbox ) {
        $distributionGroups = Get-DistributionGroup | Where-Object { (Get-DistributionGroupMember $_.Name | ForEach-Object { $_.PrimarySmtpAddress }) -contains $mailbox.PrimarySmtpAddress }
        $distributionGroups  | ForEach-Object {
            try {
                Remove-DistributionGroupMember -Identity $_.Identity -Member $mailbox.PrimarySmtpAddress -Confirm:$False
                $removedDistributionGroups.Add($_.DisplayName)
            } catch {
                $message = "Failed to remove $UserPrincipalName from distribution group: $($_.DisplayName)"
                $errorMessage = $_.Exception.Message
                Add-TaskResult -Task $task -Status $status -Message $message -ErrorMessage $errorMessage
            }
        }
        if ( $removedDistributionGroups ) {
            $removedDistributionGroups = ($removedDistributionGroups | Sort-Object) -join ", "
            $status = "Success"
            $message = "Removed $UserPrincipalName from the following distribution groups"
            $details = $removedDistributionGroups
            $errorMessage = $null
            Add-TaskResult -Task $task -Status $status -Message $message -Details $details -ErrorMessage $errorMessage
        }   
    } else {
        $status = "Skipped"
        $message = "Unable to locate mailbox: $UserPrincipalName"
        Add-TaskResult -Task $task -Status $status -Message $message -ErrorMessage $errorMessage
    }
    return $results    
	
}