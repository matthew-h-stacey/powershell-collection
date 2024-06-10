<#
.SYNOPSIS
Connect to a client tenant using delegated access

.PARAMETER Domain
The primary domain of the tenant to connect to

.EXAMPLE
Connect-DelegatedExchangeOnline.ps1 -Domain contoso.com
#>

param(   
    [Parameter(Mandatory = $true)]
    [string]
    $Domain
)

Connect-ExchangeOnline -DelegatedOrganization $Domain -ShowBanner:$false