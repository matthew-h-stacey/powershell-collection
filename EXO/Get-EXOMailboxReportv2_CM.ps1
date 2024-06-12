function Get-EXOMailboxReportv2 {

    <#
    .DESCRIPTION
    This command contains a group of reports that can be selected using the interactive menu

    <h4>Mailbox Statistics Report</h4>

    Mailbox report reports can be generated on all mailboxes, or a few filtered types of mailboxes: mailboxes with forwarding enabled, large mailboxes only (customizable threshold), or shared mailboxes only.

    <h4>Mailbox Permissions Report</h4>
    
    A report of mailbox permissions be generated for all mailboxes or a particular mailbox. In addition, toggles to include contacts and calendar are available.    
    #>

    [SkyKickCommand(DisplayName = "Set Parameter Sections", Sections = { "Exchange mailbox report v2" })]
    param(
        [SkyKickParameter(
            DisplayName = "Client",
            Section = "Exchange mailbox report v2",
            DisplayOrder = 1
        )]
        [Parameter(Mandatory = $true)]
        [CustomerContext]
        $Client,

        ### Report type
        [SkyKickParameter(
            DisplayName = "Report Type",
            HintText = "Please select the type of Exchange Online mailbox report from the available options.",
            Section = "Exchange mailbox report v2",
            DisplayOrder = 2
        )]
        [Parameter(Mandatory = $true)]
        [ValidateSet("Mailbox report - All mailboxes", "Mailbox report - Forwarding mailboxes only", "Mailbox report - Large mailboxes only", "Mailbox report - Shared mailboxes only", "Mailbox permissions")]
        [string]
        $Choice,

        ### Conditional: Threshold
        [SkyKickConditionalVisibility({
                param($Choice)
                return (
                ($Choice -eq "Mailbox report - Large mailboxes only")
                )
            },
            IsMandatoryWhenVisible = $true
        )]
        [SkyKickParameter(
            DisplayName = "Threshold",
            HintText = "Enter the threshold of what is considered to be a large mailbox (ex: 40GB).",
            Section = "Exchange mailbox report v2",
            DisplayOrder = 3
        )]
        [ValidatePattern(
            '^\d+GB$',
            ErrorMessage = "Please enter the threshold in the following format: XGB/XXGB/XXXGB."
        )]
        [String]
        $Threshold = "40GB",
        
        ### Conditional: All mailboxes
        [SkyKickConditionalVisibility({
                param($Choice)
                return (
                ($Choice -eq "Mailbox permissions")
                )
            },
            IsMandatoryWhenVisible = $true
        )]
        [SkyKickParameter(
            DisplayName = "All mailboxes?"
        )]
        [boolean]
        $AllMailboxPermissions = $true,

        ### Conditional: PrimarySmtpAddress
        [SkyKickConditionalVisibility({
                param($Choice, $AllMailboxPermissions)
                return (
                ($Choice -eq "Mailbox permissions") -and
                ($AllMailboxPermissions -eq $false)
                )
            },
            IsMandatoryWhenVisible = $true
        )]
        [SkyKickParameter(
            DisplayName = "Mailbox",
            HintText = "Enter the PrimarySmtpAddress of a mailbox to run the permissions report on."
        )]
        [String]
        $PrimarySmtpAddress,

        ### Conditional: Calendars
        [SkyKickConditionalVisibility({
                param($Choice)
                return (
                ($Choice -eq "Mailbox permissions")
                )
            },
            IsMandatoryWhenVisible = $true
        )]
        [SkyKickParameter(
            DisplayName = "Include calendars in permission report?"
        )]
        [boolean]
        $Calendar = $true,

        ### Conditional: Contacts
        [SkyKickConditionalVisibility({
                param($Choice)
                return (
                ($Choice -eq "Mailbox permissions")
                )
            },
            IsMandatoryWhenVisible = $true
        )]
        [SkyKickParameter(
            DisplayName = "Include contacts in permission report?"
        )]
        [boolean]
        $Contacts = $true
    )

    Set-CustomerContext $Client
    $clientName = (Get-CustomerContext).CustomerName
    $htmlReportFooter = "Report created using SkyKick Cloud Manager"

    switch ( $Choice ) { 
        "Mailbox report - All mailboxes" {
            $htmlReportName = "$($clientName) Mailbox Report"
            $results = Get-EXOMailboxInformation -Scope All
        }
        "Mailbox report - Forwarding mailboxes only" {
            $htmlReportName = "$($clientName) Forwarding Mailbox Report"
            $results = Get-EXOMailboxInformation -Scope ForwardingMailboxes
        }
        "Mailbox report - Large mailboxes only" {
            $htmlReportName = "$($clientName) Large Mailbox Report"
            $results = Get-EXOMailboxInformation -LargeMailboxesOnly -Threshold $Threshold
        }
        "Mailbox permissions" {
            $htmlReportName = "$($clientName) Mailbox Permissions Report"
            $results = Get-EXOMailboxPermissionReport -PrimarySmtpAddress $PrimarySmtpAddress -CloudManager -Calendar $Calendar -Contacts $Contacts
        }
        "Mailbox report - Shared mailboxes only" {
            $htmlReportName = "$($clientName) Shared Mailbox Report"
            $results = Get-EXOMailboxInformation -Scope SharedMailboxes
        }
    }

    $results | Out-SkyKickTableToHtmlReport -IncludePartnerLogo -ReportTitle $htmlReportName -ReportFooter $htmlReportFooter -OutTo NewTab

}