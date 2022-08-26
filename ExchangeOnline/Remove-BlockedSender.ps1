Param(
    [Parameter(Mandatory = $True)]
    [string]$Mailbox,
    [string]$ExternalAddress
)


# Set-MailboxJunkEmailConfiguration
# https://docs.microsoft.com/en-us/powershell/module/exchange/set-mailboxjunkemailconfiguration?view=exchange-ps
# Add: Set-MailboxJunkEmailConfiguration "Michele Martin" -TrustedSendersAndDomains @{Add="contoso.com","fabrikam.com"} -BlockedSendersAndDomains @{Add="jane@fourthcoffee.com"}
# Remove: Set-MailboxJunkEmailConfiguration "Michele Martin" -TrustedSendersAndDomains @{Remove="contoso.com","fabrikam.com"} -BlockedSendersAndDomains @{Remove="jane@fourthcoffee.com"}



Set-MailboxJunkEmailConfiguration $Mailbox -BlockedSendersAndDomains @{Remove = "$ExternalAddress" }