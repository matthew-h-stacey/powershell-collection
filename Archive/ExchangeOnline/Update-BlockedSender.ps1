Param(
    [Parameter(Mandatory = $True)][string]$Mailbox,
    [Parameter(Mandatory = $True)][string]$ExternalAddress,
    [parameter(ParameterSetName = "Add")][switch]$Add,
    [parameter(ParameterSetName = "Remove")][switch]$Remove
)

# Used to add or remove entries from BlockedSendersAndDomains without a user's intervention
# Can be helpful when a user has accidentally added an entry and is looking for email from a sender
# Works well with Export-MailRules.ps1 to pull their rules and BlockedSendersAndDomains 

# https://docs.microsoft.com/en-us/powershell/module/exchange/set-mailboxjunkemailconfiguration?view=exchange-ps
# Add: Set-MailboxJunkEmailConfiguration "Michele Martin" -TrustedSendersAndDomains @{Add="contoso.com","fabrikam.com"} -BlockedSendersAndDomains @{Add="jane@fourthcoffee.com"}
# Remove: Set-MailboxJunkEmailConfiguration "Michele Martin" -TrustedSendersAndDomains @{Remove="contoso.com","fabrikam.com"} -BlockedSendersAndDomains @{Remove="jane@fourthcoffee.com"}

if ( $Add ) { 
    Set-MailboxJunkEmailConfiguration $Mailbox -BlockedSendersAndDomains @{Add = "$ExternalAddress" }
}

if ( $Remove ) {
    Set-MailboxJunkEmailConfiguration $Mailbox -BlockedSendersAndDomains @{Remove = "$ExternalAddress" }
}

