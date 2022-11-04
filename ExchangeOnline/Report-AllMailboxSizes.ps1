# Retrieve all mailbox information necessary
$allMailbox = Get-EXOMailbox -ResultSize Unlimited
$allMailboxStats = $allMailbox | Get-EXOMailboxStatistics

$results = @()
foreach ($m in $allMailboxStats){
    $UPN = (Get-Mailbox $m.DisplayName).UserPrincipalName
    $TotalItemSize = [string]$m.TotalItemSize.Value
    $prohibitSendSize       = Get-Mailbox -Identity $m.DisplayName | select -ExpandProperty ProhibitSendQuota
    $ProhibitSendQuota = [string]$prohibitSendSize
    $userExport = [PSCustomObject]@{
        UserPrincipalName           =   $UPN
        DisplayName                 =   $m.DisplayName   
        TotalItemSize               =   $TotalItemSize.Split("(")[0] 
        ProhibitSendQuota           =   $ProhibitSendQuota.Split("(")[0] 
    }
    $results += $userExport
}
$results | Export-Csv $output\AllMailboxes.csv -NoTypeInformation