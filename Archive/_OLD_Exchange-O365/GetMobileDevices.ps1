$results = @()
$allMailboxesUPN = Get-EXOMailbox -ResultSize Unlimited | Sort-Object UserPrincipalName | Select-Object  -ExpandProperty UserPrincipalName
foreach ($mailbox in $allMailboxesUPN) {
    $mobileUser = Get-EXOMobileDeviceStatistics -UserPrincipalName $mailbox
    foreach($phone in $mobileUser){
        $mobileCustomObject = [PSCustomObject]@{
            User            = $mailbox
            LastSuccessSync = $phone.LastSuccessSync
            DeviceModel     = $phone.DeviceModel
            DeviceOS        = $phone.DeviceOS 
        }
        $results += $mobileCustomObject
    }
}
$results
# Stale devices: $results | ?{$_.LastSuccessSync -lt (get-date).adddays(-90)} | sort LastSuccessSync -Descending