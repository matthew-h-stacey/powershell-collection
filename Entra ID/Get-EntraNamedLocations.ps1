function Get-EntraNamedLocations {
    <#
    .SYNOPSIS
    Returns an array of hash tables containing all named locations in a tenant. Requires at least Policy.Read.All

    .EXAMPLE
    $locations = Get-EntraNamedLocations
    #>
    
    $namedLocations = @()
    Get-MgIdentityConditionalAccessNamedLocation | ForEach-Object {
        if ( $_.AdditionalProperties.ipRanges.cidrAddress ) {
            $namedLocations += @{
                DisplayName = $_.DisplayName
                CidrRange   = $_.AdditionalProperties.ipRanges.cidrAddress
            }
        }
    }
    return $namedLocations
}