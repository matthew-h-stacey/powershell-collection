param(
    [Parameter(Mandatory = $true)] [string] $Domain
)

Write-Host "Log into MSOnline first with your own credentials"
Connect-MsolService

function Get-MsolTenantID {
    $TenantID = (Get-MsolPartnerContract | Where-Object { $_.DefaultDomainName -like "*$Domain*" } -ErrorAction Stop | Select-Object -ExpandProperty TenantID).Guid
    if ($null -eq $TenantID) { Write-Host "No TenantID located for the domain, verify the domain is correct and try again" }
    return $TenantID
}

Get-MsolTenantID -Domain $Domain    
