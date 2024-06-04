# Objective: Connect to a client tenant using delegated access
# Usage: .\Connect-DelegatedExchangeOnline.ps1 -Domain contoso.com
# At the sign-in prompt, use your own credentials instead of signing in a specific Office 365 admin account

param(   
    [Parameter(Mandatory = $true)]
    [string]
    $Domain
)

Connect-ExchangeOnline -DelegatedOrganization $Domain -ShowBanner:$false