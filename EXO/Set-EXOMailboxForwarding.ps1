function Set-EXOMailboxForwarding {
    
    param(
        [SkyKickParameter(
            DisplayName = "Email address/UserPrincipalName of the mailbox to set forwarding on"
        )]
        [Parameter(Mandatory = $true)]
        [String]
        $Identity,

        [SkyKickParameter(
            DisplayName = "Recipient location",
            HintText = "The command to enable forwarding differs for internal and external recipients. Select the appropriate location based on whether or not the recipient is in the company's Office 365 organization or is external."
        )]
        [Parameter(Mandatory = $true)]
        [ValidateSet("Internal", "External")]
        [String]
        $RecipientLocation,

        [SkyKickParameter(
            DisplayName = "Recipient email address",
            HintText = "Enter the email address of the recipient emails will be forwarded to."
        )]
        [Parameter(Mandatory = $true)]
        [String]
        $Recipient,

        [SkyKickParameter(
            DisplayName = "Forward or redirect email?",
            HintText = "Forwarding sends a copy of every email from the source to the destination. Redirecting delivers the email to the destination only, not the source."
        )]
        [Parameter(Mandatory = $true)]
        [ValidateSet("Forwarding", "Redirection")]
        [String]
        $DeliveryType
        
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
    $task = "Set mailbox forwarding"
    $status = "Failure"
    $results = [System.Collections.Generic.List[System.Object]]::new()

    # Switch to set $DeliverToMailboxAndForward and $mailAction (string for output) based on $DeliveryType
    switch ( $DeliveryType ) {
        "Forwarding" { 
            $DeliverToMailboxAndForward = $true
            $mailAction = "forward"
        }
        "Redirection" {
            $DeliverToMailboxAndForward = $false
            $mailAction = "redirect"
        }
    }

    # Configure mailbox forwarding/redirection based on recipient location
    # The difference is in the parameter ForwardingAddress vs. ForwardingSMTPAddress
    $mailbox = Test-EXOMailbox -UserPrincipalName $Identity
    if ( $mailbox ) {
        switch ( $RecipientLocation ) {
            "Internal" { 
                try {
                    Set-Mailbox -Identity $Identity -DeliverToMailboxAndForward $DeliverToMailboxAndForward -ForwardingAddress $Recipient
                    $status = "Success"
                    $message = "Set email to $mailAction from $Identity to $Recipient"
                } catch {
                    $message = "Failed to $mailAction email from $Identity to $Recipient"
                    $errorMessage = $_.Exception.Message
                }
            }
            "External" {
                try {
                    Set-Mailbox -Identity $Identity -DeliverToMailboxAndForward $DeliverToMailboxAndForward -ForwardingAddress $null -ForwardingSMTPAddress $Recipient
                    $status = "Success"
                    $message = "Set email to $mailAction from $Identity to $Recipient"
                } catch {
                    $message = "Failed to $mailAction email from $Identity to $Recipient"
                    $errorMessage = $_.Exception.Message
                }
            }
        }
    } else {
        $status = "Skipped"
        $message = "No mailbox found for: $Identity"
    }

    # Output
    Add-TaskResult -Task $task -Status $status -Message $message -ErrorMessage $errorMessage
    return $results	
	
}