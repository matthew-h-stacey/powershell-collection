# 1. Create SharedMailbox + hide from GAL
# 2. Add auto-reply to SharedMailbox
# 3. Add SharedMailbox to the DG
# This can be added as a member to a distibution group to add automatic replies to an existing distribution list

$dn = "Seattle Office AutoReply"
$addr = "SeattleOfficeAutoReply@5r86fn.onmicrosoft.com"
.\New-SharedMailbox.ps1 -Name $dn -DisplayName $dn -PrimarySmtpAddress $addr -Shared
Set-Mailbox -Identity $addr -HiddenFromAddressListsEnabled:$true

$msg = "This distribution group is outdated. Please use the new group moving forward: wastepapertimmy@contoso.com"
Set-MailboxAutoReplyConfiguration -Identity $addr -AutoReplyState Enabled -InternalMessage $msg -ExternalMessage $msg

<# 
Many normal methods of selecting a recipient (Recipient is …) are not valid for a distibution group
https://docs.microsoft.com/en-us/exchange/policy-and-compliance/mail-flow-rules/conditions-and-exceptions?view=exchserver-2016#message-sensitive-information-types-to-and-cc-values-size-and-character-sets
However, you can filter based on the "To" header

Example:

Apply this rule if …
	A message header includes ...
		Header: To
		Value: SeattleOffice@5r86fn.onmicrosoft.com
    Do the following ...
        Add these repients to the To box ...
            "Seattle Office AutoReply"

#>