function Set-EXOMailboxAutoReply {
    
    param(
        [Parameter(Mandatory = $true)]
        [String]
        $Identity,

        [Parameter(Mandatory = $true)]
        [String]
        $InternalReply,

        [Parameter(Mandatory = $true)]
        [String]
        $ExternalReply
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
    $task = "Set mailbox auto-reply"
    $status = "Failure"
    $results = [System.Collections.Generic.List[System.Object]]::new()

    $mailbox = Test-EXOMailbox -UserPrincipalName $Identity
    if ( $mailbox ) {
        $params = @{
            Identity         = $Identity
            AutoReplyState   = "Enabled"
            InternalMessage  = $InternalReply
            ExternalMessage  = $ExternalReply
            ExternalAudience = "All"
            ErrorAction      = "Stop"
        }
        try {
            Set-MailboxAutoReplyConfiguration @params
            $status = "Success"
            $message = "Set auto-reply on mailbox"
            if ( $InternalReply -eq $ExternalReply) {
                $details = "Autoreply: $InternalReply"
            } else {
                $details = "Internal autoreply: $InternalReply. External autoreply: $ExternalReply."
            }
        } catch {
            $message = "Failed to apply auto-reply to $Identity"
            $errorMessage = $_.Exception.Message
        }
    } else {
        $status = "Skipped"
        $message = "No mailbox found for: $Identity"
    }

    # Output
    Add-TaskResult -Task $task -Status $status -Message $message -ErrorMessage $errorMessage -Details $details
    return $results	
	
}