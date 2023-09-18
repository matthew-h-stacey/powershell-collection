function Get-EXOMailboxPermissionReport {
    param(
    )

    $results = [System.Collections.ArrayList]@()
    $ClientName = (Get-CustomerContext).CustomerName

    Get-Mailbox -ResultSize Unlimited | ForEach-Object {
        $DisplayName = $_.DisplayName
        $UserPrincipalName = $_.UserPrincipalName
        $MailboxPermissions = Get-MailboxPermission -Identity $_.Identity | Where-Object { $_.User -notlike "*SELF" }
        $RecipientPermissions = Get-RecipientPermission -Identity $_.Identity | Where-Object { $_.Trustee -notlike "*SELF" }

        $MailboxPermissions | ForEach-Object {
            $MailboxOutput = [PSCustomObject]@{
                DisplayName = $DisplayName
                Mailbox     = $UserPrincipalName
                Trustee     = $_.User
                Permission  = [string]$_.AccessRights
            }
            $results.Add($MailboxOutput) | Out-Null
        }

        $RecipientPermissions | ForEach-Object {
            $MailboxOutput = [PSCustomObject]@{
                DisplayName = $DisplayName
                Mailbox     = $UserPrincipalName
                Trustee     = $_.Trustee
                Permission  = [string]$_.AccessRights
            }
            $results.Add($MailboxOutput) | Out-Null
        }
    }

    $reportTitle = "$($ClientName) Exchange Mailbox Permission Report"
    $reportFooter = "Report created using SkyKick Cloud Manager"
    $results | Out-SkyKickTableToHtmlReport -IncludePartnerLogo -ReportTitle $reportTitle -ReportFooter $reportFooter -OutTo NewTab

}
