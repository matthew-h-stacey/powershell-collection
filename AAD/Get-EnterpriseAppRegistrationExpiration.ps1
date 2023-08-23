$myAccessToken = Get-MsalToken -ClientId $clientID -TenantId $tenantID -ClientCertificate $ClientCertificate # create Graph access token
$servicePrincipals = (Invoke-RestMethod -Headers @{Authorization = "Bearer $($myAccessToken.AccessToken)" } `
        -Uri "https://graph.microsoft.com/v1.0/servicePrincipals" `
        -Method Get).Value

$servicePrincipals = $servicePrincipals | sort DisplayName

$results = @()
foreach ($sp in $servicePrincipals) {
    $spObject = [PSCustomObject]@{
        DisplayName = $sp.displayName
    }
    if ($null -ne $sp.passwordCredentials) {
        # Only attempt to add password-related properties for apps that have passwords
        $PasswordName = $sp.passwordCredentials.DisplayName
        $PasswordExpiration = $sp.passwordCredentials.endDateTime
        Add-Member -InputObject $spObject -MemberType NoteProperty -Name PasswordName -Value $PasswordName 
        Add-Member -InputObject $spObject -MemberType NoteProperty -Name PasswordExpiration -Value $PasswordExpiration 
    }

    if ($null -ne $sp.keyCredentials) {
        # Only attempt to add certificates-related properties for apps that have certificates
        Add-Member -InputObject $spObject -MemberType NoteProperty -Name CertName -Value $sp.keyCredentials.DisplayName
        Add-Member -InputObject $spObject -MemberType NoteProperty -Name CertExpiration -Value $sp.keyCredentials.endDateTime
    }
    $results += $spObject

}
# Report on any expiring passwords/certificates
foreach ($r in $results) {
    if ($null -ne $r.PasswordExpiration ) {
        foreach ($pw in $r.PasswordExpiration){
            $pwExpirationDate = $pw
            $timespan = New-TimeSpan -Start (Get-Date) -End $pwExpirationDate
            if ($All) {
                if ($timespan.Days -le 0) {
                    Write-Warning "[EnterpriseApp] $($r.DisplayName) secret $($r.PasswordName) is EXPIRED! ($($timespan.Days) days ago)"
                }
                else {
                    Write-Host "[EnterpriseApp] $($r.DisplayName) secret $($r.PasswordName) expires in $($timespan.Days): days"
                }
            }
            if ($ExpiringSoonOnly) {
                if ($timespan.Days -le $threshold) {
                    if ($timespan.Days -le 0) {
                        Write-Warning "[EnterpriseApp] $($r.DisplayName) secret $($r.PasswordName) is EXPIRED! ($($timespan.Days) days ago)"
                    }
                    else {
                        Write-Warning "[EnterpriseApp] $($r.DisplayName) secret $($r.PasswordName) expires in $($timespan.Days): days"
                    }
                }
            }
        }
    }
    if ($null -ne $r.CertExpiration ) {
            foreach ($cert in $r.CertExpiration) {
                $certExpirationDate = $cert
                $timespan = New-TimeSpan -Start (Get-Date) -End $certExpirationDate
                if ($All) {
                    if ($timespan -le 0) {
                        Write-Warning "[EnterpriseApp] $($r.DisplayName) certificate is EXPIRED! ($($timespan.Days) days ago)"
                    }
                    else {
                        Write-Host "[EnterpriseApp] $($r.DisplayName) certificate expires in $($timespan.Days): days"
                    }
                }
            if ($ExpiringSoonOnly) {
                if ($timespan.Days -le 60) {
                    if ($timespan.Days -le 0) {
                        Write-Warning "[EnterpriseApp] $($r.DisplayName) certificate is EXPIRED! ($($timespan.Days) days ago)"
                    }
                    else {
                        Write-Warning "[EnterpriseApp] $($r.DisplayName) certificate expires in $($timespan.Days): days"
                    }
                }
            }
        }      
    }
}