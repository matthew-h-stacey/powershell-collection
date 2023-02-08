function Get-AppRegistrationExpiration {

    param(

        [Parameter(Mandatory = $true)]
        [ValidateSet("All", "ExpiringSoonOnly")]
        [string]$Scope
    )

    $threshold = 90 # default threshold for number of days to be considered "soon" for expiration purposes

    $appRegistrations = (Invoke-MSGraphRequest -HttpMethod 'GET' -Url 'https://graph.microsoft.com/v1.0/applications').Value
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
            # if-statement to check if the object has a password with an expiration set
            # Check for expiring passwords (secrets)
            
            if ( $r.PasswordExpiration.Length -eq 1) {
                $pwExpirationDate = $r.PasswordExpiration
                $timespan = New-TimeSpan -Start (Get-Date) -End $pwExpirationDate

                switch ($Scope) {
                    "All" {
                        Write-Output "[AppReg] $($r.DisplayName) secret $($PasswordName)expires in: $($timespan.Days) days"
                    } `
                        "ExpiringSoonOnly" {
                        if ($timespan.Days -le $threshold) {
                            Write-Output "WARNING: [AppReg] $($r.DisplayName) secret $($PasswordName)expires in: $($timespan.Days) days"
                        }
                    }
                }
            }
            if ($r.PasswordExpiration.Length -gt 1) {
                # if the App Reg has multiple certificates
                $pwExpirationDates = $r.passwordExpiration                
                foreach ( $secret in $pwExpirationDates) { 
                    $timespan = New-TimeSpan -Start (Get-Date) -End $secret

                    switch ($Scope) {
                        "All" {
                            Write-Output "[AppReg] $($r.DisplayName) secret $($CertName)expires in: $($timespan.Days) days"
                        } `
                            "ExpiringSoonOnly" {
                            if ($timespan.Days -le $threshold) {
                                Write-Output "WARNING: [AppReg] $($r.DisplayName) secret $($CertName)expires in: $($timespan.Days) days"
                            }
                        }
                    }

                }

            }

        }
        if ($null -ne $r.CertExpiration ) {
            # Check for expiring certificates
            if ( $r.CertExpiration.Length -eq 1) {
                # if the App Reg has a single certificate
                $certExpirationDate = $r.CertExpiration
                $timespan = New-TimeSpan -Start (Get-Date) -End $certExpirationDate
                
                switch ($Scope) {
                    "All" {
                        Write-Output "[AppReg] $($r.DisplayName) certificate $($CertName)expires in: $($timespan.Days) days"
                    } `
                        "ExpiringSoonOnly" {
                        if ($timespan.Days -le $threshold) {
                            Write-Output "WARNING: [AppReg] $($r.DisplayName) certificate $($CertName)expires in: $($timespan.Days) days"
                        }
                    }
                }
            }
            if ($r.CertExpiration.Length -gt 1) {
                # if the App Reg has multiple certificates
                $certExpirationDates = $r.CertExpiration                
                foreach ( $cert in $certExpirationDates) { 
                    $timespan = New-TimeSpan -Start (Get-Date) -End $cert

                    switch ($Scope) {
                        "All" {
                            Write-Output "[AppReg] $($r.DisplayName) certificate $($CertName)expires in: $($timespan.Days) days"
                        } `
                            "ExpiringSoonOnly" {
                            if ($timespan.Days -le $threshold) {
                                Write-Output "WARNING: [AppReg] $($r.DisplayName) certificate $($CertName)expires in: $($timespan.Days) days"
                            }
                        }
                    }

                }

            }
        }
    }
}