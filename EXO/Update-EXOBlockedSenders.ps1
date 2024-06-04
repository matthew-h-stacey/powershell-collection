<#
.SYNOPSIS
This script remoes a sender address from a mailboxes blocked sender settings

.EXAMPLE
Update-EXOBlockedSenders -Identity jsmith@contoso.com -Action Add -SenderAddress noreply@salesforce.com 

.NOTES
https://docs.microsoft.com/en-us/powershell/module/exchange/set-mailboxjunkemailconfiguration?view=exchange-ps
Add: Set-MailboxJunkEmailConfiguration "Michele Martin" -TrustedSendersAndDomains @{Add="contoso.com","fabrikam.com"} -BlockedSendersAndDomains @{Add="jane@fourthcoffee.com"}
Remove: Set-MailboxJunkEmailConfiguration "Michele Martin" -TrustedSendersAndDomains @{Remove="contoso.com","fabrikam.com"} -BlockedSendersAndDomains @{Remove="jane@fourthcoffee.com"}
#>

param(
    # The mailbox to modify
    [Parameter(Mandatory = $True)]
    [string]
    $Identity,

    # The action to take, either block or remove from blocked senders
    [Parameter(Mandatory=$true)]
    [ValidateSet("Add", "Remove")]
    [String]
    $Action,

    # External email address or domain to add/remove from blocked senders
    [Parameter(Mandatory = $True)]
    [string]
    $Sender
)

switch ( $Action ) {
    "Add" {
        try {
            Set-MailboxJunkEmailConfiguration $Identity -BlockedSendersAndDomains @{Add = "$Sender" } -ErrorAction Stop
            Write-Output "[INFO] Added $Sender to the blocked sender/domain list for $Identity"
        } catch {
            Write-Output "[ERROR] Failed to add $Sender to the blocked sender/domain list for $Identity. Error: $($_.Exception.Message)"
        }
    }
    "Remove" {
        try {
            Set-MailboxJunkEmailConfiguration $Identity -BlockedSendersAndDomains @{Remove = "$Sender" }
            Write-Output "[INFO] Removed $Sender from the blocked sender/domain list for $Identity"
        } catch {
            Write-Output "[ERROR] Failed to remove $Sender to the blocked sender/domain list for $Identity. Error: $($_.Exception.Message)"
        }
    }
}