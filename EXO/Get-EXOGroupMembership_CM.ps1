function Get-EXOGroupMembership {

    [SkyKickCommand(DisplayName = "Set Parameter Sections", Sections = { "Distibution Groups", "Dynamic Distribution Groups", "Microsoft 365 Groups/Teams" })]
    param(
        ### Distibution groups
        [SkyKickParameter(
            DisplayName = "Distribution Group report",
            Section = "Distibution Groups",
            DisplayOrder = 1
        )]
        [Parameter(Mandatory = $false)]
        [boolean]
        $Distis,

        # Distibution groups optional: All
        [SkyKickConditionalVisibility({
                param($Distis)
                return (
                ($Distis -eq $true)
                )
            },
            IsMandatoryWhenVisible = $true
        )]
        [SkyKickParameter(
            DisplayName = "All Distribution Groups?",
            Section = "Distibution Groups",
            DisplayOrder = 2
        )]
        [boolean]
        $AllDistis = $true,

        # Distibution groups optional: Specific group
        [SkyKickConditionalVisibility({
                param($Distis, $AllDistis)
                return (
                ($Distis -eq $true) -and
                ($AllDistis -eq $false)
                )
            },
            IsMandatoryWhenVisible = $true
        )]
        [ArgumentCompleter({
            param ($CommandName, $ParameterName, $WordToComplete, $CommandAst, $FakeBoundParameters)

            $params = @{}
            if ( $WordToComplete ) {
                $params["Filter"] = "PrimarySmtpAddress -like '*" + $WordToComplete + "*'"
            }
            Get-DistributionGroup @params | Sort-Object PrimarySmtpAddress | ForEach-Object {
                New-SkyKickCompletionResult -Value $_.PrimarySmtpAddress -DisplayName $_.PrimarySmtpAddress
            }
        })] 
        [SkyKickParameter(
                DisplayName = "Distribution Group",
                Section = "Distibution Groups",
                DisplayOrder = 3
        )] 
        [string] $DistiSmtpAddress,

        ### Dynamic distribution groups
        [SkyKickParameter(
            DisplayName = "Dynamic Distribution Group report",
            Section = "Dynamic Distribution Groups",
            DisplayOrder = 1
        )]
        [Parameter(Mandatory = $false)]
        [boolean]
        $DynamicDLs,

        # Dynamic distribution groups optional: All
        [SkyKickConditionalVisibility({
                param($DynamicDLs)
                return (
                ($DynamicDLs -eq $true)
                )
            },
            IsMandatoryWhenVisible = $true
        )]
        [SkyKickParameter(
            DisplayName = "All Dynamic Distribution Groups?",
            Section = "Dynamic Distribution Groups",
            DisplayOrder = 2
        )]
        [boolean]
        $AllDynamicDistis = $true,

        # Dynamic distribution groups optional: Specific group
        [SkyKickConditionalVisibility({
                param($DynamicDLs, $AllDynamicDistis)
                return (
                ($DynamicDLs -eq $true) -and
                ($AllDynamicDistis -eq $false)
                )
            },
            IsMandatoryWhenVisible = $true
        )]
        [ArgumentCompleter({
            param ($CommandName, $ParameterName, $WordToComplete, $CommandAst, $FakeBoundParameters)

            $params = @{}
            if ( $WordToComplete ) {
                $params["Filter"] = "PrimarySmtpAddress -like '*" + $WordToComplete + "*'"
            }
            Get-DynamicDistributionGroup @params | Sort-Object PrimarySmtpAddress | ForEach-Object {
                New-SkyKickCompletionResult -Value $_.PrimarySmtpAddress -DisplayName $_.PrimarySmtpAddress
            }
        })] 
        [Parameter(Mandatory=$false)]
        [SkyKickParameter(
            DisplayName = "Dynamic Distribution Group",
            Section = "Dynamic Distribution Groups",
            DisplayOrder = 3
        )] 
        [String]
        $DynamicDLPrimarySmtpAddress,

        ### M365 Groups
        [SkyKickParameter(
            DisplayName = "Microsoft 365 Group report",
            Section = "Microsoft 365 Groups/Teams",
            DisplayOrder = 1
        )]
        [Parameter(Mandatory = $false)]
        [boolean]
        $M365Groups,

        # M365 Groups optional: All
        [SkyKickConditionalVisibility({
                param($M365Groups)
                return (
                ($M365Groups -eq $true)
                )
            },
            IsMandatoryWhenVisible = $true
        )]
        [SkyKickParameter(
            DisplayName = "All M365 Groups?",
            Section = "Microsoft 365 Groups/Teams",
            DisplayOrder = 2
        )]
        [boolean]
        $AllM365Groups = $true,

        # M365 Groups optional: Specific Group
        [SkyKickConditionalVisibility({
                param($M365Groups, $AllM365Groups)
                return (
                ($M365Groups -eq $true) -and
                ($AllM365Groups -eq $false)
                )
            },
            IsMandatoryWhenVisible = $true
        )]
        [ArgumentCompleter({
            param ($CommandName, $ParameterName, $WordToComplete, $CommandAst, $FakeBoundParameters)

            $params = @{}
            if ( $WordToComplete ) {
                $params["Filter"] = "PrimarySmtpAddress -like '*" + $WordToComplete + "*'"
            }
            Get-UnifiedGroup @params | Sort-Object PrimarySmtpAddress | ForEach-Object {
                New-SkyKickCompletionResult -Value $_.PrimarySmtpAddress -DisplayName $_.PrimarySmtpAddress
            }
        })]
        [SkyKickParameter(
            DisplayName = "Microsoft 365 Group",
            Section = "Microsoft 365 Groups/Teams",
            DisplayOrder = 3
        )] 
        [String]
        $M365GroupPrimarySmtpAddress
    )

    # Array to store all of the output of the reports
    $results = @()
    # Array to store the report types executed for a label on the report
    $reportType = @()

    if ( $Distis ) {
        switch ( $AllDistis ) {
            True {
                $membership = Get-EXODistributionGroupMembership -All
            }
            False {
                $membership = Get-EXODistributionGroupMembership -PrimarySmtpAddress $DistiSmtpAddress
            }
        }
        if ( $membership ) {
            $results += $membership
            $reportType += "DL"
        }
    }
    if ( $DynamicDLs ) {
        switch ( $AllDynamicDistis ) {
            True {
                $membership = Get-EXODynamicDistributionGroupMembership -All
            }
            False {
                $membership = Get-EXODynamicDistributionGroupMembership -PrimarySmtpAddress $DynamicDLPrimarySmtpAddress
            }
        }
        if ( $membership ) {
            $results += $membership
            $reportType += "DDL"
        }
    }
    if ( $M365Groups ) {
        switch ( $AllM365Groups ) {
            True {
                $membership = Get-EXOUnifiedGroupMembership -All
            }
            False {
                $membership = Get-EXOUnifiedGroupMembership -PrimarySmtpAddress $M365GroupPrimarySmtpAddress
            }
        }
        if ( $membership ) {
            $results += $membership
            $reportType += "Group"
        }
    }
    if ( $results ) {
        $reportTypeConcat = $reportType -join ", "
        $htmlReportName = "$($clientName) Group Membership Report ($reportTypeConcat)"
        $clientName = (Get-CustomerContext).CustomerName
        $htmlReportFooter = "Report created using SkyKick Cloud Manager"
        $results | Out-SkyKickTableToHtmlReport -IncludePartnerLogo -ReportTitle $htmlReportName -ReportFooter $htmlReportFooter -OutTo NewTab
    }
	
}