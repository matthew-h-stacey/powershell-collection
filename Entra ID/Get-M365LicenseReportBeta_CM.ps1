function Get-M365LicenseReportBeta {

    [SkyKickCommand(DisplayName = "Set Parameter Sections", Sections = { "Client", "Scope" })]
    param (
        [SkyKickParameter(
            DisplayName = "Client",
            Section = "Client",
            DisplayOrder = 1
        )]
        [Parameter(Mandatory = $true)]
        [CustomerContext[]]
        $Clients,

        [SkyKickParameter(
            DisplayName = "Scope of the license report",
            HintText = "Select 'All' to report on all licenses, or use 'ExpiringSoonOnly' to retrieve only licenses that are expiring/renewing soon.",
            Section = "Scope",
            DisplayOrder = 1
        )]
        [Parameter (Mandatory = $true)]
        [ValidateSet("All", "ExpiringSoonOnly")]
        [String]
        $Scope,

        [SkyKickConditionalVisibility({
                param($Scope)
                return (
                ($Scope -eq "ExpiringSoonOnly")
                )
            },
            IsMandatoryWhenVisible = $true
        )]
        [SkyKickParameter(
            DisplayName = "Days threshold",
            HintText = "Enter the number of days to be considered 'soon' (ex: 90 for 90 days)",
            Section = "Scope",
            DisplayOrder = 2
        )]
        [int]
        $ThresholdDays = 30,

        [SkyKickParameter(
            DisplayName = "Underallocated SKUs only",
            HintText = "Excludes any SKUs where the quantity of assigned matches the quantity available (ex: 10 available, 10 assigned) for the purposes of finding underallocation",
            Section = "Scope",
            DisplayOrder = 3
        )]
        [boolean]
        $UnderallocatedSKUsOnly
    )

    $htmlReportName = "Microsoft 365 License Report"
    $htmlReportFooter = "Report created using SkyKick Cloud Manager"
    $results = [System.Collections.Generic.List[System.Object]]::new()
    $reportParams = @{
        IncludePartnerLogo = $true
        ReportTitle        = $htmlReportName
        ReportFooter       = $htmlReportFooter
        OutTo              = "NewTab"
    }
    $today = Get-Date
    $skusMappingTable = Get-Microsoft365LicensesMappingTable

    $Clients | ForEach-Object -Process {

        # Set the customer context to the selected customer
        Set-CustomerContext $_
        $clientName = (Get-CustomerContext).CustomerName

        $subs = Invoke-MgGraphRequest -Method get -Uri https://graph.microsoft.com/v1.0/directory/subscriptions
        $skus = Invoke-MgGraphRequest -Method get -Uri https://graph.microsoft.com/v1.0/subscribedSkus
        $subsArray = $subs.value
        $skusArray = $skus.value
        
        # if a sub was purchased twice (two diff resellers, etc.)
        # it will be present in $subs twice but once in $skus

        foreach ( $sub in $subsArray ) {
            # if-else to check the SKUsMappingTable for a friendly display name, otherwise sets the license name to be the SkuPartNumber
            if ( $SKUsMappingTable | Where-Object { $_.GUID -like $sub.skuId } | Select-Object DisplayName -Unique -ExpandProperty DisplayName ) {
                $licenseName = $SKUsMappingTable | Where-Object { $_.GUID -like $sub.skuId } | Select-Object DisplayName -Unique -ExpandProperty DisplayName
            } else {
                $licenseName = $sub.skuPartNumber
            }
            if ( $sub.nextLifecycleDateTime ) {
                $timespan = New-TimeSpan -Start $today -End $sub.nextLifecycleDateTime
                if ( $timespan -gt 0) {
                    $expiringSoon = $timespan.Days -le $ThresholdDays
                } elseif ( $timespan -lt 0 ) {
                    $expiringSoon = "Expired"
                }
            } else {
                $expiringSoon = "N/A"
            }

            # Locate all subs matching the SKU ID and add them to create the total
            # This is the value to subtract consumed units from, not PurchasedLicenses as that
            # is subscription-specific
            $totalLicenses = 0
            $subsArray | Where-Object { $_.skuid -like $sub.skuid -and $_.Status -like "Enabled" } | ForEach-Object {
                $totalLicenses += $_.totalLicenses
            }
            if ( $sub.Status -eq "Enabled" ) {
                $consumedUnits = ($skusArray | Where-Object { $_.skuId -like $sub.skuId }).consumedUnits
                $availableLicenses = $totalLicenses - $consumedUnits
            } else {
                $consumedUnits = "N/A"
                $availableLicenses = "N/A"
            }
            
            $licenseOutput = [pscustomobject]@{
                Client                = $clientName
                ProductName           = $licenseName
                PurchasedLicenses     = $sub.totalLicenses 
                TotalAssignedLicenses = $consumedUnits
                AvailableLicenses     = $availableLicenses
                Status                = $sub.status
                IsTrial               = $sub.isTrial
                DatedAdded            = $sub.createdDateTime
                NextLifecycleDate     = $sub.nextLifecycleDateTime
                ExpiringSoon          = $expiringSoon
            }
            
            # Conditionally output the results based on the scope
            switch ($Scope) {
                "All" {
                    # If 'UnderallocatedSKUsOnly' is true, only add when 'AvailableLicenses' is greater than 0
                    if ($UnderallocatedSKUsOnly) {
                        if ($licenseOutput.AvailableLicenses -gt 0) {
                            $results.Add($licenseOutput)
                        }
                    } else {
                        # Otherwise, just add everything
                        $results.Add($licenseOutput)
                    }
                }
                "ExpiringSoonOnly" {
                    if ($licenseOutput.expiringSoon -eq $True) {
                        # Only add EXPIRING, not expired items
                        if ( $licenseOutput.status -eq "Warning" -or $licenseOutput.status -eq "Enabled"  ) {
                            # If 'UnderallocatedSKUsOnly' is true, only add when 'AvailableLicenses' is greater than 0
                            if ($UnderallocatedSKUsOnly) {
                                if ($licenseOutput.AvailableLicenses -gt 0) {
                                    $results.Add($licenseOutput)
                                }
                            } else {
                                # Otherwise, just add all expiring items
                                $results.Add($licenseOutput)
                            }
                        }
                    }
                }
            }
        }
    }

    if ( $results ) {
        $results | Out-SkyKickTableToHtmlReport @ReportParams
    } else {
        Write-Output "[INFO] No output for selected client(s)"
    }
    
}