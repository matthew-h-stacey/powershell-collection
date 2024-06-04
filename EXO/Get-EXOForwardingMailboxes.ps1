function Get-EXOForwardingMailboxes {

    # Retrieve all mailboxes with forwarding enabled
    $forwardingMBs = Get-Mailbox | Where-Object { ($null -ne $_.ForwardingSMTPAddress) -or ($null -ne $_.ForwardingAddress ) }

    # For-each loop to gather and format properties for all the mailboxes with forwarding
    $results = @()
    foreach ( $mailbox in $forwardingMBs ) {
        if ( $mailbox.ForwardingAddress ) {
            $forwardingAddressUser = (Get-Recipient $mailbox.ForwardingAddress).PrimarySmtpAddress
        } 
        else {
            $forwardingAddressUser = $null
        }
        $output = [PSCustomObject]@{
            DisplayName             = $mailbox.DisplayName
            UserPrincipalName       = $mailbox.UserPrincipalName
            ForwardingSMTPAddress   = $mailbox.ForwardingSMTPAddress
            ForwardingAddress       = $forwardingAddressUser
        }
        $results += $output
    }
    $results = $results | Sort-Object DisplayName
    return $results
	
}