param
(   
    [Parameter(Mandatory = $true)] [string] $PrimarySmtpAddress # Group to be converted to a disti
)

$O365Group = Get-UnifiedGroup -Identity $PrimarySmtpAddress
$Alias = $O365Group.Alias
$domain = $PrimarySmtpAddress.Split("@")[1]
$temporaryAlias = $PrimarySmtpAddress.Split("@")[0]+"tmp"
$temporaryAddress = "$temporaryAlias@$domain"

# 1) Create disti with temporary, alternate name

New-DistributionGroup -Name $temporaryAlias -Alias $temporaryAlias -Description $O365Group.Description -DisplayName $O365Group.DisplayName -ManagedBy $O365Group.ManagedBy -ModerationEnabled $O365Group.ModerationEnabled -PrimarySmtpAddress $temporaryAddress -RequireSenderAuthenticationEnabled $o365Group.RequireSenderAuthenticationEnabled 
Set-DistributionGroup -Identity $temporaryAlias -HiddenFromAddressListsEnabled $O365Group.HiddenFromAddressListsEnabled 

# 2) Match membership of O365 Group to disti 

$groupMembers = Get-UnifiedGroupLinks -Identity ($O365Group).Identity -LinkType Member
    foreach ($m in $groupMembers) {
        Add-DistributionGroupMember -Identity $temporaryAlias -Member ($m.PrimarySmtpAddress)
        }

# 4) Rename O365 Group (+ "OLD") and hide from GAL
$O365GroupDotOldAlias = $PrimarySmtpAddress.Split("@")[0] + "old"
$O365GroupDotOldEmail = "$O365GroupDotOldAlias@$domain"
Set-UnifiedGroup -Identity $O365GroupDotOldEmail -HiddenFromExchangeClientsEnabled:$true -HiddenFromAddressListsEnabled:$true

# Set-Group -Identity $O365Group.Identity -WindowsEmailAddress $O365GroupDotOldEmail
Set-UnifiedGroup -Identity ($O365Group).Identity -PrimarySmtpAddress $O365GroupDotOldEmail
Set-UnifiedGroup -Identity $O365Group.Identity -EmailAddress @{remove = "SMTP:$PrimarySmtpAddress" }

# 5) Rename disti to use the required email address
Set-DistributionGroup -Identity $temporaryAddress -PrimarySmtpAddress $PrimarySmtpAddress -Alias $Alias
Set-DistributionGroup -Identity $PrimarySmtpAddress -EmailAddress @{remove = "smtp:$temporaryAddress", "smtp:$temporaryAlias@$($O365Group.OrganizationalUnitRoot)"}
Set-DistributionGroup -Identity $PrimarySmtpAddress -EmailAddress @{add = "smtp:$Alias@$($O365Group.OrganizationalUnitRoot)" }