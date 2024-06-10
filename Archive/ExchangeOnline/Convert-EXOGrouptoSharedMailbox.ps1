param(   
    [Parameter(Mandatory = $true)]
    [string]
    $GroupName,
    
    [Parameter(Mandatory = $true)]
    [boolean]
    $ExternallyAccessible
)

try {
    $group = Get-UnifiedGroup $GroupName -ErrorAction Stop
} catch {
    Write-Output "[ERROR] Group not found. Please check that the provided name is correct and try again"
    exit
}

# Vanity domain
$domain = $group.PrimarySmtpAddress.Split("@")[1]

# Variables for the renamed group and email
$groupRenamedDN = $GroupName + "_OLD" 
$groupRenamedEmail = $groupRenamedDN + "@" + $domain

# Back up properties of the group to be converted and its members
$group | Select-Object *  | out-file "C:\TempPath\${groupName}_Backup_Properties.txt"
$groupMembers = Get-UnifiedGroupLinks -Identity $GroupName -LinkType members
$groupMembers | out-file C:\TempPath\${groupName}_Backup_Members.txt

# Rename the current group and hide it from view, export new properties of the group
Set-UnifiedGroup $group.Name -DisplayName $groupRenamedDN -Alias $groupRenamedDN -PrimarySmtpAddress $groupRenamedEmail-HiddenFromExchangeClientsEnabled:$true -HiddenFromAddressListsEnabled:$true Set-UnifiedGroup $groupRenamedDN -EmailAddresses @{Remove = "$group.PrimarySmtpAddress" }
Get-UnifiedGroup $groupRenamedDN | Select-Object *  | out-file "C:\TempPath\${groupName}_Updated_Properties.txt"

# Created a new SharedMailbox using the old Name/DisplayName/PrimarySmtpAddress of the M365 Group
New-Mailbox -Shared -Name $GroupName -DisplayName $GroupName -PrimarySmtpAddress $group.PrimarySmtpAddress -RequireSenderAuthenticationEnabled:$ExternallyAccessible

# Grant each member of the old M365 group access to the SharedMailbox
foreach($m in $groupMembers){
    Add-MailboxPermission -Identity $GroupName -User $m.Name -AccessRights FullAccess
}