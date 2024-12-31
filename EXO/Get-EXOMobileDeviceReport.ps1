function Get-EXOMobileDeviceReport {


    $clientName = (Get-CustomerContext).CustomerName
    $results = [System.Collections.Generic.List[System.Object]]::new()
    $htmlReportName = "$clientName Mobile Device Report"
    $htmlReportFooter = "Report created using SkyKick Cloud Manager"
    $reportParams = @{
        IncludePartnerLogo = $true
        ReportTitle        = $htmlReportName
        ReportFooter       = $htmlReportFooter
        OutTo              = "NewTab"
    }

    $mailboxes = Get-Mailbox -ResultSize Unlimited
    foreach ($mailbox in $mailboxes) {
        $upn = $mailbox.UserPrincipalName
        try {
            $mobileDevices = Get-MobileDeviceStatistics -Mailbox $upn -ErrorAction Stop
            foreach ($device in $mobileDevices) {
                $results.Add([PSCustomObject]@{
                        User            = $upn
                        DeviceType      = $device.DeviceType
                        DeviceUserAgent = $device.DeviceUserAgent
                        DeviceModel     = $device.DeviceModel
                        DeviceOS        = $device.DeviceOS
                        FirstSync       = $device.FirstSyncTime
                        LastSuccessSync = $device.LastSuccessSync
                    })
            }
        } catch {
            # No mobile devices
        }
    }

    $results | Out-SkyKickTableToHtmlReport @reportParams
	
}