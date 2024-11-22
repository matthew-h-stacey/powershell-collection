<#
.SYNOPSIS
Check Apple Push, Azure App Registrations, and Enterprise Apps for expiring secrets or certificates.

.DESCRIPTION
This script queries Apple Push, Azure App Registrations, and Enterprise Apps using Microsoft Graph API and checks each one of them for any secrets or certificates that are about to expire soon.
The script compares the secret/certificate expiration date against the current date plus a threshold (default value: 90 days) to determine if they are expiring soon or not.

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

.PARAMETER ExpiringSoonDays
If Scope is set to "ExpiringSoonOnly," only report on certificates expired/expiring within this threshold. For example, to report on certificates that are either expired or exiring with 90 days, enter 90 as the threshold.

.NOTES
Author: Matt Stacey
Version: 3.0
Date: 11/4/2024
#>

function Get-EntraCertificateAndSecretExpirations {

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
        )][int]$ExpiringSoonDays
    )

    function Get-ApplePushCertExpiration {

    <#
    .SYNOPSIS
    Retrieve the Apple Push certificate from a client tenant

    .PARAMETER Scope
    Filter the output based on a desired scope. ExpiringSoonOnly works with ExpiringSoonDays to filter by a specific range. ExpiredOnly pulls only certificates/secrets that have expired. All pulls all certificates/secrets

    .PARAMETER IgnoreStaleDays
    Ignore certificates that have expired greater than X days old to limit "white noise" (i.e application/service no longer being used)

    .PARAMETER ExpiringSoonDays
    Only report on certificates expired/expiring within this threshold. For example, to report on certificates that are either expired or exiring with 90 days, enter 90 as the threshold.
    #>

        param (
            [Parameter (Mandatory = $true)]
            [ValidateSet("All", "ExpiringSoonOnly", "ExpiredOnly")]
            [String]
            $Scope,

            [Parameter(Mandatory = $false)]
            [int]
            $IgnoreStaleDays = 180,

            [Parameter(Mandatory = $false)]
            [int]
            $ExpiringSoonDays
        )

        # Make IgnoreStaleDays negative for New-Timespan to ignore older than X days old
        if ($IgnoreStaleDays -gt 0) {
            $IgnoreStaleDays = - [math]::Abs($IgnoreStaleDays)
        }

        $today = Get-Date
        $uri = 'https://graph.microsoft.com/v1.0/deviceManagement/applePushNotificationCertificate'
        $applePushCert = Invoke-MgGraphRequest -Method GET -Uri $uri -SkipHttpErrorCheck
    
        if ( $applePushCert.Keys -eq "error" ) {
            # No Apple Push 
            Write-Output "[INFO] ${clientName}: No ApplePush certificate found"
        } elseif ( $applePushCert.id ) {
            # Apple Push certificate found. Store certificate properties in object
            Write-Output "[INFO] ${clientName}: Found ApplePush certificate"
            $timeSpan = New-TimeSpan -Start $today -End $applePushCert.expirationDateTime
            $cert = [PSCustomObject]@{
                Client = (Get-CustomerContext).CustomerName
                Category = "ApplePush"
                Type = "Certificate"
                AppName = "N/A"
                ObjectName = "Apple MDM Push certificate"
                DaysUntilExpiry = $timeSpan.Days
                IsExpired = ($timespan.Days -lt 0)
            }

            # Conditionally return the Apple Push certificate based on the scope
            switch ($Scope) {
                'All' {
                    return $cert
                }
                'ExpiringSoonOnly' {
                    if ($timespan.Days -gt $IgnoreStaleDays -and $timespan.Days -le $ExpiringSoonDays) {
                        return $cert
                    }        
                }
                'ExpiredOnly' {
                    if ( $isExpired ) {
                        if ( $timespan.Days -gt $IgnoreStaleDays ) {
                            return $cert
                        }
                    }
                }
            }
        
        }

    }

    function Get-EntraAppRegExpirations {

        <#
    .SYNOPSIS
    Retrieve Entra Application Registration secrets or certificates expiring within the selected range

    .PARAMETER Scope
    Filter the output based on a desired scope. ExpiringSoonOnly works with ExpiringSoonDays to filter by a specific range. ExpiredOnly pulls only certificates/secrets that have expired. All pulls all certificates/secrets

    .PARAMETER IgnoreStaleDays
    Ignore certificates that have expired greater than X days old to limit "white noise" (i.e application/service no longer being used)

    .PARAMETER ExpiringSoonDays
    Only report on certificates expired/expiring within this threshold. For example, to report on certificates that are either expired or exiring with 90 days, enter 90 as the threshold.
    #>

        param (
            [Parameter (Mandatory = $true)]
            [ValidateSet("All", "ExpiringSoonOnly", "ExpiredOnly")]
            [String]
            $Scope,

            [Parameter(Mandatory = $false)]
            [int]
            $IgnoreStaleDays = 180,

            [Parameter(Mandatory = $false)]
            [int]
            $ExpiringSoonDays
        )

        # Make IgnoreStaleDays negative for New-Timespan to ignore older than X days old
        if ($IgnoreStaleDays -gt 0) {
            $IgnoreStaleDays = - [math]::Abs($IgnoreStaleDays)
        }

        # Construct an empty list and object format to add to the list as items are processed
        $resultsList = [System.Collections.Generic.List[System.Object]]::new()
        $result = [PSCustomObject]@{
            Client     = (Get-CustomerContext).CustomerName
            Category   = "AppReg"
            Type       = "-"
            AppName    = "-"
            ObjectName = "-"
            DaysUntilExpiry = "-"
            IsExpired  = "-"
        }

        $today = Get-Date
        $appRegistrations = Invoke-MgGraphRequest -Method 'GET' -Uri 'https://graph.microsoft.com/v1.0/applications'
        $appRegistrations = $appRegistrations.Value | Sort-Object DisplayName
    
        # Iterate through every app
        foreach ($app in $appRegistrations) {
            $result.AppName = $app.DisplayName
            if ( $app.passwordCredentials) {
                # Only process apps that have secrets
                $result.Type = "Secret"
                foreach ($Password in $app.passwordCredentials) {
                    # Loop through all secrets attached to the app
                    $result.ObjectName = $Password.DisplayName
                    $timespan = New-TimeSpan -Start $today -End $Password.endDateTime
                    $isExpired = ($timespan.Days -lt 0)
                    $result.DaysUntilExpiry = $timespan.Days
                    $result.IsExpired = $isExpired
                    # Output the results based on the scope parameter and timespan status
                    switch ($Scope) {
                        'All' {
                            $resultsList.Add($result)
                        }
                        'ExpiringSoonOnly' {
                            if ($timespan.Days -gt $IgnoreStaleDays -and $timespan.Days -le $ExpiringSoonDays) {
                                $resultsList.Add($result)
                            }        
                        }
                        'ExpiredOnly' {
                            if ( $isExpired ) {
                                if ( $timespan.Days -gt $IgnoreStaleDays ) {
                                    $resultsList.Add($result)
                                }
                            }
                        }
                    }
                }
                if ( $app.keyCredentials) {
                    # Only process apps that have certificates
                    $result.Type = "Certificate"
                    foreach ($certificate in $app.keyCredentials) {
                        # Loop through all certificates attached to the app
                        $result.ObjectName = $certificate.DisplayName
                        $timespan = New-TimeSpan -Start $today -End $certificate.endDateTime
                        $isExpired = ($timespan.Days -lt 0)
                        $result.DaysUntilExpiry = $timespan.Days
                        $result.IsExpired = $isExpired
                        # Output the results based on the scope parameter and timespan status
                        switch ($Scope) {
                            'All' {
                                $resultsList.Add($result)     
                            }
                            'ExpiringSoonOnly' {
                                if ($timespan.Days -gt $IgnoreStaleDays -and $timespan.Days -le $ExpiringSoonDays) {
                                    $resultsList.Add($result)
                                }        
                            }
                            'ExpiredOnly' {
                                if ( $isExpired ) {
                                    if ( $timespan.Days -gt $IgnoreStaleDays ) {
                                        $resultsList.Add($result)
                                    }
                                }
                            }
                        }
                    }
                }      
            }
        }

        return $resultsList

    }

    function Get-EntraEnterpriseAppExpirations {

        <#
    .SYNOPSIS
    Retrieve Entra Enterprise Application secrets or certificates expiring within the selected range

    .PARAMETER Scope
    Filter the output based on a desired scope. ExpiringSoonOnly works with ExpiringSoonDays to filter by a specific range. ExpiredOnly pulls only certificates/secrets that have expired. All pulls all certificates/secrets

    .PARAMETER IgnoreStaleDays
    Ignore certificates that have expired greater than X days old to limit "white noise" (i.e application/service no longer being used)

    .PARAMETER ExpiringSoonDays
    Only report on certificates expired/expiring within this threshold. For example, to report on certificates that are either expired or exiring with 90 days, enter 90 as the threshold.
    #>

        param (
            [Parameter (Mandatory = $true)]
            [ValidateSet("All", "ExpiringSoonOnly", "ExpiredOnly")]
            [String]
            $Scope,

            [Parameter(Mandatory = $false)]
            [int]
            $IgnoreStaleDays = 180,

            [Parameter(Mandatory = $false)]
            [int]
            $ExpiringSoonDays
        )

        # Make IgnoreStaleDays negative for New-Timespan to ignore older than X days old
        if ($IgnoreStaleDays -gt 0) {
            $IgnoreStaleDays = - [math]::Abs($IgnoreStaleDays)
        }

        # Construct an empty list and object format to add to the list as items are processed
        $resultsList = [System.Collections.Generic.List[System.Object]]::new()
        $result = [PSCustomObject]@{
            Client     = (Get-CustomerContext).CustomerName
            Category   = "EnterpriseApp"
            Type       = "-"
            AppName    = "-"
            ObjectName = "-"
            DaysUntilExpiry = "-"
            IsExpired  = "-"
        }

        $today = Get-Date
        $enterpriseApps = Get-MgServicePrincipal -All:$true -Filter "ServicePrincipalType eq 'Application'"
        foreach ($app in $enterpriseApps) {
            $appName = $app.DisplayName
            $result.AppName = $appName
        
            if ( $appName -notLike "P2P Server") {
                if ( $app.passwordCredentials) {
                    # Only process apps that have secrets                
                    $result.Type = "Secret"
                    foreach ($Password in $app.passwordCredentials) {
                        # Loop through all secrets attached to the app
                        $result.ObjectName = $Password.DisplayName
                        $timespan = New-TimeSpan -Start $today -End $Password.endDateTime
                        $isExpired = ($timespan.Days -lt 0)
                        $result.DaysUntilExpiry = $timespan.Days
                        $result.IsExpired = $isExpired
                        # Output the results based on the scope parameter and timespan status
                        switch ($Scope) {
                            'All' {
                                $resultsList.Add($result)    
                            }
                            'ExpiringSoonOnly' {
                                if ($timespan.Days -gt $IgnoreStaleDays -and $timespan.Days -le $ExpiringSoonDays) {
                                    $resultsList.Add($result)
                                }        
                            }
                            'ExpiredOnly' {
                                if ( $isExpired ) {
                                    if ( $timespan.Days -gt $IgnoreStaleDays ) {
                                        $resultsList.Add($result)
                                    }
                                }
                            }
                        }
                    }
                    if ( $app.keyCredentials) {
                        # Only process apps that have certificates
                        $result.Type = "Certificate"
                        foreach ($Certificate in $app.keyCredentials) {
                            # Loop through all certificates attached to the app
                            $result.ObjectName = $certificate.DisplayName
                            $timespan = New-TimeSpan -Start $today -End $certificate.endDateTime
                            $isExpired = ($timespan.Days -lt 0)
                            $result.DaysUntilExpiry = $timespan.Days
                            $result.IsExpired = $isExpired

                            # Output the results based on the scope parameter and timespan status
                            switch ($Scope) {
                                'All' {
                                    $resultsList.Add($result)      
                                }
                                'ExpiringSoonOnly' {
                                    if ($timespan.Days -gt $IgnoreStaleDays -and $timespan.Days -le $ExpiringSoonDays) {
                                        $resultsList.Add($result)   
                                    }        
                                }
                                'ExpiredOnly' {
                                    if ( $isExpired ) {
                                        if ( $timespan.Days -gt $IgnoreStaleDays ) {
                                            $resultsList.Add($result)
                                        }
                                    }
                                }
                            }
                        }      
                    }
                }
            }
        }
        return $resultsList
    }


    $output = New-Object System.Collections.Generic.List[System.Object]
    $reportTitle = "Certificate/secret expiration report"

    foreach ( $ClientContext in $Client) {
        Set-CustomerContext $clientContext
        $clientName = (Get-CustomerContext).CustomerName
        Write-Output "[INFO] Changed client to $clientName"
        if ( $CheckApplePushCert ) { 
            Write-Output "[INFO] ${clientName}: Running ApplePush check"
            $output.Add((Get-ApplePushCertExpiration -Scope $Scope -ExpiringSoonDays $ExpiringSoonDays))
        }
        if ( 
            $CheckEnterpriseApp ) {
            Get-EntraEnterpriseAppExpirations
            Write-Output "[INFO] ${clientName}: Running Enterprise app check"
        }
        if ( $CheckAppReg ) {
            Get-EntraAppRegExpirations
            Write-Output "[INFO] ${clientName}: Running App reg check"
        }
    }

    if ( $output ) {
        $output | Out-SkyKickTableToHtmlReport -IncludePartnerLogo -ReportTitle $reportTitle -ReportFooter "Report created using SkyKick Cloud Manager" -OutTo NewTab
    }
    
}