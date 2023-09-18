function Update-UnifiedGroupSubscriptionSettings {
    
    # Objective: Update subscription settings for all members of a M365 group so they receive emails sent to that group

    param (
        # The PrimarySmtpAddress of the group to modify subscription settings for
        [Parameter(Mandatory=$true)]
        [String]
        $PrimarySmtpAddress
    )

    try {
        $Group = Get-UnifiedGroup -Identity $PrimarySmtpAddress
    }
    catch {
        throw "Unable to locate the requested group, please check the PrimarySmtpAddress provided and try again."
    }

    $Members = Get-UnifiedGroupLinks -Identity $Group.Identity -LinkType Members
    $Subscribers = Get-UnifiedGroupLinks -Identity $Group.Identity -LinkType Subscribers

    if ( $Members ) {
        foreach ($Member in $Members) {
            
            if ($Member.Name -NotIn $Subscribers.Name) {
                try {
                    Write-Output "$($Group.Name): Subscribed $($Member.Name)"
                    Add-UnifiedGroupLinks -Identity $Group.Name -LinkType Subscribers -Links $Member.Name
                }
                catch {
                    Write-Output "[Error] Unable to subscribe $($Member.Name) to $($Group.Name). Error:"
                    $_.Exception.Message 
                }
            }
        }
    }
    else {
        Write-Output "[INFO] All members of $($Group.Name) are subscribed to the group. Exiting."
    }
	
}