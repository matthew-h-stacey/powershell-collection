param (
    [Parameter(Mandatory = $true)]
    [string]
    $CertificateThumbprint,

    [Parameter(Mandatory = $true)]
    [string]
    $ClientId,

    [Parameter(Mandatory = $true)]
    [string]
    $TenantId,

    [Parameter(Mandatory = $true)]
    [string]
    $MailFrom,

    [Parameter(Mandatory = $true)]
    [string]
    $MailSubject,

    [Parameter(Mandatory = $true)]
    [ValidateSet("All", "ExpiringSoonOnly", "ExpiredOnly")]
    [string]
    $Scope,

    [Parameter(Mandatory = $false)]
    [int]
    $ExpiringWithinDays = 14
)

function Get-ADUserPasswordResetReport {

    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet("All", "ExpiringSoonOnly", "ExpiredOnly")]
        [string]
        $Scope,

        [int]
        $ExpiringWithinDays = 14
    )

    $today = Get-Date
    $results = [System.Collections.Generic.List[System.Object]]::new()
    $users = Get-ADUser -Filter {Enabled -eq $true -and mail -ne "$null"} -Properties displayName,mail,passwordLastSet,passwordNeverExpires,msDS-UserPasswordExpiryTimeComputed | Sort-Object DisplayName
        foreach ($user in $users) {
        $includeUser = $false
        # Retrieve password expiration details. If pw never expires/no expiration can be computed, set to $null
        $passwordNeverExpires = $user.passwordNeverExpires
        if ( $passwordNeverExpires -or -not $user."msDS-UserPasswordExpiryTimeComputed") {
            $passwordExpiresOn = $null
            $passwordDaysUntilExpiration = $null
            $passwordIsExpired = $false
        } else {
            $passwordExpiresOn = [datetime]::FromFileTime($user."msDS-UserPasswordExpiryTimeComputed")
            $passwordDaysUntilExpiration = (New-TimeSpan -Start $today -End $passwordExpiresOn).Days
            $passwordIsExpired = $passwordDaysUntilExpiration -lt 0
        }
        switch ( $Scope ) { 
            "All" {
                $includeUser = $true
            }
            "ExpiringSoonOnly" {
                if (-not $passwordNeverExpires -and $passwordDaysUntilExpiration -ge 0 -and $passwordDaysUntilExpiration -lt $ExpiringWithinDays ) {
                    $includeUser = $true
                }
            }
            "ExpiredOnly" {
                if ( $passwordIsExpired -eq $true ) {
                    $includeUser = $true
                }
            }
        }
        # Add user to the list for output
        if ( $includeUser ) {
            $results.Add(
                [pscustomobject]@{
                    GivenName = $user.GivenName
                    DisplayName = $user.displayName
                    Email = $user.mail
                    passwordNeverExpires = $user.passwordNeverExpires
                    passwordLastSet = $user.passwordLastSet
                    passwordExpiresOn = $passwordExpiresOn
                    passwordDaysUntilExpiration = $passwordDaysUntilExpiration
                    passwordIsExpired = $passwordIsExpired
                }
            )
        }
    }
    return $results

}

try {
    Connect-MgGraph -CertificateThumbprint $CertificateThumbprint -ClientId $ClientId -TenantId $TenantId -NoWelcome
} catch {
    return "Failed to connect to MgGraph. Error: $($_.Exception.Message)"
    exit
}
$expirationReport = Get-ADUserPasswordResetReport -Scope $Scope -ExpiringWithinDays $ExpiringWithinDays

foreach ( $user in $expirationReport ) {
    $mailTo = $user.Email
    # TEMPORARY OVERRIDE FOR TESTING
    $mailTo = "mstacey@bcservice.tech"
    # Format message body based on expired/expiring soon
    if ( $user.passwordDaysUntilExpiration -eq 0 ) {
        $mailBody = "<p>Hi $($user.GivenName),</p><p>This is an automated notification from BCS365 informing you that your password expires in $($user.passwordDaysUntilExpiration) days. Please update your password at your earliest convenience to avoid disruption.</p><p>Thank you,<br />BCS365</p>"    
    } else {
        $mailBody = "<p>Hi $($user.GivenName),</p><p>This is an automated notification from BCS365 informing you that your password has expired. Please update your password at your earliest convenience to avoid disruption.</p><p>Thank you,<br />BCS365</p>"
    }

    $params = @{
        message = @{
            subject = $MailSubject
            importance = "High"
            body = @{
                contentType = "HTML"
                content = $mailBody
            }
            toRecipients = @(
                @{
                    emailAddress = @{
                        address = $mailTo
                    }
                }
            )
        }
        saveToSentItems = "false"
    }
    Send-MgUserMail -UserId $mailFrom -BodyParameter $params
}

Disconnect-MgGraph | Out-Null
