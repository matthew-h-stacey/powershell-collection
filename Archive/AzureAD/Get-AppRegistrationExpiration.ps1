param (
        [Parameter(Mandatory = $true)][String]$clientID,
        [Parameter(Mandatory = $true)][String]$tenantID,
        [parameter(ParameterSetName = "LimitedOutput")][switch]$ExpiringSoonOnly,
        [parameter(ParameterSetName = "All")][switch]$All
)

Import-Module MSAL.PS

# Threshold of days to be considered expiring "soon."
# example: if threshold is set to 90 and $ExpiringSoonOnly is used then the script will warn about any passwords/certificates expiring within 90 days
$threshold = 90 

# Retrieve the certificate from the PC using {Username}-{Hostname} format
$certName = [System.Environment]::UserName + "-" + [system.environment]::MachineName
$certThumbprint = Get-ChildItem Cert:\CurrentUser\My\ | Where-Object { $_.Subject -like "*$certName*" } | Select-Object -ExpandProperty Thumbprint
$ClientCertificate = Get-Item "Cert:\CurrentUser\My\$($certThumbprint)"
$myAccessToken = Get-MsalToken -ClientId $clientID -TenantId $tenantID -ClientCertificate $ClientCertificate # create Graph access token

$appRegistrations = (Invoke-RestMethod -Headers @{Authorization = "Bearer $($myAccessToken.AccessToken)" } `
        -Uri "https://graph.microsoft.com/v1.0/applications" `
        -Method Get).Value
$appRegistrations = $appRegistrations | Sort-Object DisplayName

# Populate an array with a list of all App Registrations and their passwords/certificates and expirations
$results = @()
foreach ($app in $appRegistrations) {
        $appObject = [PSCustomObject]@{
                DisplayName             = $app.displayName
        }
        if ($null -ne $app.passwordCredentials) { # Only attempt to add password-related properties for apps that have passwords
                $PasswordName = $app.passwordCredentials.DisplayName
                $PasswordExpiration = $app.passwordCredentials.endDateTime
                Add-Member -InputObject $appObject -MemberType NoteProperty -Name PasswordName -Value $PasswordName 
                Add-Member -InputObject $appObject -MemberType NoteProperty -Name PasswordExpiration -Value $PasswordExpiration 
        }

        if ($null -ne $app.keyCredentials) { # Only attempt to add certificates-related properties for apps that have certificates
                Add-Member -InputObject $appObject -MemberType NoteProperty -Name CertName -Value $app.keyCredentials.DisplayName
                Add-Member -InputObject $appObject -MemberType NoteProperty -Name CertExpiration -Value $app.keyCredentials.endDateTime
        }
        $results += $appObject

}
# Report on any expiring passwords/certificates
foreach ($r in $results){
        if ($null -ne $r.PasswordExpiration ) {
                $pwExpirationDate = $r.PasswordExpiration
                $timespan = New-TimeSpan -Start (Get-Date) -End $pwExpirationDate
                if ($All) {
                        Write-Host "$($r.DisplayName) secret $($PasswordName) expires in $($timespan.Days): days"
                }
                if ($ExpiringSoonOnly) {
                        if ($timespan.Days -le $threshold){
                                Write-Warning "$($r.DisplayName) secret $($PasswordName) expires in $($timespan.Days): days"
                        }
                }
        }
        if ($null -ne $r.CertExpiration ) {
                $certExpirationDate = $r.CertExpiration
                $timespan = New-TimeSpan -Start (Get-Date) -End $certExpirationDate
                
                if ($All) {
                        Write-Host "$($r.DisplayName) certificate $($CertName) expires in $($timespan.Days): days"
                }
                if ($ExpiringSoonOnly) {
                        if ($timespan.Days -le 60) {
                                Write-Warning "$($r.DisplayName) certificate $($CertName) expires in $($timespan.Days): days"
                        }
                }
        }
}