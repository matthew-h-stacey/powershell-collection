$test = "aalarie@cfpsych.org"

foreach ($mailbox in $test) {
    $mobileUser = Get-EXOMobileDeviceStatistics -UserPrincipalName $mailbox
    foreach ($phone in $mobileUser) {
        $arrayInfo = @{
            User            = $mailbox
            LastSuccessSync = $phone.LastSuccessSync
            DeviceModel     = $phone.DeviceModel
            DeviceOS        = $phone.DeviceOS 
        }
        $results += New-Object psobject -Property $arrayInfo
    }
}
$results | Format-Table




foreach ($g in $pcaGroups) { Write-Host (($g.Split("@")[0] + “@psycare.info”))}

foreach($d in $PCSDistis) { Write-Host ($d.PrimarySmtpAddress.Split("@")[0] + “@psycare.info”) }