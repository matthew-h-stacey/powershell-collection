$csv = Import-Csv .\Graph_CertChecker_ClientIDs.csv # Must have headers: Tenant,TenantID,ClientID
$FromAddress = "certificatechecker@bcservice.net"
$ToAddress = "mstacey@bcservice.net"


foreach ($app in $csv) { 

    $EmailBody = .\Get-AllCertExpiration.ps1 -TenantID $app.TenantID -ClientID $app.ClientID -All

    if ($null -ne $EmailBody) {
        Send-MailMessage -From $FromAddress -To $ToAddress -Subject "$($app.Tenant): Azure certificate/secret expiration alert" -Body ($EmailBody | Out-String) -SmtpServer d169685a.ess.barracudanetworks.com
    }

}