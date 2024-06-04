<#
.SYNOPSIS
This script creates a report with mailbox and recipient permissions for either a single mailbox, or all mailboxes. Note that this report excludes "SELF," therefore it only shows custom permissions. If a mailbox is not listed, it does not have custom permissions applied

.EXAMPLE
Get-EXOMailboxPermissionReport -PrimarySmtpAddress jsmith@contoso.com
#>

function Get-EXOMailboxPermissionReport {
    param(
        # Optional: Specify one mailbox. If left blank the report will run on every mailbox
        [Parameter(Mandatory=$false)]
        [String]
        $PrimarySmtpAddress,

        # Path to export the report to
        [Parameter(Mandatory=$true)]
        [String]
        $ExportPath
    )
    
    $ExportPath = $($ExportPath.TrimEnd("\")) # trim trailing "\""
    $results = [System.Collections.ArrayList]@()

    if ( $PrimarySmtpAddress ) {
        try { 
            $outputFile = "$ExportPath\$PrimarySmtpAddress_EXOMailboxPermissionReport.csv"
            $dataInput = Get-Mailbox $PrimarySmtpAddress -ErrorAction Stop
        } catch {
            Write-Output "[ERROR] Unable to find mailbox: $PrimarySmtpAddress. Please double check the value provided and try again"
            exit
        }
    } else {
        $primaryDomain = Get-AcceptedDomain | Where-Object { $_.Default -eq $true } | Select-Object -ExpandProperty DomainName
        $outputFile = "$ExportPath\${primaryDomain}_EXOMailboxPermissionReport.csv"
        $dataInput = Get-Mailbox -ResultSize Unlimited
    }

    $dataInput | ForEach-Object {
        $displayName = $_.DisplayName
        $userPrincipalName = $_.UserPrincipalName
        $mailboxPermissions = Get-MailboxPermission -Identity $_.Identity | Where-Object { $_.User -notlike "*SELF" }
        $recipientPermissions = Get-RecipientPermission -Identity $_.Identity | Where-Object { $_.Trustee -notlike "*SELF" }

        $mailboxPermissions | ForEach-Object {
            $mailboxOutput = [PSCustomObject]@{
                DisplayName = $displayName
                Mailbox     = $userPrincipalName
                Trustee     = $_.User
                Permission  = [string]$_.AccessRights
            }
            $results.Add($mailboxOutput) | Out-Null
        }

        $recipientPermissions | ForEach-Object {
            $mailboxOutput = [PSCustomObject]@{
                DisplayName = $displayName
                Mailbox     = $userPrincipalName
                Trustee     = $_.Trustee
                Permission  = [string]$_.AccessRights
            }
            $results.Add($mailboxOutput) | Out-Null
        }
    }

    $results | Export-Csv -Path $outputFile

}
