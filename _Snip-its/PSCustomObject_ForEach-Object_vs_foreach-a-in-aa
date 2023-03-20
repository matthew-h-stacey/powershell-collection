# Avoid this method as it initializes LicenseUsage unnecessarily, then uses another variable and foreach loop that just creates extra steps. It also requires continuously calling the variable in order to access its properties

$LicenseUsage = @()
$LicenseConsumption = Get-MsolAccountSku
foreach ( $SKU in $LicenseConsumption ) {
    $LicenseUsage += [PSCustomObject] @{
        License  = $SKU.SkuPartNumber
        Quantity = $SKU.ActiveUnits
        Applied  = $SKU.ConsumedUnits
        Expiring = $SKU.WarningUnits
    }
}

# Instead, try the following method which initializes LicenseUsage with the actual objects, then immediately pipes to a ForEach-Object to process the items. The creation of the PSCustomObject in this example is much easier and cleaner

$LicenseUsage = Get-MsolAccountSku | ForEach-Object {
    [PSCustomObject] @{
        License  = $_.SkuPartNumber
        Quantity = $_.ActiveUnits
        Applied  = $_.ConsumedUnits
        Expiring = $_.WarningUnits
    }
}

