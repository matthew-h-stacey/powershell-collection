function Get-EXOMailboxReportv2 {
    param(
        ### Report type
        [SkyKickParameter(
            DisplayName = "Report Type",
            HintText = "Please select the type of Exchange Online mailbox report from the available options."
        )]
        [Parameter(Mandatory = $true)]
        [ValidateSet("All", "Forwarding mailboxes only", "Large mailboxes only", "Permissions report", "Shared mailboxes only")]
        [string]
        $Choice,

        ### Conditional: Threshold
        [SkyKickConditionalVisibility({
                param($Choice)
                return (
                ($Choice -eq "Large mailboxes only")
                )
            },
            IsMandatoryWhenVisible = $true
        )]
        [SkyKickParameter(
            DisplayName = "Threshold",
            HintText = "Enter the threshold of what is considered to be a large mailbox (ex: 40GB)."
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
                ($Choice -eq "Permissions report")
                )
            },
            IsMandatoryWhenVisible = $true
        )]
        [SkyKickParameter(
            DisplayName = "All mailboxes?"
        )]
        [boolean]
        $AllMailboxPermissions=$true,

        ### Conditional: PrimarySmtpAddress
        [SkyKickConditionalVisibility({
                param($Choice, $AllMailboxPermissions)
                return (
                ($Choice -eq "Permissions report") -and
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
                ($Choice -eq "Permissions report")
                )
            },
            IsMandatoryWhenVisible = $true
        )]
        [SkyKickParameter(
            DisplayName = "Include calendars in permission report?"
        )]
        [boolean]
        $Calendar=$true,

        ### Conditional: Contacts
        [SkyKickConditionalVisibility({
                param($Choice)
                return (
                ($Choice -eq "Permissions report")
                )
            },
            IsMandatoryWhenVisible = $true
        )]
        [SkyKickParameter(
            DisplayName = "Include contacts in permission report?"
        )]
        [boolean]
        $Contacts=$true
    )

    $clientName = (Get-CustomerContext).CustomerName
    $htmlReportName = "$($clientName) Exchange Mailbox Report"
    $htmlReportFooter = "Report created using SkyKick Cloud Manager"

    switch ( $Choice ) { 
        "All" {
            $results = Get-EXOMailboxInformation -Scope All
        }
        "Forwarding mailboxes only" {
            $results = Get-EXOMailboxInformation -Scope ForwardingMailboxes
        }
        "Large mailboxes only" {
            #$results = Get-EXOMailboxInformation -Scope All | Where-Object { [int64]($_.MailboxSize.Value -replace '.+\(|bytes\)') -gt $Threshold }
            $results = Get-EXOMailboxInformation -LargeMailboxesOnly -Threshold $Threshold
        }
        "Permissions report" {
            $results = Get-EXOMailboxPermissionReport -PrimarySmtpAddress $PrimarySmtpAddress -CloudManager -Calendar $Calendar -Contacts $Contacts
        }
        "Shared mailboxes only" {
            $results = Get-EXOMailboxInformation -Scope SharedMailboxes
        }
    }

    $results | Out-SkyKickTableToHtmlReport -IncludePartnerLogo -ReportTitle $htmlReportName -ReportFooter $htmlReportFooter -OutTo NewTab

}