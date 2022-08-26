# https://blog.darrenjrobinson.com/microsoft-graph-using-msal-with-powershell-and-certificate-authentication/

param (
        [Parameter(Mandatory = $true)][String]$clientID,
        [Parameter(Mandatory = $true)][String]$tenantID
)

$certName = [System.Environment]::UserName + "-" + [system.environment]::MachineName
$certThumbprint = Get-ChildItem Cert:\CurrentUser\My\ | Where-Object { $_.Subject -like "*$certName*" } | Select-Object -ExpandProperty Thumbprint

Import-Module MSAL.PS

$ClientCertificate = Get-Item "Cert:\CurrentUser\My\$($certThumbprint)"
$myAccessToken = Get-MsalToken -ClientId $clientID -TenantId $tenantID -ClientCertificate $ClientCertificate

$applePushCert = (Invoke-RestMethod -Headers @{Authorization = "Bearer $($myAccessToken.AccessToken)" } `
        -Uri "https://graph.microsoft.com/v1.0/deviceManagement/applePushNotificationCertificate" `
        -Method Get)

$expirationDate = $applePushCert.expirationDateTime
$timespan = New-TimeSpan -Start (Get-Date) -End $expirationDate

Write-Host "Apple push cert expires in $($timespan.Days): days"