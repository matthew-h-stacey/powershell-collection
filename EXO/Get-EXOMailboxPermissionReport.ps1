<#
.SYNOPSIS
This script creates a report with mailbox and recipient permissions for either a single mailbox, or all mailboxes. Note that this report excludes "SELF," therefore it only shows custom permissions. If a mailbox is not listed, it does not have custom permissions applied

.PARAMETER PrimarySmtpAddress
Optional: Specify one mailbox. If left blank the report will run on every mailbox

.PARAMETER Calendar
Optional: Include calendar permissions

.PARAMETER Contacts
Optional: Include contact permissions

.PARAMETER CloudManager
Used when running the script from SkyKick Cloud Manager

.PARAMETER ExportPath
Used when running the script outside of SkyKick Cloud Manager. This is the local directory to export the script output to

.EXAMPLE
Get-EXOMailboxPermissionReport -PrimarySmtpAddress jsmith@contoso.com
#>

function Get-EXOMailboxPermissionReport {

    param(
        
        [Parameter(Mandatory = $false)]
        [string]
        $PrimarySmtpAddress,

        [Parameter(Mandatory = $false)]
        [boolean]
        $Calendar,

        [Parameter(Mandatory = $false)]
        [boolean]
        $Contacts,

        [Parameter(Mandatory = $true, ParameterSetName = "CloudManager")]
        [switch]
        $CloudManager,

        [Parameter(Mandatory = $true, ParameterSetName = "Local")]
        [string]
        $ExportPath

    )

    $results = [System.Collections.ArrayList]@()

    if ( $PrimarySmtpAddress ) {
        # Filter by a single mailbox
        try { 
            $mailboxes = Get-Mailbox $PrimarySmtpAddress -ErrorAction Stop
        } catch {
            Write-Output "[ERROR] Unable to find mailbox: $PrimarySmtpAddress. Please double check the value provided and try again"
            exit
        }
    } else {
        # Run on all mailboxes. Retrieve primary domain to use in export file name
        $mailboxes = Get-Mailbox -ResultSize Unlimited
    }

    # Start processing mailboxes
    $mailboxes | ForEach-Object {
        $displayName = $_.DisplayName
        $userPrincipalName = $_.UserPrincipalName

        # Get mailbox permissions
        Get-MailboxPermission -Identity $_.Identity | Where-Object { $_.User -notlike "*SELF" } | ForEach-Object {
            $mailboxOutput = [PSCustomObject]@{
                DisplayName = $displayName
                Mailbox     = $userPrincipalName
                Type        = "Mailbox"
                Trustee     = $_.User
                Permission  = [string]$_.AccessRights
            }
            $results.Add($mailboxOutput) | Out-Null
        }

        # Get recipient permissions
        Get-RecipientPermission -Identity $_.Identity | Where-Object { $_.Trustee -notlike "*SELF" } | ForEach-Object {
            $mailboxOutput = [PSCustomObject]@{
                DisplayName = $displayName
                Mailbox     = $userPrincipalName
                Type        = "RecipientPermissions"
                Trustee     = $_.Trustee
                Permission  = [string]$_.AccessRights
            }
            $results.Add($mailboxOutput) | Out-Null
        }

        # Optional: Get calendar permissions
        if ( $Calendar ) {
            Get-MailboxFolderPermission -Identity ${userPrincipalName}:\Calendar | ForEach-Object {
                $mailboxOutput = [PSCustomObject]@{
                    DisplayName = $displayName
                    Mailbox     = $userPrincipalName
                    Type        = "Calendar"
                    Trustee     = $_.User.DisplayName
                    Permission  = [string]$_.AccessRights
                }
                $results.Add($mailboxOutput) | Out-Null
            }
        }

        # Optional: Get contacts permissions
        if ( $Contacts ) {
            Get-MailboxFolderPermission -Identity ${userPrincipalName}:\Contacts | ForEach-Object {
                $mailboxOutput = [PSCustomObject]@{
                    DisplayName = $displayName
                    Mailbox     = $userPrincipalName
                    Type        = "Contacts"
                    Trustee     = $_.User.DisplayName
                    Permission  = [string]$_.AccessRights
                }
                $results.Add($mailboxOutput) | Out-Null
            }
        }
    }

    switch ($PSCmdlet.ParameterSetName) {
        "CloudManager" {
            $reportTitle = "$($clientName) Exchange Mailbox Permission Report"
            $reportFooter = "Report created using SkyKick Cloud Manager"
            $clientName = (Get-CustomerContext).CustomerName
            if ( $results ) {
                $results | Out-SkyKickTableToHtmlReport -IncludePartnerLogo -ReportTitle $reportTitle -ReportFooter $reportFooter -OutTo NewTab
            }
        }
        "Local" {
            $ExportPath = $($ExportPath.TrimEnd("\")) # trim trailing "\"
            if ( $PrimarySmtpAddress ) {
                $outputFile = "$ExportPath\${PrimarySmtpAddress}_EXOMailboxPermissionReport.csv"
            } else {
                $primaryDomain = Get-AcceptedDomain | Where-Object { $_.Default -eq $true } | Select-Object -ExpandProperty DomainName
                $outputFile = "$ExportPath\${primaryDomain}_EXOMailboxPermissionReport.csv"
            }
            if ( $results ) {
                $results | Export-Csv -Path $outputFile -NoTypeInformation
                Write-Output "[INFO] Report exported to: $outputFile"
            }
        }
    }

}