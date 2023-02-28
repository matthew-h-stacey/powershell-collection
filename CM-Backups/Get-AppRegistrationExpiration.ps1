<#
.SYNOPSIS
Check Azure App Registrations for expiring secrets or certificates.

.DESCRIPTION
This script queries Azure App Registrations using Microsoft Graph API and checks each one of them for any secrets or certificates that are about to expire soon. The script compares the secret/certificate expiration date against the current date plus a threshold (default value: 90 days) to determine if they are expiring soon or not.

.PARAMETER Client
A selectable array of clients.

.PARAMETER Scope
Specifies the scope of the search. The value can be "All" (searches all App Registrations) or "ExpiringSoonOnly" (searches only App Registrations with expiring secrets/certificates).

.EXAMPLE
PS C:> Get-AppRegistrationExpiration -Client $customerContext -Scope All

This command searches the App Registrations for the customers in $customerContext and returns only those with expiring secrets/certificates.

.NOTES
Author: Matt Stacey
Version: 1.0
Date: Feb 21, 2023
#>

function Get-AppRegistrationExpirationv2 {

    [SkyKickCommand(DisplayName = "Set Parameter Sections", Sections = { "Client", "Scope", "ExpiringSoonOnly" })]
    param(
        [SkyKickParameter(
            DisplayName = "Client",
            Section = "Client",
            DisplayOrder = 1
        )]
        [Parameter(Mandatory = $true)][CustomerContext[]]$Client,

        [SkyKickParameter(
            DisplayName = "Scope of expiration check",    
            Section = "Scope",
            DisplayOrder = 1,
            HintText = "Select 'All' to report on expiration of all certs/secrets, or use 'ExpiringSoonOnly' to retrieve only certs/secrets that are expiring soon."
        )]
        [Parameter (Mandatory = $true)][ValidateSet("All", "ExpiringSoonOnly")][String]$Scope,
    
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
            DisplayOrder = 2,
            HintText = "Enter the number of days to be considered 'soon' (ex: 90 days)"
        )][int]$ThresholdDays
    )




    $strLengthThresold = 40 # truncate app name/secret name/certificate names that are longer than X characters long for cleaner output

    foreach ( $ClientContext in $Client) {

        Set-CustomerContext $clientContext
        $Client = Get-CustomerContext
        $ClientName = $Client.CustomerName

        # Retrieve all App Registrations
        $appRegistrations = Invoke-MSGraphRequest -HttpMethod 'GET' -Url 'https://graph.microsoft.com/v1.0/applications'
        $appRegistrations = $appRegistrations.Value | Sort-Object DisplayName

        # Iterate through every app
        foreach ($App in $AppRegistrations) {

            $AppName = $App.DisplayName+":"
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
                                'True' { Write-Output "[$ClientName][AppReg][Secret] $($AppName) secret $($PasswordName) expired $([Math]::Abs($Timespan.Days)) days ago" }
                                'False' { Write-Output "[$ClientName][AppReg][Secret] $($AppName) secret $($PasswordName) expires in $($TimeSpan.Days) days" }
                            }        
                        }
                        'ExpiringSoonOnly' {
                            if ($TimeSpan.Days -le $ThresholdDays) {
                                switch ($IsExpired) {
                                    'True' { Write-Output "[$ClientName][AppReg][Secret] $($AppName) secret $($PasswordName) expired $([Math]::Abs($Timespan.Days)) days ago" }
                                    'False' { Write-Output "[$ClientName][AppReg][Secret] $($AppName) secret $($PasswordName) expires in $($TimeSpan.Days) days" }
                                }
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
                    $TimeSpan = New-TimeSpan -Start (Get-Date) -End $CertificateExpiration
                    $IsExpired = ($Timespan.Days -lt 0)

                    # Output the results based on the scope parameter and timespan status
                    switch ($Scope) {
                        'All' {
                            switch ($IsExpired) {
                                'True' { Write-Output "[$ClientName][AppReg][Cert] $($AppName) certificate $($CertificateName) expired $([Math]::Abs($Timespan.Days)) days ago" }
                                'False' { Write-Output "[$ClientName][AppReg][Cert] $($AppName) certificate $($CertificateName) expires in $($TimeSpan.Days) days" }
                            }        
                        }
                        'ExpiringSoonOnly' {
                            if ($TimeSpan.Days -le $ThresholdDays) {
                                switch ($IsExpired) {
                                    'True' { Write-Output "[$ClientName][AppReg][Cert] $($AppName) certificate $($CertificateName) expired $([Math]::Abs($Timespan.Days)) days ago" }
                                    'False' { Write-Output "[$ClientName][AppReg][Cert] $($AppName) certificate $($CertificateName) expires in $($TimeSpan.Days) days" }
                                }
                            }        
                        }
                    }
                }      
            }
        }
    }
}