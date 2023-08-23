param
(   
    [Parameter(Mandatory = $true)] [string] $UserPrincipalName
)

# Check if already connected to MSOnline, connect if not connected
try {
    Get-MsolDomain -ErrorAction Stop > $null
}
catch {
    Write-Host "Connecting to MsolService, check for a pop-up authentication window"
    Connect-MsolService
}

Write-Host "[MSONLINE] Processing licenses for user $($UserPrincipalName)..."
try { $user = Get-MsolUser -UserPrincipalName $UserPrincipalName -ErrorAction Stop }
catch {
    Write-Host "An error occurred:"
    Write-Host $_
 }

$SKUs = @($user.Licenses)
# if (!$SKUs) { Write-Host "No Licenses found for user $($user.UserPrincipalName), skipping..." ; continue }
if (!$SKUs) { 
    Write-Host "[MSONLINE] No Licenses found for user $($user.UserPrincipalName), skipping..." 
}

foreach ($SKU in $SKUs) {
    if (($SKU.GroupsAssigningLicense.Guid -ieq $user.ObjectId.Guid) -or (!$SKU.GroupsAssigningLicense.Guid)) {
        Write-Host "[MSONLINE] Removing license $($Sku.AccountSkuId) from user $($user.UserPrincipalName)"
        Set-MsolUserLicense -UserPrincipalName $user.UserPrincipalName -RemoveLicenses $SKU.AccountSkuId
    }
    else {
        Write-Host "[MSONLINE] License $($Sku.AccountSkuId) is assigned via Group, use the Azure AD blade to remove it!"
    }
}