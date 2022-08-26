Param
(   
    [Parameter(Mandatory = $true)] [string] $groupName,
    [Parameter(Mandatory = $true)] [boolean] $externallyAccessible
)

# Vanity domain
$domain = "contoso.com"

# Variables for the renamed group and email
$groupRenamedDN = $groupName + "_OLD" 
$groupRenamedEmail = $groupRenamedDN + "@" + $domain

# Back up properties of the group to be converted and its members
$group = Get-UnifiedGroup $groupName
$group | Select-Object *  | out-file "C:\TempPath\${groupName}_Backup_Properties.txt"
$groupMembers = Get-UnifiedGroupLinks -Identity $groupName -LinkType members
$groupMembers | out-file C:\TempPath\${groupName}_Backup_Members.txt

# Rename the current group and hide it from view, export new properties of the group
Set-UnifiedGroup $group.Name -DisplayName $groupRenamedDN -Alias $groupRenamedDN -PrimarySmtpAddress $groupRenamedEmail-HiddenFromExchangeClientsEnabled:$true -HiddenFromAddressListsEnabled:$true Set-UnifiedGroup $groupRenamedDN -EmailAddresses @{Remove = "$group.PrimarySmtpAddress" }
Get-UnifiedGroup $groupRenamedDN | Select-Object *  | out-file "C:\TempPath\${groupName}_Updated_Properties.txt"

# Created a new SharedMailbox using the old Name/DisplayName/PrimarySmtpAddress of the M365 Group
New-Mailbox -Shared -Name $groupName -DisplayName $groupName -PrimarySmtpAddress $group.PrimarySmtpAddress -RequireSenderAuthenticationEnabled:$externallyAccessible

# Grant each member of the old M365 group access to the SharedMailbox
foreach($m in $groupMembers){
    Add-MailboxPermission -Identity $groupName -User $m.Name -AccessRights FullAccess
}