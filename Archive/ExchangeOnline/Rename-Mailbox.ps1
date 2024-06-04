$oldUPN = "socialmedia@contoso.com"
$newUPN = "resources@contoso.com"
$newDisplayName = "Resources"

Connect-MsolService
Connect-ExchangeOnline

Set-MsolUserPrincipalName -UserPrincipalName $oldUPN -NewUserPrincipalName $newUPN
Set-Mailbox -Identity $newUPN -DisplayName $newDisplayName -Name $newDisplayName

# Note that by renaming a user it will add the new UPN as the primary email address to the EmailAddresses value ("SMTP:$newUPN") while making the old UPN an alias ("smtp:$oldUPN")