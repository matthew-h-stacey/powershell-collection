<#
.SYNOPSIS
    This script will utilize an existing Azure App Registration to report on certificates in use on the tenant and their expirations. This script can very easily be
    combined with New-AppRegCertChecker.ps1, which will handle the creation of that Azure App Registration. The script can be run one-off on a single client or looped
    through many for broader reporting. This script uses a certificate instead of secret for better security (ex: New-PersonalCertificate.ps1). The permissions for the
    App Registration are as follows: 
        Graph>Application.Read.All, DeviceManagementManagedDevices.Read.All, DeviceManagementServiceConfig.Read.All
.PARAMETER TenantID
    The Azure tenant ID that is unique to every Azure instance. You can pull this manually or from \Graph_CertChecker_ClientIDs.csv if you used New-AppRegCertChecker.ps1.
.PARAMETER ClientID
    The client or application ID that is assigned to the Azure App Registration. You can pull this manually or from \Graph_CertChecker_ClientIDs.csv if you used New-AppRegCertChecker.ps1.
.PARAMETER ExpiringSoonOnly
    Only report on certificates that whose expiration date is less than equal to $Threshold.
.PARAMETER Threshold
    The number of days left in a certificate to be considered expiring "soon." Recommended number to start is 90, for 90 days.
.PARAMETER All
    If the goal is to retrieve all certificates instead of just those that are expiring soon, use the All switch.
.EXAMPLE
    Single:
    .\Get-AllCertExpiration.ps1 -clientID 0000000-0000-0000-0000-000000000000 -tenantID 1111111-1111-1111-1111-111111111111 -ExpiringSoonOnly -Threshold 90

    Bulk (report file):
    $csv = Import-Csv .\Graph_CertChecker_ClientIDs.csv # Must have headers: Tenant,TenantID,ClientID
    foreach ($app in $csv) { 
        $reportFile = .\$($app.Tenant)_Cert_Report.txt
        $output = .\Get-AllCertExpiration.ps1 -TenantID $app.TenantID -ClientID $app.ClientID -ExpiringSoonOnly -Threshold 90
        if ($null -ne $output) {
            $output | Out-File $reportFile
        }
    }

    Bulk (email):
    $csv = Import-Csv .\Graph_CertChecker_ClientIDs.csv # Must have headers: Tenant,TenantID,ClientID
    foreach ($app in $csv) { 
    $EmailBody = .\Get-AllCertExpiration.ps1 -TenantID $app.TenantID -ClientID $app.ClientID -ExpiringSoonOnly -Threshold 90
    if ($null -ne $EmailBody) {
        Send-MailMessage -From certificatechecker@bcservice.net -To help@bcservice.net -Subject "$($app.Tenant): Azure certificate expiration" -Body $EmailBody -SmtpServer d169685a.ess.barracudanetworks.com
    }

}
.NOTES
    Author: Matt Stacey
    Date:   June 15, 2022
#>

param (
    [Parameter(Mandatory = $true)][String]$TenantID,
    [Parameter(Mandatory = $true)][String]$ClientID,
    [parameter(ParameterSetName = "LimitedOutput")][switch]$ExpiringSoonOnly,
    [parameter(ParameterSetName = "LimitedOutput")][int]$Threshold,
    [parameter(ParameterSetName = "All")][switch]$All
)

try {
    Import-Module MSAL.PS -ErrorAction Stop
}
catch {
    Write-Output "[MODULE] MSAL.PS module not found, installing ..."
    Install-Module MSAL.PS -Scope CurrentUser
    Import-Module MSAL.PS
}

$certName = [System.Environment]::UserName + "-" + [system.environment]::MachineName
$certThumbprint = Get-ChildItem Cert:\CurrentUser\My\ | Where-Object { $_.Subject -like "*$certName*" } | Select-Object -ExpandProperty Thumbprint
$ClientCertificate = Get-Item "Cert:\CurrentUser\My\$($certThumbprint)"
$myAccessToken = Get-MsalToken -ClientId $clientID -TenantId $tenantID -ClientCertificate $ClientCertificate

function Get-ApplePushCertExpiration {
    try {
        $applePushCert = (Invoke-RestMethod -Headers @{Authorization = "Bearer $($myAccessToken.AccessToken)" } `
                -Uri "https://graph.microsoft.com/v1.0/deviceManagement/applePushNotificationCertificate" `
                -Method Get)
        $expirationDate = $applePushCert.expirationDateTime
        $timespan = New-TimeSpan -Start (Get-Date) -End $expirationDate

        if ($All) {
            if ( $timespan -le 0 ) {
                Write-Output "WARNING: [ApplePush] Apple push cert is EXPIRED! ($($timespan.Days) days ago)"
            }
            else {
                Write-Output "[ApplePush] Apple push cert expires in: $($timespan.Days) days"
            }
        }
        if ($ExpiringSoonOnly) {
            if ( $timespan -le 0 ) {
                Write-Output "WARNING: [ApplePush] Apple push cert is EXPIRED! ($($timespan.Days) days ago)"
            }
            elseif ($timespan.Days -le $threshold) {
                Write-Output "[ApplePush] Apple push cert expires in: $($timespan.Days) days"
            }
        }
    }
    catch {
        # No Apple push certificates
    }

    
}

function Get-AppRegistrationExpiration {
    $appRegistrations = (Invoke-RestMethod -Headers @{Authorization = "Bearer $($myAccessToken.AccessToken)" } `
            -Uri "https://graph.microsoft.com/v1.0/applications" `
            -Method Get).Value
    $appRegistrations = $appRegistrations | Sort-Object DisplayName

    # Populate an array with a list of all App Registrations and their passwords/certificates and expirations
    $results = @()
    foreach ($app in $appRegistrations) {
        $appObject = [PSCustomObject]@{
            DisplayName = $app.displayName
        }
        if ($null -ne $app.passwordCredentials) {
            # Only attempt to add password-related properties for apps that have passwords
            $PasswordName = $app.passwordCredentials.DisplayName
            $PasswordExpiration = $app.passwordCredentials.endDateTime
            Add-Member -InputObject $appObject -MemberType NoteProperty -Name PasswordName -Value $PasswordName 
            Add-Member -InputObject $appObject -MemberType NoteProperty -Name PasswordExpiration -Value $PasswordExpiration 
        }

        if ($null -ne $app.keyCredentials) {
            # Only attempt to add certificates-related properties for apps that have certificates
            Add-Member -InputObject $appObject -MemberType NoteProperty -Name CertName -Value $app.keyCredentials.DisplayName
            Add-Member -InputObject $appObject -MemberType NoteProperty -Name CertExpiration -Value $app.keyCredentials.endDateTime
        }
        $results += $appObject

    }
    # Report on any expiring passwords/certificates
    foreach ($r in $results) {
        if ($null -ne $r.PasswordExpiration ) {
            # Check for expiring passwords (secrets)
            $pwExpirationDate = $r.PasswordExpiration
            $timespan = New-TimeSpan -Start (Get-Date) -End $pwExpirationDate
            if ($All) {
                Write-Output "[AppReg] $($r.DisplayName) secret $($PasswordName) expires in: $($timespan.Days) days"
            }
            if ($ExpiringSoonOnly) {
                if ($timespan.Days -le $threshold) {
                    Write-Output "WARNING: [AppReg] $($r.DisplayName) secret $($PasswordName) expires in: $($timespan.Days) days"
                }
            }
        }
        if ($null -ne $r.CertExpiration ) {
            # Check for expiring certificates
            if ( $r.CertExpiration.Length -eq 1) {
                # if the App Reg has a single certificate
                $certExpirationDate = $r.CertExpiration
                $timespan = New-TimeSpan -Start (Get-Date) -End $certExpirationDate
                if ($All) {
                    Write-Output "[AppReg] $($r.DisplayName) certificate $($CertName) expires in: $($timespan.Days) days"
                }
                if ($ExpiringSoonOnly) {
                    if ($timespan.Days -le 60) {
                        Write-Output "WARNING: [AppReg] $($r.DisplayName) certificate $($CertName) expires in: $($timespan.Days) days"
                    }
                }
            }
            if ($r.CertExpiration.Length -gt 1) {
                # if the App Reg has multiple certificates
                $certExpirationDates = $r.CertExpiration                
                foreach ( $cert in $certExpirationDates) { 
                    $timespan = New-TimeSpan -Start (Get-Date) -End $cert
                    if ($All) {
                        Write-Output "[AppReg] $($r.DisplayName) certificate $($CertName) expires in: $($timespan.Days) days"
                    }
                    if ($ExpiringSoonOnly) {
                        if ($timespan.Days -le 60) {
                            Write-Output "WARNING: [AppReg] $($r.DisplayName) certificate $($CertName) expires in: $($timespan.Days) days"
                        }
                    }

                }

            }
        }
    }
}

function Get-EnterpriseAppRegistration {
    $myAccessToken = Get-MsalToken -ClientId $clientID -TenantId $tenantID -ClientCertificate $ClientCertificate # create Graph access token
    $servicePrincipals = (Invoke-RestMethod -Headers @{Authorization = "Bearer $($myAccessToken.AccessToken)" } `
            -Uri "https://graph.microsoft.com/v1.0/servicePrincipals" `
            -Method Get).Value

    $servicePrincipals = $servicePrincipals | Where-Object { $_.DisplayName -notLike "P2P Server" } | Sort-Object DisplayName

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
            foreach ($pw in $r.PasswordExpiration) {
                $pwExpirationDate = $pw
                $timespan = New-TimeSpan -Start (Get-Date) -End $pwExpirationDate
                if ($All) {
                    if ($timespan.Days -le 0) {
                        Write-Output "WARNING: [EnterpriseApp] $($r.DisplayName) secret $($r.PasswordName) is EXPIRED! ($($timespan.Days) days ago)"
                    }
                    else {
                        Write-Output "[EnterpriseApp] $($r.DisplayName) secret $($r.PasswordName) expires in: $($timespan.Days) days"
                    }
                }
                if ($ExpiringSoonOnly) {
                    if ($timespan.Days -le $threshold) {
                        if ($timespan.Days -le 0) {
                            Write-Output "WARNING: [EnterpriseApp] $($r.DisplayName) secret $($r.PasswordName) is EXPIRED! ($($timespan.Days) days ago)"
                        }
                        else {
                            Write-Output "WARNING: [EnterpriseApp] $($r.DisplayName) secret $($r.PasswordName) expires in: $($timespan.Days) days"
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
                        Write-Output "WARNING: [EnterpriseApp] $($r.DisplayName) certificate is EXPIRED! ($($timespan.Days) days ago)"
                    }
                    else {
                        Write-Output "[EnterpriseApp] $($r.DisplayName) certificate expires in: $($timespan.Days) days"
                    }
                }
                if ($ExpiringSoonOnly) {
                    if ($timespan.Days -le 60) {
                        if ($timespan.Days -le 0) {
                            Write-Output "WARNING: [EnterpriseApp] $($r.DisplayName) certificate is EXPIRED! ($($timespan.Days) days ago)"
                        }
                        else {
                            Write-Output "WARNING: [EnterpriseApp] $($r.DisplayName) certificate expires in: $($timespan.Days) days"
                        }
                    }
                }
            }      
        }
    }
}

Get-ApplePushCertExpiration
Get-AppRegistrationExpiration
Get-EnterpriseAppRegistration