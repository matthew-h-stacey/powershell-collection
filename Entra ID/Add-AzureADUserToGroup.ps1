function Add-AzureADUserToGroup {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $User,

        [Parameter(Mandatory = $true)]
        [String]
        $GroupName
    )

    # Example 1 - Single add:
    # Add-AzureADUserToGroup -User jsmith@contoso.com -GroupName "Coffee Club"

    # Example 2 - Bulk add:
    # New-AzureADGroup -DisplayName "CM_NonUserAccounts" -MailEnabled $false -SecurityEnabled $true -MailNickName "NotSet"
    # Get-Content users.txt | ForEach-Object { Add-AzureADUserToGroup -User $_ -GroupName "CM_NonUserAccounts" }

    # Retrieve the GroupID for the provided group DisplayName
    $GroupFilter = "DisplayName eq '$GroupName'"

    $AADGroup = Get-AzureADGroup -Filter $GroupFilter
    if ($null -eq $AADGroup) {
        throw "Failed to locate group: $GroupName, quitting ... "
    }

    # Locate UID for the provided user
    if ( $User -match '@') { # UPN was provided
        $UID = (Get-AzureADUser -ObjectId $User).ObjectId
    }
    else { # DisplayName was provided
        $UserFilter = "DisplayName eq '$User'"
        $UID = (Get-AzureADUser -Filter $UserFilter).ObjectId
    }

    # Add the user to the group
    try {
        if ( !((Get-AzureADGroupMember -ObjectId $AADGroup.ObjectId) -match $UID) ){
            Add-AzureADGroupMember -ObjectId $AADGroup.ObjectId -RefObjectId $UID
            Write-Output "[INFO] Added: $User to $GroupName."
        }
        else {
            Write-Output "[INFO] Skipped: $User, user is already a member of $GroupName. "
        }
    }
    catch {
        Write-Warning "Unable to add $User to $GroupName. Encountered error:"
        $_.Exception.Message
    }
    
}
