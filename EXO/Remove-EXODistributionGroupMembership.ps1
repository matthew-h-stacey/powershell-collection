function Remove-EXODistributionGroupMembership {
    param(
        [Parameter(Mandatory = $true)]
        [String]
        $UserPrincipalName
    )

    $removedDistributionGroups = New-Object System.Collections.Generic.List[System.Object]
    $mailbox = Get-Mailbox -Identity $UserPrincipalName
    
    $distributionGroups = Get-DistributionGroup | Where-Object { (Get-DistributionGroupMember $_.Name | ForEach-Object { $_.PrimarySmtpAddress }) -contains $mailbox.PrimarySmtpAddress }
    $distributionGroups  | ForEach-Object {
        try {
            Remove-DistributionGroupMember -Identity $_.Identity -Member $mailbox.PrimarySmtpAddress -Confirm:$False
            $removedDistributionGroups.Add($_.DisplayName)
        } catch {
            Write-Output "[Disti] Failed to remove $UserPrincipalName from distribution group: $($_.DisplayName). Error:"
            Write-Output $_.Exception.Message	
        }

    }
    $removedDistributionGroups = ($removedDistributionGroups | Sort-Object) -join ", "
    Write-Output "[Disti] Removed $UserPrincipalName from the following distribution groups: $removedDistributionGroups"
	
}