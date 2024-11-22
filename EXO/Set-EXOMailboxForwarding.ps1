function Set-EXOMailboxForwarding {
    
    param(
        [SkyKickParameter(
            DisplayName = "Email address/UserPrincipalName of the mailbox to set forwarding on"
        )]
        [Parameter(Mandatory = $true)]
        [String]$Identity,

        [SkyKickParameter(
            DisplayName = "Recipient location",
            HintText = "The command to enable forwarding differs for internal and external recipients. Select the appropriate location based on whether or not the recipient is in the company's Office 365 organization or is external."
        )]
        [Parameter(Mandatory = $true)]
        [ValidateSet("Internal", "External")]
        [String]$RecipientLocation,

        [SkyKickParameter(
            DisplayName = "Recipient email address",
            HintText = "Enter the email address of the recipient emails will be forwarded to."
        )]
        [Parameter(Mandatory = $true)]
        [String]$Recipient,

        [SkyKickParameter(
            DisplayName = "Forward or redirect email?",
            HintText = "Forwarding sends a copy of every email from the source to the destination. Redirecting delivers the email to the destination only, not the source."
        )]
        [Parameter(Mandatory = $true)]
        [ValidateSet("Forwarding", "Redirection")]
        [String]$DeliveryType
        
    )

    $status = "Failure"
    $message = $null
    $errorMessage = $null
    $details = $null

    # Switch to set $DeliverToMailboxAndForward based on $DeliveryType
    switch ( $DeliveryType ) {
        "Forwarding" { 
            $DeliverToMailboxAndForward = $true
            $MailAction = "forward"
        }
        "Redirection" {
            $DeliverToMailboxAndForward = $false
            $MailAction = "redirect"
        }
    }

    # Check for the mailbox before proceeding
    if ( !(Test-EXOMailbox -UserPrincipalName $Identity) ) {
        return "[Email $DeliveryType] Skipped, no mailbox found for $Identity"
    }

    # Configure mailbox forwarding/redirection based on recipient location
    # The difference here is in the parameter ForwardingAddress vs. ForwardingSMTPAddress

    switch ( $RecipientLocation ) {
        "Internal" { 
            try {
                Set-Mailbox -Identity $Identity -DeliverToMailboxAndForward $DeliverToMailboxAndForward -ForwardingAddress $Recipient
                #Write-Output "[Email $DeliveryType] Set email to $MailAction from $Identity to $Recipient."
            } catch {
                #Write-Output "[Email $DeliveryType] Failed to $MailAction email from $Identity to $Recipient. Error:"
                $_.Exception.Message
            }
        }
        "External" {
            try {
                Set-Mailbox -Identity $Identity -DeliverToMailboxAndForward $DeliverToMailboxAndForward -ForwardingAddress $null -ForwardingSMTPAddress $Recipient
                #Write-Output "[Email $DeliveryType] Set email to $MailAction from $Identity to $Recipient."
            } catch {
                #Write-Output "[Email $DeliveryType] Failed to $MailAction from $Identity to $Recipient. Error:"
                $_.Exception.Message
            }
        }
    }

    return [PSCustomObject]@{
        FunctionName = $MyInvocation.MyCommand.Name
        Status       = $status
        Message      = $message
        ErrorMessage = $errorMessage
        Details      = $details
    }
	
}