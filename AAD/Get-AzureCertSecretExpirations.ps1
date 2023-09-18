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
Date: Feb 21, 2023

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

    # Global Variables 
    $strLengthThresold = 40 # truncate app name/secret name/certificate names that are longer than X characters long for cleaner output
    $StaleThreshold = 90 # Ignore certs that are older than X days old to limit "white noise" (i.e application/service no longer being used)
    $Today = Get-Date


    function Get-ApplePushCertExpiration {

        try {
            $applePushCert = Invoke-MSGraphRequest -HttpMethod 'GET' -Url 'https://graph.microsoft.com/v1.0/deviceManagement/applePushNotificationCertificate' -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
            $Timespan = New-TimeSpan -Start $Today -End $applePushCert.expirationDateTime
            $IsExpired = ($Timespan.Days -lt 0)
            switch ($Scope) {
                'All' {
                    switch ($IsExpired) {
                        'True' { 
                            if ( ([Math]::Abs($Timespan.Days)) -lt $StaleThreshold -and ([Math]::Abs($Timespan.Days)) -ge 0) {
                                Write-Output "[$ClientName][ApplePush][MDM] Apple push cert expired $([Math]::Abs($Timespan.Days)) days ago"
                            }
                        }
                        'False' { Write-Output "[$ClientName][ApplePush][MDM] Apple push cert expires in $($TimeSpan.Days) days" }
                    }        
                }
                'ExpiringSoonOnly' {
                    if ($TimeSpan.Days -le $ThresholdDays) {
                        switch ($IsExpired) {
                            'True' { 
                                if ( ([Math]::Abs($Timespan.Days)) -lt $StaleThreshold -and ([Math]::Abs($Timespan.Days)) -ge 0) {
                                    Write-Output "[$ClientName][ApplePush][MDM] Apple push cert expired $([Math]::Abs($Timespan.Days)) days ago"
                                }
                            }
                            'False' { Write-Output "[$ClientName][ApplePush][MDM] Apple push cert expires in $($TimeSpan.Days) days" }
                        }
                    }        
                }
                'ExpiredOnly' {
                    if ( $IsExpired ) {
                        Write-Output "[$ClientName][ApplePush][MDM] Apple push cert expired $([Math]::Abs($Timespan.Days)) days ago"
                    }
                }
            }
        }
        catch {
            # No Apple Push 
        }       

    }

    function Get-AzureAppRegExpirations {
        
        $appRegistrations = Invoke-MSGraphRequest -HttpMethod 'GET' -Url 'https://graph.microsoft.com/v1.0/applications'
        $appRegistrations = $appRegistrations.Value | Sort-Object DisplayName

        # Iterate through every app
        foreach ($App in $AppRegistrations) {

            $AppName = $App.DisplayName + ":"
            if ($AppName.Length -gt $strLengthThresold) {
                $AppName = $AppName.subString(0, [System.Math]::Min($strLengthThresold, $AppName.Length)) + "...:"
            }

            # Only process apps that have secrets
            if ( $App.passwordCredentials) {
                # Additional for-each loop in case the app has multiple secrets
                foreach ($Password in $App.passwordCredentials) {
                    #$PasswordName = $Password.DisplayName

                    $PasswordName = $Password.DisplayName

                    if ($PasswordName.Length -gt $strLengthThresold) {
                        $PasswordName = $PasswordName.subString(0, [System.Math]::Min($strLengthThresold, $PasswordName.Length)) + "..."
                    }

                    $PasswordExpiration = $Password.endDateTime
                    $TimeSpan = New-TimeSpan -Start $Today -End $PasswordExpiration
                    $IsExpired = ($Timespan.Days -lt 0)

                    # Output the results based on the scope parameter and timespan status
                    switch ($Scope) {
                        'All' {
                            switch ($IsExpired) {
                                'True' { 
                                    if ( ([Math]::Abs($Timespan.Days)) -lt $StaleThreshold -and ([Math]::Abs($Timespan.Days)) -ge 0) {
                                        Write-Output "[$ClientName][AppReg][Secret] $($AppName) secret $($PasswordName) expired $([Math]::Abs($Timespan.Days)) days ago"
                                    }
                                }
                                'False' { Write-Output "[$ClientName][AppReg][Secret] $($AppName) secret $($PasswordName) expires in $($TimeSpan.Days) days" }
                            }        
                        }
                        'ExpiringSoonOnly' {
                            if ($TimeSpan.Days -le $ThresholdDays) {
                                switch ($IsExpired) {
                                    'True' { 
                                        if ( ([Math]::Abs($Timespan.Days)) -lt $StaleThreshold -and ([Math]::Abs($Timespan.Days)) -ge 0) {
                                            Write-Output "[$ClientName][AppReg][Secret] $($AppName) secret $($PasswordName) expired $([Math]::Abs($Timespan.Days)) days ago"
                                        }
                                    }
                                    'False' { Write-Output "[$ClientName][AppReg][Secret] $($AppName) secret $($PasswordName) expires in $($TimeSpan.Days) days" }
                                }
                            }        
                        }
                        'ExpiredOnly' {
                            if ( $IsExpired ) {
                                if ( ([Math]::Abs($Timespan.Days)) -lt $StaleThreshold -and ([Math]::Abs($Timespan.Days)) -ge 0) {
                                    Write-Output "[$ClientName][AppReg][Secret] $($AppName) secret $($PasswordName) expired $([Math]::  Abs($Timespan.Days)) days ago"
                                }
                            }
                            
                        }
                    }
                }
                if ( $App.keyCredentials) {
                    # Additional for-each loop in case the app has multiple certificates
                    foreach ($Certificate in $App.keyCredentials) {
                        $CertificateName = $Certificate.DisplayName

                        if ($CertificateName.Length -gt $strLengthThresold) {
                            $CertificateName = $CertificateName.subString(0, [System.Math]::Min($strLengthThresold, $CertificateName.Length)) + "..."
                        }
                    
                        $CertificateExpiration = $Certificate.endDateTime
                        $TimeSpan = New-TimeSpan -Start $Today -End $CertificateExpiration
                        $IsExpired = ($Timespan.Days -lt 0)

                        # Output the results based on the scope parameter and timespan status
                        switch ($Scope) {
                            'All' {
                                switch ($IsExpired) {
                                    'True' { 
                                        if ( ([Math]::Abs($Timespan.Days)) -lt $StaleThreshold -and ([Math]::Abs($Timespan.Days)) -ge 0) {
                                            Write-Output "[$ClientName][AppReg][Cert] $($AppName) certificate $($CertificateName) expired $([Math]::Abs($Timespan.Days)) days ago"
                                        }
                                    }
                                        'False' { Write-Output "[$ClientName][AppReg][Cert] $($AppName) certificate $($CertificateName) expires in $($TimeSpan.Days) days" }
                                    }        
                                }
                                'ExpiringSoonOnly' {
                                    if ($TimeSpan.Days -le $ThresholdDays) {
                                        switch ($IsExpired) {
                                            'True' { 
                                                if ( ([Math]::Abs($Timespan.Days)) -lt $StaleThreshold -and ([Math]::Abs($Timespan.Days)) -ge 0) {
                                                    Write-Output "[$ClientName][AppReg][Cert] $($AppName) certificate $($CertificateName) expired $([Math]::Abs($Timespan.Days)) days ago"
                                                }
                                            }
                                                'False' { Write-Output "[$ClientName][AppReg][Cert] $($AppName) certificate $($CertificateName) expires in $($TimeSpan.Days) days" }
                                            }
                                        }        
                                    }
                                    'ExpiredOnly' {
                                        if ( $IsExpired ) {
                                            if ( ([Math]::Abs($Timespan.Days)) -lt $StaleThreshold -and ([Math]::Abs($Timespan.Days)) -ge 0) {
                                                Write-Output "[$ClientName][AppReg][Cert] $($AppName) certificate $($CertificateName) expired $([Math]::Abs($Timespan.Days)) days ago"
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

                    $EnterpriseApps = Invoke-MSGraphRequest -HttpMethod 'GET' -Url 'https://graph.microsoft.com/v1.0/servicePrincipals'
                    $EnterpriseApps = $EnterpriseApps.Value | Sort-Object DisplayName

                    # Iterate through every app
                    foreach ($App in $EnterpriseApps) {

                        $AppName = $App.DisplayName + ":"
                        if ($AppName.Length -gt $strLengthThresold) {
                            $AppName = $AppName.subString(0, [System.Math]::Min($strLengthThresold, $AppName.Length)) + "...:"
                        }

                        # Only process apps that have secrets
                        if ( $App.passwordCredentials) {
                            # Additional for-each loop in case the app has multiple secrets
                            foreach ($Password in $App.passwordCredentials) {
                                #$PasswordName = $Password.DisplayName

                                $PasswordName = $Password.DisplayName

                                if ($PasswordName.Length -gt $strLengthThresold) {
                                    $PasswordName = $PasswordName.subString(0, [System.Math]::Min($strLengthThresold, $PasswordName.Length)) + "..."
                                }

                                $PasswordExpiration = $Password.endDateTime
                                $TimeSpan = New-TimeSpan -Start (Get-Date) -End $PasswordExpiration
                                $IsExpired = ($Timespan.Days -lt 0)

                                # Output the results based on the scope parameter and timespan status
                                switch ($Scope) {
                                    'All' {
                                        switch ($IsExpired) {
                                            'True' { 
                                                if ( ([Math]::Abs($Timespan.Days)) -lt $StaleThreshold -and ([Math]::Abs($Timespan.Days)) -ge 0) {
                                                    Write-Output "[$ClientName][EntApp][Secret] $($AppName) secret $($PasswordName) expired $([Math]::Abs($Timespan.Days)) days ago"
                                                }
                                            }
                                            'False' { Write-Output "[$ClientName][EntApp][Secret] $($AppName) secret $($PasswordName) expires in $($TimeSpan.Days) days" }
                                        }        
                                    }
                                    'ExpiringSoonOnly' {
                                        if ($TimeSpan.Days -le $ThresholdDays) {
                                            switch ($IsExpired) {
                                                'True' { 
                                                    if ( ([Math]::Abs($Timespan.Days)) -lt $StaleThreshold -and ([Math]::Abs($Timespan.Days)) -ge 0) {
                                                        Write-Output "[$ClientName][EntApp][Secret] $($AppName) secret $($PasswordName) expired $([Math]::Abs($Timespan.Days)) days ago"
                                                    }
                                                }
                                                'False' { Write-Output "[$ClientName][EntApp][Secret] $($AppName) secret $($PasswordName) expires in $($TimeSpan.Days) days" }
                                            }
                                        }        
                                    }
                                    'ExpiredOnly' {
                                        Write-Output "[$ClientName][EntApp][Secret] $($AppName) secret $($PasswordName) expired $([Math]::Abs($Timespan.Days)) days ago"
                                    }
                            
                                }
                            }
                        }
                        if ( $App.keyCredentials) {
                            # Additional for-each loop in case the app has multiple certificates
                            foreach ($Certificate in $App.keyCredentials) {
                                $CertificateName = $Certificate.DisplayName

                                if ($CertificateName.Length -gt $strLengthThresold) {
                                    $CertificateName = $CertificateName.subString(0, [System.Math]::Min($strLengthThresold, $CertificateName.Length)) + "..."
                                }
                    
                                $CertificateExpiration = $Certificate.endDateTime
                                $TimeSpan = New-TimeSpan -Start (Get-Date) -End $CertificateExpiration
                                $IsExpired = ($Timespan.Days -lt 0)

                                # Output the results based on the scope parameter and timespan status
                                switch ($Scope) {
                                    'All' {
                                        switch ($IsExpired) {
                                            'True' { 
                                                if ( ([Math]::Abs($Timespan.Days)) -lt $StaleThreshold -and ([Math]::Abs($Timespan.Days)) -ge 0) {
                                                    Write-Output "[$ClientName][EntApp][Cert] $($AppName) certificate $($CertificateName) expired $([Math]::Abs($Timespan.Days)) days ago"
                                                }
                                            }
                                            'False' { Write-Output "[$ClientName][EntApp][Cert] $($AppName) certificate $($CertificateName) expires in $($TimeSpan.Days) days" }
                                        }        
                                    }
                                    'ExpiringSoonOnly' {
                                        if ($TimeSpan.Days -le $ThresholdDays) {
                                            switch ($IsExpired) {
                                                'True' { 
                                                    if ( ([Math]::Abs($Timespan.Days)) -lt $StaleThreshold -and ([Math]::Abs($Timespan.Days)) -ge 0) {
                                                        Write-Output "[$ClientName][EntApp][Cert] $($AppName) certificate $($CertificateName) expired $([Math]::Abs($Timespan.Days)) days ago"
                                                    }
                                                }
                                                'False' { Write-Output "[$ClientName][EntApp][Cert] $($AppName) certificate $($CertificateName) expires in $($TimeSpan.Days) days" }
                                            }
                                        }        
                                    }
                                    'ExpiredOnly' {
                                        Write-Output "[$ClientName][EntApp][Cert] $($AppName) certificate $($CertificateName) expired $([Math]::Abs($Timespan.Days)) days ago"
                                    }
                                }
                            }      
                        }
                    }
      
                }

                foreach ( $ClientContext in $Client) {

                    Set-CustomerContext $clientContext
                    $Client = Get-CustomerContext
                    $ClientName = $Client.CustomerName

                    if ( $CheckApplePushCert ) { Get-ApplePushCertExpiration }
                    if ( $CheckEnterpriseApp ) { Get-AzureAppRegExpirations }
                    if ( $CheckAppReg ) { Get-AzureEnterpriseAppExpirations }
                }
    
            }