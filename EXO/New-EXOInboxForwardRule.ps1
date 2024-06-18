param (
    [Parameter(Mandatory=$true)]
    [string]
    $Mailbox,

    [Parameter(Mandatory=$true)]
    [string]
    $ExternalAddress
)

try {
    $mailboxExists = Get-Mailbox -Identity $Mailbox
} catch {
    Write-Output "[ERROR] Mailbox not found: $mailbox. Please check the provided input and try again."
    exit 1
}

if ( $mailboxExists ) {
    $params = @{
        Mailbox             = $Mailbox
        Name                = "Auto-forward email"
        ForwardTo           = $ExternalAddress
        StopProcessingRules = $False
    }
    try {
        New-InboxRule @params | Out-Null
        Write-Output "[INFO] Successfully created inbox rule to forward emails from $Mailbox to $ExternalAddress."
    } catch {
        Write-Output "[ERROR] Failed to create inbox rule. Error: $($_.Exception.Message)"
    }
}

