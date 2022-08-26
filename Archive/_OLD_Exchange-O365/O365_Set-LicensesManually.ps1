# List Services available for <SKU>
Get-MsolAccountSku | Select -ExpandProperty ServiceStatus

# Get AccountSkuID
$AcctSkuID = Get-MsolAccountSku | Select-Object -ExpandProperty AccountSkuID

# Determine what packages need to be disabled, corresponding to the service name itself
# https://docs.microsoft.com/en-us/office365/enterprise/powershell/view-licenses-and-services-with-office-365-powershell or # https://docs.microsoft.com/en-us/azure/active-directory/active-directory-licensing-product-and-service-plan-reference
# Note those for the next step where the LicensingOption is created with the "DisabledPlans" parameter set to the services noted

$LO = New-MsolLicenseOptions -AccountSkuId <AccountSkuId> -DisabledPlans "<UndesirableService1>", "<UndesirableService2>"…

# Apply the licensing options to one user as a test ...
Set-MsolUserLicense -UserPrincipalName <Account> -LicenseOptions $LO

# ... and verify it applied correctly
(Get-MsolUser -UserPrincipalName user@domain.com).Licenses.ServiceStatus

# Optional: to apply the $LO variable to all users
# $AllLicensedUsers = Get-MsolUser -All | where { $_.IsLicensed -eq $true and $_.Licenses.AccountSkuID -eq  $AcctSkuID }
# $AllLicensedUsers | foreach { Set-MsolUserLicense -UserPrincipalName $_.UserPrincipalName -LicenseOptions $LO }