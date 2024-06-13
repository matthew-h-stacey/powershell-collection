function Get-EXOGroupMembership {
    param(
        [SkyKickParameter(
            DisplayName = "Distribution Groups"
        )]
        [Parameter(Mandatory = $false)]
        [boolean]
        $Distis,

        [SkyKickParameter(
            DisplayName = "Dynamic Distribution Groups"
        )]
        [Parameter(Mandatory = $false)]
        [boolean]
        $DynamicDLs,

        [SkyKickParameter(
            DisplayName = "Microsoft 365 Groups"
        )]
        [Parameter(Mandatory = $false)]
        [boolean]
        $M365Groups
    )

    # Array to store all of the output of the reports
    $results = New-Object System.Collections.ArrayList
    # Array to store the report types executed for a label on the report
    $reportType = New-Object System.Collections.ArrayList

    if ( $Distis ) {
        $membership = Get-EXODistributionGroupMembership
        if ( $membership ) {
            $results.Add($membership)
        }
        $reportType.Add("DL")
    }
    if ( $DynamicDLs ) {
        $membership = Get-EXODynamicDistributionGroupMembership
        if ( $membership ) {
            $results.Add($membership)
        }
        $reportType.Add("DDL")
    }
    if ( $M365Groups ) {
        $membership = Get-EXOUnifiedGroupMembership
        if ( $membership ) {
            $results.Add($membership)
        }
        $reportType.Add("Group")
    }
    if ( $results ) {
        $reportTypeConcat = $reportType -join ", "
        $htmlReportName = "$($clientName) Group Membership Report ($reportTypeConcat)"
        $clientName = (Get-CustomerContext).CustomerName
        $htmlReportFooter = "Report created using SkyKick Cloud Manager"
        $results | ForEach-Object {
            $_ | Out-SkyKickTableToHtmlReport -IncludePartnerLogo -ReportTitle $htmlReportName -ReportFooter $htmlReportFooter -OutTo NewTab
        }
    }
	
}