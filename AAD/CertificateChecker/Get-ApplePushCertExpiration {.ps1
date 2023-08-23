function Get-ApplePushCertExpiration {

	
    try {

        $applePushCert = Invoke-MSGraphRequest -HttpMethod 'GET' -Url 'https://graph.microsoft.com/v1.0/deviceManagement/applePushNotificationCertificate' 
        $timespan = New-TimeSpan -Start (Get-Date) -End $applePushCert.expirationDateTime

        if ( $timespan -le 0 ) {
            Write-Output "WARNING: [ApplePush] Apple push cert is EXPIRED! ($($timespan.Days) days ago)"
        }
        else {
            Write-Output "[ApplePush] Apple push cert expires in: $($timespan.Days) days"
        }

    }
    catch {
        # No Apple push certificates
    }

}