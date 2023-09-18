<#
.SYNOPSIS
	Generate a report of Exchange mailboxes with useful properties

.DESCRIPTION
	This script uses Exchange Online cmdlets to extract mailbox properties and statistics that are helpful for at-a-glance reporting on an environment

.PARAMETER LargeMailboxesOnly
	Only report mailboxes that are larger than the specified $Threshold

.PARAMETER Threshold
	If LargeMailboxesOnly is specified, the size that determines what "large" is (ex: 40GB)

.PARAMETER SharedMailboxesOnly
	Only report on SharedMailboxes

.NOTES
	Author: Matt Stacey
	Date:   May 1, 2023
	Tags: 	#Exchange, 	#CloudManager, #FilePermissions
#>

function Get-EXOMailboxReport {
    param(
        [Bool]$LargeMailboxesOnly = $False,

        [SkyKickConditionalVisibility({
                param($LargeMailboxesOnly)
                return (
                ($LargeMailboxesOnly -eq $true)
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
        [String]$Threshold = "40GB",

        [Bool]$SharedMailboxesOnly = $False
	
    )

    $ClientName = (Get-CustomerContext).CustomerName
    $HTMLReportName = "$($ClientName) Exchange Mailbox Report"
    $HTMLReportFooter = "Report created using SkyKick Cloud Manager"
    
    $Mailboxes = Get-Mailbox -ResultSize Unlimited
    $results = @()

    foreach ( $Mailbox in $Mailboxes ) {
    
        $MailboxOutput = [PSCustomObject]@{
            DisplayName                   = $Mailbox.DisplayName
            PrimarySmtpAddress            = $Mailbox.PrimarySmtpAddress
            WhenMailboxCreated            = $Mailbox.WhenMailboxCreated
            IsMailboxEnabled              = $Mailbox.IsMailboxEnabled
            RecipientTypeDetails          = $Mailbox.RecipientTypeDetails
            HiddenFromAddressListsEnabled = $Mailbox.HiddenFromAddressListsEnabled
            ForwardingAddress             = $Mailbox.ForwardingAddress
            ForwardingSmtpAddress         = $Mailbox.ForwardingSmtpAddress
            ArchiveStatus                 = $Mailbox.ArchiveStatus
            AutoExpandingArchiveEnabled   = $Mailbox.AutoExpandingArchiveEnabled
            RetentionHoldEnabled          = $Mailbox.RetentionHoldEnabled
            TotalItemSize                 = ($Mailbox | Get-EXOMailboxStatistics | Select-Object -ExpandProperty TotalItemSize)
        }

        if ($SharedMailboxesOnly) {
            if ($LargeMailboxesOnly) {
                $LargeSharedMailboxes = $MailboxOutput | Where-Object { $_.RecipientTypeDetails -eq "SharedMailbox" -and [int64]($_.TotalItemSize.Value -replace '.+\(|bytes\)') -gt $Threshold }
                $results += $LargeSharedMailboxes
            }
            else {
                $SharedMailboxes = $MailboxOutput | Where-Object { $_.RecipientTypeDetails -eq "SharedMailbox" }
                $results += $SharedMailboxes
            }
        }
        elseif ($LargeMailboxesOnly) {
            $results += $MailboxOutput | Where-Object { [int64]($_.TotalItemSize.Value -replace '.+\(|bytes\)') -gt $Threshold }
        }

        else {
            $results += $MailboxOutput
        }


    }

    $results | Out-SkyKickTableToHtmlReport -IncludePartnerLogo -ReportTitle $HTMLReportName -ReportFooter $HTMLReportFooter -OutTo NewTab

}