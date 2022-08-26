# Adjust variables as needed
# LicenseAssignment is determined by MsolAccountSku's available on tenenat (Get-MsolAccountSku)

$Users | foreach { New-MsolUser -DisplayName $_.DisplayName -FirstName $_.FirstName -LastName $_.LastName -UserPrincipalName $_.UserPrincipalName -PasswordNeverExpires:$true -StrongPasswordRequired:$true -LicenseAssignment $_.LicenseAssignment -UsageLocation US}