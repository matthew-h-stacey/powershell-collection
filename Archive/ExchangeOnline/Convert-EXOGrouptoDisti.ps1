param(   
    # Group to be converted to a disti    
    [Parameter(Mandatory = $true)]
    [string]
    $PrimarySmtpAddress
)

$o365Group = Get-UnifiedGroup -Identity $PrimarySmtpAddress
$alias = $o365Group.Alias
$domain = $PrimarySmtpAddress.Split("@")[1]
$temporaryAlias = $PrimarySmtpAddress.Split("@")[0]+"tmp"
$temporaryAddress = "$temporaryAlias@$domain"

# 1) Create disti with temporary, alternate name

New-DistributionGroup -Name $temporaryAlias -Alias $temporaryAlias -Description $o365Group.Description -DisplayName $o365Group.DisplayName -ManagedBy $o365Group.ManagedBy -ModerationEnabled $o365Group.ModerationEnabled -PrimarySmtpAddress $temporaryAddress -RequireSenderAuthenticationEnabled $o365Group.RequireSenderAuthenticationEnabled 
Set-DistributionGroup -Identity $temporaryAlias -HiddenFromAddressListsEnabled $o365Group.HiddenFromAddressListsEnabled 

# 2) Match membership of O365 Group to disti 

$groupMembers = Get-UnifiedGroupLinks -Identity ($o365Group).Identity -LinkType Member
foreach ($m in $groupMembers) {
    Add-DistributionGroupMember -Identity $temporaryAlias -Member $m.PrimarySmtpAddress
}

# 4) Rename O365 Group (+ "OLD") and hide from GAL
$o365GroupDotOldAlias = $PrimarySmtpAddress.Split("@")[0] + "old"
$o365GroupDotOldEmail = "$o365GroupDotOldAlias@$domain"
Set-UnifiedGroup -Identity $o365GroupDotOldEmail -HiddenFromExchangeClientsEnabled:$true -HiddenFromAddressListsEnabled:$true
Set-UnifiedGroup -Identity $o365Group.Identity -PrimarySmtpAddress $o365GroupDotOldEmail
Set-UnifiedGroup -Identity $o365Group.Identity -EmailAddress @{remove = "SMTP:$PrimarySmtpAddress" }

# 5) Rename disti to use the required email address
Set-DistributionGroup -Identity $temporaryAddress -PrimarySmtpAddress $PrimarySmtpAddress -Alias $alias
Set-DistributionGroup -Identity $PrimarySmtpAddress -EmailAddress @{remove = "smtp:$temporaryAddress", "smtp:$temporaryAlias@$($o365Group.OrganizationalUnitRoot)"}
Set-DistributionGroup -Identity $PrimarySmtpAddress -EmailAddress @{add = "smtp:$alias@$($o365Group.OrganizationalUnitRoot)" }