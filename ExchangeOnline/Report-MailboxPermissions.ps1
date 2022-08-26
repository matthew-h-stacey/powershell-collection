<#
Objective: Get a report of any custom* mailbox permissions for a specified group of mailboxes, or ALL mailboxes

* Meaning any permissions that are not for the SELF user
#>

$output = "C:\TempPath\MailboxPermissionsReport.csv"


$allMailboxes = Get-Mailbox -ResultSize Unlimited | Sort-Object PrimarySmtpAddress | Select-Object -ExpandProperty PrimarySmtpAddress

$results = @()
foreach ($u in $allMailboxes){
    $output = Get-MailboxPermission $u | Where-Object { $_.User -notLike "NT AUTHORITY\SELF" } | Select-Object Identity,User,AccessRights
    $results += $output
}
$results | Export-Csv $output -NoTypeInformation