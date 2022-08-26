#
# Get all distribution groups
Get-DistributionGroup | select Name,PrimarySmtpAddress,HiddenFromAddressListsEnabled,RequireSenderAuthenticationEnabled,WindowsEmailAddress | Export-CSV C:\AllDistributionGroups.csv -NoTypeInformation

#
# EXCHANGE: Get all distribution group members
$AllDistributionGroups = (Get-DistributionGroup).Identity
$GroupMembers = foreach($member in $AllDistributionGroups){Get-DistributionGroupMember -Identity $member | select Name,PrimarySmtpAddress,@{n='Member';e={$member.Name}}}
$GroupMembers | Export-Csv C:\AllDistributionGroupMembers.csv -Notypeinformation


#
# O365: Get all distribution group members
# $GroupMembers = foreach($member in Get-DistributionGroup){
#                       $memberID = $member.Identity
#                        Get-DistributionGroupMember $memberID | select Name,@{n='Member';e={$member.Name}}
#                        }
#                        $GroupMembers | Export-Csv C:\AllDistributionGroupMembers.csv -Notypeinformation

#
# EXCHANGE: Get all distribution groups ADPermissions
#Get-DistributionGroup | Get-ADPermission | select Identity,User,@{name="AccessRights";expression={$_.AccessRights}},@{name="ExtendedRights";expression={$_.ExtendedRights}} | Export-CSV C:\AllDistributionGroupsADPermissions.csv -NoTypeInformation

#
# O365: Get all distribution groups send-as permissions
Get-DistributionGroup | Get-RecipientPermission | select Identity,Trustee,AccessRights

#
# Get all MailPublicFolders
Get-MailPublicFolder | select Alias,DisplayName,EmailAddresses,GrantSendOnBehalfTo,HiddenFromAddressListsEnabled,PrimarySmtpAddress | Export-CSV C:\AllMailPublicFolders.csv -NoTypeInformation

#
# EXCHANGE: Get all MailPublicFolder send-as permissions
#Get-MailPublicFolder | where {$_.IsValid -eq $true -and $_.EmailAddressPolicyEnabled -eq $true} | Get-ADPermission | where {$_.ExtendedRights -like "Send-As"} | select @{name="ExtendedRights";expression={$_.ExtendedRights}},User,Identity | # Export-Csv C:\PublicFolderSendAsPermissions.csv -NoTypeInformation

#
# O365: Get all MailPublicFolder send-as permissions
Get-PublicFolder -Recurse | where {($_.MailEnabled -eq $True)} | Get-PublicFolderClientPermission | select FolderName,User,AccessRights | Export-Csv C:\PublicFolderSendAsPermissions.csv -NoTypeInformation

#
# Get all mailboxes
Get-Mailbox -ResultSize Unlimited | select DisplayName,ForwardingAddress | Export-CSV C:\AllMailboxes.csv -Notypeinformation

#
# Get all Mailboxes that have forwarding enabled
Get-Mailbox -ResultSize Unlimited | where {$_.ForwardingAddress -ne $null} | select DisplayName,ForwardingAddress | Export-CSV C:\AllForwardingMailboxes.csv -Notypeinformation
