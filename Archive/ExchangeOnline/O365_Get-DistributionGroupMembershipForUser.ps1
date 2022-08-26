cls
Write-Host "Determine all distribution groups a user is a member of"
$User = Read-Host "Enter full email address for user to search"
$DistributionGroups = Get-DistributionGroup | where { (Get-DistributionGroupMember $_.Name | foreach {$_.PrimarySmtpAddress}) -contains "$User"}
$DistributionGroups