<#
.SYNOPSIS
Check Apple Push, Azure App Registrations, and Enterprise Apps for expiring secrets or certificates.

.DESCRIPTION
This script queries Apple Push, Azure App Registrations, and Enterprise Apps using Microsoft Graph API and checks each one of them for any secrets or certificates that are about to expire soon. The script compares the secret/certificate expiration date against the current date plus a threshold (default value: 90 days) to determine if they are expiring soon or not.

.PARAMETER Client
A selectable array of clients.

.PARAMETER CheckApplePushCert
Enable/disable the Apple Push certificate check

.PARAMETER CheckAppReg
Enable/disable the Application Registration certificate/secret check

.PARAMETER CheckEnterpriseApp
Enable/disable the Enterprise Application certificate/secret check

.PARAMETER Scope
Specifies the scope of the search. The value can be "All," "ExpiringSoonOnly," or "ExpiredOnly."

.PARAMETER ThresholdDays
If Scope is set to "ExpiringSoonOnly," only report on certificates expired/expiring within this threshold. For example, to report on certificates that are either expired or exiring with 90 days, enter 90 as the threshold.

.NOTES
Author: Matt Stacey
Version: 2.0
Date: June 20, 2023

To-Do:
- Fix Apple Push check failing script on clients that do not have an Apple Push certificate. Reached out to SkyKick support about this 2/27/2023. According to them, no known resolution at this time.
#>

function Get-AzureCertSecretExpirations {

    [SkyKickCommand(DisplayName = "Set Parameter Sections", Sections = { "Client", "Scope" })]
    param(
        [SkyKickParameter(
            DisplayName = "Client",
            Section = "Client",
            DisplayOrder = 1
        )]
        [Parameter(Mandatory = $true)][CustomerContext[]]$Client,

        [SkyKickParameter(
            DisplayName = "Apple Push Certificates",
            Section = "Scope",
            DisplayOrder = 1,
            HintText = "Enable or disable the check for Apple Push Certificates (ex: disable if the client does not use Apple MDM)"
        )]
        [Parameter(Mandatory = $true)][boolean]$CheckApplePushCert,

        [SkyKickParameter(
            DisplayName = "Application Registration Secret/Certificates",
            Section = "Scope",
            DisplayOrder = 2,
            HintText = "Enable or disable the check for Application Registration Secret/Certificates"
        )]
        [Parameter(Mandatory = $true)][boolean]$CheckAppReg,


        [SkyKickParameter(
            DisplayName = "Enterprise Application Secret/Certificates",
            Section = "Scope",
            DisplayOrder = 3,
            HintText = "Enable or disable the check for Enterprise Application Secret/Certificates"
        )]
        [Parameter(Mandatory = $true)][boolean]$CheckEnterpriseApp,

        [SkyKickParameter(
            DisplayName = "Scope of expiration check",    
            Section = "Scope",
            DisplayOrder = 4,
            HintText = "Select 'All' to report on expiration of all certs/secrets, or use 'ExpiringSoonOnly' to retrieve only certs/secrets that are expiring soon."
        )]
        [Parameter (Mandatory = $true)][ValidateSet("All", "ExpiringSoonOnly", "ExpiredOnly")][String]$Scope,
    
        [SkyKickConditionalVisibility({
                param($Scope)
                return (
                ($Scope -eq "ExpiringSoonOnly")
                )
            },
            IsMandatoryWhenVisible = $true
        )]
        [SkyKickParameter(
            DisplayName = "Days threshold",
            Section = "Scope",
            DisplayOrder = 5,
            HintText = "Enter the number of days to be considered 'soon' (ex: 90 days)"
        )][int]$ThresholdDays
    )

    function Add-HTMLOutput {
        $outputObject = [PSCustomObject]@{
            Client              = $clientName
            Category            = $category # ApplePush, AppReg, EnterpriseApp
            Type                = $objectType # Certificate, secret
            AppName             = $appName # Name of app reg or enterprise app
            Name                = $objectName # Name of the secret/certificate
            IsExpired           = $isExpired
            DaysUntilExpiration = $timespan.Days
        }
        $output.Add($outputObject)
    }

    function Get-ApplePushCertExpiration {

        try {
            $category = "ApplePush"
            $objectType = "Certificate"
            $objectName = "Apple MDM Push certificate"
            $appName = "N/A"
            $applePushCert = Invoke-MSGraphRequest -HttpMethod 'GET' -Url 'https://graph.microsoft.com/v1.0/deviceManagement/applePushNotificationCertificate' -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
            $timespan = New-TimeSpan -Start $today -End $applePushCert.expirationDateTime
            $isExpired = ($timespan.Days -lt 0)
            switch ($Scope) {
                'All' {
                    Add-HTMLOutput   
                }
                'ExpiringSoonOnly' {
                    if ($timespan.Days -gt $staleThreshold -and $timespan.Days -le $ThresholdDays) {
                        Add-HTMLOutput
                    }        
                }
                'ExpiredOnly' {
                    if ( $isExpired ) {
                        if ( $timespan.Days -gt $staleThreshold ) {
                            Add-HTMLOutput
                        }
                    }
                }
            }
            Write-Output "[$clientName] Found ApplePush certificate"
        } catch {
            # No Apple Push 
            Write-Output "[$clientName] No ApplePush certificate found"
        }       

    }

    function Get-AzureAppRegExpirations {
        
        $category = "AppReg"
        $appRegistrations = Invoke-MSGraphRequest -HttpMethod 'GET' -Url 'https://graph.microsoft.com/v1.0/applications'
        $appRegistrations = $appRegistrations.Value | Where-Object { $_.keyCredentials -ne $null -or $_.passwordCredentials -ne $null } | Sort-Object DisplayName

        # Iterate through every app
        foreach ($app in $appRegistrations) {
            $appName = $app.DisplayName
            if ( $app.passwordCredentials) { # Only process apps that have secrets
                $objectType = "Secret"
                foreach ($Password in $app.passwordCredentials) { # Loop through all secrets attached to the app
                    $passwordName = $Password.DisplayName
                    $objectName = $passwordName
                    $passwordExpiration = $Password.endDateTime
                    $timespan = New-TimeSpan -Start $today -End $passwordExpiration
                    $isExpired = ($timespan.Days -lt 0)
                    # Output the results based on the scope parameter and timespan status
                    switch ($Scope) {
                        'All' {
                            Add-HTMLOutput
                        }
                        'ExpiringSoonOnly' {
                            if ($timespan.Days -gt $staleThreshold -and $timespan.Days -le $ThresholdDays) {
                                Add-HTMLOutput
                            }        
                        }
                        'ExpiredOnly' {
                            if ( $isExpired ) {
                                if ( $timespan.Days -gt $staleThreshold ) {
                                    Add-HTMLOutput
                                }
                            }
                        }
                    }
                }
                if ( $app.keyCredentials) {
                    # Only process apps that have certificates
                    $objectType = "Certificate"
                    foreach ($certificate in $app.keyCredentials) {
                        # Loop through all certificates attached to the app
                        $certName = $certificate.DisplayName
                        $objectName = $certName
                    
                        $CertificateExpiration = $certificate.endDateTime
                        $timespan = New-TimeSpan -Start $today -End $CertificateExpiration
                        $isExpired = ($timespan.Days -lt 0)

                        # Output the results based on the scope parameter and timespan status
                        switch ($Scope) {
                            'All' {
                                Add-HTMLOutput       
                            }
                            'ExpiringSoonOnly' {
                                if ($timespan.Days -gt $staleThreshold -and $timespan.Days -le $ThresholdDays) {
                                    Add-HTMLOutput
                                }        
                            }
                            'ExpiredOnly' {
                                if ( $isExpired ) {
                                    if ( $timespan.Days -gt $staleThreshold ) {
                                        Add-HTMLOutput
                                    }
                                }
                            }
                        }
                    }
                }      
            }
        }

    }

    function Get-AzureEnterpriseAppExpirations {

        $category = "EnterpriseApp"
        $enterpriseApps = Get-MgServicePrincipal -All:$true -Filter "ServicePrincipalType eq 'Application'"
        foreach ($app in $enterpriseApps) {
            $appName = $app.DisplayName
            $objectType = "Secret"
            if ( $appName -notLike "P2P Server") {
                if ( $app.passwordCredentials) { # Only process apps that have secrets
                    foreach ($Password in $app.passwordCredentials) { # Loop through all secrets attached to the app
                        $passwordName = $Password.DisplayName
                        $objectName = $passwordName
                        $passwordExpiration = $Password.endDateTime
                        $timespan = New-TimeSpan -Start (Get-Date) -End $passwordExpiration
                        $isExpired = ($timespan.Days -lt 0)

                        # Output the results based on the scope parameter and timespan status
                        switch ($Scope) {
                            'All' {
                                Add-HTMLOutput      
                            }
                            'ExpiringSoonOnly' {
                                if ($timespan.Days -gt $staleThreshold -and $timespan.Days -le $ThresholdDays) {
                                    Add-HTMLOutput
                                }        
                            }
                            'ExpiredOnly' {
                                if ( $isExpired ) {
                                    if ( $timespan.Days -gt $staleThreshold ) {
                                        Add-HTMLOutput
                                    }
                                }
                            }
                        }
                    }
                    if ( $app.keyCredentials) { # Only process apps that have certificates
                        $objectType = "Certificate"
                        foreach ($Certificate in $app.keyCredentials) { # Loop through all certificates attached to the app
                            $certName = $certificate.DisplayName
                            $objectName = $certName
                            $CertificateExpiration = $certificate.endDateTime
                            $timespan = New-TimeSpan -Start (Get-Date) -End $CertificateExpiration
                            $isExpired = ($timespan.Days -lt 0)

                            # Output the results based on the scope parameter and timespan status
                            switch ($Scope) {
                                'All' {
                                    Add-HTMLOutput     
                                }
                                'ExpiringSoonOnly' {
                                    if ($timespan.Days -gt $staleThreshold -and $timespan.Days -le $ThresholdDays) {
                                        Add-HTMLOutput
                                    }        
                                }
                                'ExpiredOnly' {
                                    if ( $isExpired ) {
                                        if ( $timespan.Days -gt $staleThreshold ) {
                                            Add-HTMLOutput
                                        }
                                    }
                                }
                            }
                        }      
                    }
                }
            }
        }
    }

    # Global Variables 
    $staleThreshold = -90 # Ignore certificates or secrets that have expired greater than X days old to limit "white noise" (i.e application/service no longer being used)
    $today = Get-Date
    $output = New-Object System.Collections.Generic.List[System.Object]
    $reportTitle = "Certificate/secret expiration report"

    foreach ( $ClientContext in $Client) {
        Set-CustomerContext $clientContext
        $clientName = (Get-CustomerContext).CustomerName
        Write-Output "[INFO] Changed client to $clientName"
        if ( $CheckApplePushCert ) { 
            Write-Output "[$clientName] Running ApplePush check"
            Get-ApplePushCertExpiration
        }
        if ( 
            $CheckEnterpriseApp ) {
            Get-AzureEnterpriseAppExpirations
            Write-Output "[$clientName] Running Enterprise app check"
        }
        if ( $CheckAppReg ) {
            Get-AzureAppRegExpirations
            Write-Output "[$clientName] Running App reg check"
        }
    }

    $output | Out-SkyKickTableToHtmlReport -IncludePartnerLogo -ReportTitle $reportTitle -ReportFooter "Report created using SkyKick Cloud Manager" -OutTo NewTab
    
}