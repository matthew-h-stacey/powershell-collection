function Get-M365LicenseReport {

    # Uses both Get-MsolAccountSku and Get-MsolSubscription to get both the usage and expiration of licenses

    # Initial variables
    $ClientDisplayName = (Get-MgOrganization).DisplayName
    $SKUsMappingTable = Get-Microsoft365LicensesMappingTable

    # Retrieve all licenses and their usage statistics
    $LicenseUsage = Get-MsolAccountSku | ForEach-Object {
        [PSCustomObject] @{
            License  = $_.SkuPartNumber
            Quantity = $_.ActiveUnits
            Applied  = $_.ConsumedUnits
            Expiring = $_.WarningUnits
        }
    }

    # Iterate through all subscriptions and retrieve relevant properties for output
    $AllLicenses = Get-MsolSubscription | Select-Object SkuPartNumber, Status, DateCreated, IsTrial, NextLifecycleDate, TotalLicenses
    $results = @()
    foreach ( $License in $AllLicenses ) {

        # if-else to check the SKUsMappingTable for a friendly display name, otherwise sets the license name to be the SkuPartNumber
        if ( $null -ne ($SKUsMappingTable | Where-Object { $_.SkuPartNumber -like $License.SkuPartNumber })) {
            $LicenseName = $SKUsMappingTable | Where-Object { $_.SkuPartNumber -like $License.SkuPartNumber } | Select-Object -ExpandProperty DisplayName
        }
        else {
            $LicenseName = $License.SkuPartNumber
        }

        # Quantity and applied licenses
        $Quantity = $License.TotalLicenses
        $Applied = ($LicenseUsage | Where-Object { $_.License -contains $License.SkuPartNumber }).Applied

        # Custom formatting for outputting to the report
        $results += [PSCustomObject] @{
            License    = $LicenseName
            Valid      = $License.Status
            Trial      = $License.IsTrial
            Expired    = if ( $License.NextLifecycleDate ) { ((New-TimeSpan -Start (Get-Date) -End ($License.NextLifecycleDate)).Days -lt 0) } else { "Perpetual" }
            Expiration = if ($License.NextLifecycleDate) { $License.NextLifecycleDate } else { "Perpetual" }
            Quantity   = $Quantity
            Applied    = $Applied
            Available  = $Quantity - $Applied
        }
    }
       
    $results | Sort-Object License | Out-SkyKickTableToHtmlReport -IncludePartnerLogo -ReportTitle "$($ClientDisplayName) M365 License Report" -ReportFooter "Report created using SkyKick Cloud Manager" -OutTo NewTab

}