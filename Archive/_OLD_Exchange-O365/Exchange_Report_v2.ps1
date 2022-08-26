# Exchange Report
#
#

# 0) Gather initial information to be used in the script
$AllMailboxes = Get-Mailbox -ResultSize Unlimited
$AllDistributionGroups = Get-DistributionGroup -ResultSize Unlimited 
$AllMailContacts = Get-MailContact -ResultSize Unlimited 
$AllMailPublicFolders = Get-MailPublicFolder -ResultSize Unlimited 

# 1) Get all distribution groups
$AllDistributionGroups | select Name,DisplayName,PrimarySmtpAddress,@{n='EmailAddresses';expression={$_.EmailAddresses}},@{n='ManagedBy';expression={$_.ManagedBy}},HiddenFromAddressListsEnabled,RequireSenderAuthenticationEnabled,MemberJoinRestriction,MemberDepartRestriction | Export-CSV C:\1DistributionGroups_Exchange.csv -NoTypeInformation

# 2) Get all distribution group members
$GroupMembers = foreach($group in $AllDistributionGroups){Get-DistributionGroupMember -Identity $group | select @{n='DistributionGroup';e={$group.Name}},Name,PrimarySmtpAddress}
$GroupMembers | Export-Csv C:\2DistributionGroupMembers_Exchange.csv -NoTypeInformation

# 3) Get all distribution groups ADPermissions
$AllDistributionGroups | Get-ADPermission | select Identity,User,@{name="AccessRights";expression={$_.AccessRights}},@{name="ExtendedRights";expression={$_.ExtendedRights}} | Export-CSV C:\3DistributionGroupsADPermissions_Exchange.csv -NoTypeInformation

# 4) Get all MailPublicFolders
$AllMailPublicFolders | select Alias,DisplayName,@{n='EmailAddresses';expression={$_.EmailAddresses}},@{n='GrantSendOnBehalfTo';expression={$_.GrantSendOnBehalfTo}},HiddenFromAddressListsEnabled,PrimarySmtpAddress | Export-CSV C:\4MailPublicFolders_Exchange.csv -NoTypeInformation

# 5) Get all MailPublicFolder send-as permissions
$AllMailPublicFolders | where {$_.IsValid -eq $true} | Get-ADPermission | where {$_.ExtendedRights -like "Send-As"} | select @{name="ExtendedRights";expression={$_.ExtendedRights}},User,Identity | Export-Csv C:\5PublicFolderSendAsPermissions_Exchange.csv -NoTypeInformation

# 6) Get all mailboxes
$AllMailboxes | select DisplayName,PrimarySmtpAddress,@{n='EmailAddresses';expression={$_.EmailAddresses}},ForwardingAddress,HiddenFromAddressListsEnabled,WhenMailboxCreated | Export-CSV C:\6Mailboxes_Exchange.csv -NoTypeInformation

# 7) Get all FullAccess mailbox permissions
$AllMailboxes | Get-MailboxPermission | where{ ($_.AccessRights -eq "FullAccess") -and ($_.IsInherited -eq $false) -and ($_.IsValid -eq $true)} | select User,Identity,@{n='AccessRights';expression={$_.AccessRights}},IsInherited | Export-CSV C:\7MailboxesPermissions_Exchange.csv -NoTypeInformation

# 8) Get all mail contacts
$AllMailContacts | select Alias,PrimarySmtpAddress,ExternalEmailAddress,@{n='EmailAddresses';expression={$_.EmailAddresses}},HiddenFromAddressListsEnabled | Export-CSV C:\8Mailcontacts_Exchange.csv -NoTypeInformation