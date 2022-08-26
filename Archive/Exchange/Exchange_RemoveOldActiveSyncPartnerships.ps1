# Get all ActiveSync partnerships and export to a CSV
$AllActiveSyncPartnerships = Get-CASMailbox -Filter {hasactivesyncdevicepartnership -eq $true -and -not displayname -like "CAS_{*"} | Get-Mailbox
$AllActiveSyncPartnerships | foreach { Get-ActiveSyncDeviceStatistics -Mailbox $_} | select Identity,DeviceFriendlyName,LastSuccessSync | Export-CSV C:\Scripts\AllActiveSyncPhones_Before.csv -NoTypeInformation
Write-Host "Exported list of all ActiveSync partnerships to C:\Scripts\AllActiveSyncPhones_Before.csv"

# Remove all ActiveSync partnerships that are 90+ days old

Write-Host "Removing all ActiveSync partnerships older than 90 days"
try{
$OldActiveSyncPartnerships = Get-ActiveSyncDevice -result unlimited | Get-ActiveSyncDeviceStatistics | where {$_.LastSuccessSync -le (Get-Date).AddDays("-90")}
$OldActiveSyncPartnerships | foreach-object {Remove-ActiveSyncDevice ([string]$_.Guid) -confirm:$false} -ErrorAction Ignore
}
catch {
Write-Host "SKIPPING: No old ActiveSync partnerships"
}

# Get all remaining ActiveSync partnerships and export to a CSV

$AllActiveSyncPartnerships = Get-CASMailbox -Filter {hasactivesyncdevicepartnership -eq $true -and -not displayname -like "CAS_{*"} | Get-Mailbox
$AllActiveSyncPartnerships | foreach { Get-ActiveSyncDeviceStatistics -Mailbox $_} | select Identity,DeviceFriendlyName,LastSuccessSync | Export-CSV C:\Scripts\AllActiveSyncPhones_After.csv -NoTypeInformation
Write-Host "Exported list of all remaining ActiveSync partnerships to C:\Scripts\AllActiveSyncPhones_After.csv"

