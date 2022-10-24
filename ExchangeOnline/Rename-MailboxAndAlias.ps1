param (
    [Parameter(Mandatory = $true)][string]$mailboxName,
    [Parameter(Mandatory = $true)][string]$mailboxNameUpdated
)

#$mailboxName = "Wetlab"
#$mailboxNameUpdated = $mailboxName + "_OLD"
$mailbox = Get-Mailbox -Identity $mailboxName
$newSmtpAddress = $mailboxNameUpdated + "@" + $mailbox.PrimarySmtpAddress.Split("@")[1]

Set-Mailbox -Identity $mailbox -HiddenFromAddressListsEnabled:$true # Hide mailbox
Set-Mailbox -Identity $mailbox -Alias $mailboxNameUpdated -DisplayName $mailboxNameUpdated # Update name
Set-Mailbox -Identity $mailbox -WindowsEmailAddress $newSmtpAddress # Set email address
Set-Mailbox -Identity $mailbox -EmailAddresses @{Remove = $mailbox.PrimarySmtpAddress } # (1/2) Update PrimarySmtpAddress with new value
Set-Mailbox -Identity $mailbox -EmailAddresses @{Add = $newSmtpAddress } # (2/2) Update PrimarySmtpAddress with new value