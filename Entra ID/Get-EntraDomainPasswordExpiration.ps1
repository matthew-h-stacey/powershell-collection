function Get-EntraDomainPasswordExpiration {
    $primaryDomain = Get-MgDomain | Where-Object { $_.IsDefault }
    if (-not $primaryDomain) {
        Write-Warning "Could not retrieve the default domain. Ensure you have the necessary permissions and that a default domain is set."
        return
    }
    $pwNeverExpires = $false
    $pwMaxAge = $null
    switch ($primaryDomain.PasswordValidityPeriodInDays) {
        2147483647 {
            $pwNeverExpires = $true
            $pwMaxAge = $null
        }
        default {
            $pwNeverExpires = $false
            $pwMaxAge = [int]$primaryDomain.PasswordValidityPeriodInDays
        }
    }
    $domainADSynced = (Get-MgOrganization).VerifiedDomains.Name -contains $primaryDomain.Id
    return [PSCustomObject]@{
        Domain                  = $primaryDomain.Id
        DomainADSynced          = $domainADSynced
        PasswordNeverExpires    = $pwNeverExpires
        PasswordMaxAge          = $pwMaxAge
    }
}