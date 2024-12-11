function Get-EndpointManagerEnrollmentRestrictions {

    param (
        [Parameter(Mandatory = $true)]
        [CustomerContext[]]
        $Clients
    )

    $htmlReportName = "Endpoint Manager Enrollment Restrictions"
    $htmlReportFooter = "Report created using SkyKick Cloud Manager"
    $results = [System.Collections.Generic.List[System.Object]]::new()
    $reportParams = @{
        IncludePartnerLogo = $true
        ReportTitle        = $htmlReportName
        ReportFooter       = $htmlReportFooter
        OutTo              = "NewTab"
    }
    foreach ( $client in $Clients ) {
        Set-CustomerContext $client
        $platformRestrictions = Get-MgDeviceManagementDeviceEnrollmentConfiguration | Where-Object { $_.Id -like "*DefaultPlatformRestrictions" }
        $results.Add([PSCustomObject]@{
                ClientName             = (Get-CustomerContext).CustomerName
                AndroidPlatformBlocked = $platformRestrictions.AdditionalProperties.androidRestriction.platformBlocked
                AndroidPersonalBlocked = $platformRestrictions.AdditionalProperties.androidRestriction.personalDeviceEnrollmentBlocked
                AndroidMinVersion      = $platformRestrictions.AdditionalProperties.androidRestriction.osMinimumVersion
                AndroidMaxVersion      = $platformRestrictions.AdditionalProperties.androidRestriction.osMaximumVersion
                iOSPlatformBlocked     = $platformRestrictions.AdditionalProperties.iosRestriction.platformBlocked
                iOSPersonalBlocked     = $platformRestrictions.AdditionalProperties.iosRestriction.personalDeviceEnrollmentBlocked
                iOSMinVersion          = $platformRestrictions.AdditionalProperties.iosRestriction.osMinimumVersion
                iOSMaxVersion          = $platformRestrictions.AdditionalProperties.iosRestriction.osMaximumVersion
                MacOSXPlatformBlocked  = $platformRestrictions.AdditionalProperties.macOSRestriction.platformBlocked
                MacOSXPersonalBlocked  = $platformRestrictions.AdditionalProperties.macOSRestriction.personalDeviceEnrollmentBlocked
                MacOSXMinVersion       = "Not currently supported in Endpoint Manager"
                MacOSXMaxVersion       = "Not currently supported in Endpoint Manager"
                WindowsPlatformBlocked = $platformRestrictions.AdditionalProperties.windowsRestriction.platformBlocked
                WindowsPersonalBlocked = $platformRestrictions.AdditionalProperties.windowsRestriction.personalDeviceEnrollmentBlocked
                WindowsMinVersion      = $platformRestrictions.AdditionalProperties.windowsRestriction.osMinimumVersion
                WindowsMaxVersion      = $platformRestrictions.AdditionalProperties.windowsRestriction.osMaximumVersion
            })
    }
    $results | Out-SkyKickTableToHtmlReport @reportParams

}