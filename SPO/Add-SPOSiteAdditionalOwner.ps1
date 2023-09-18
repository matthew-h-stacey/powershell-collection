function Add-SPOSiteAdditionalOwner {

    param(
        [Parameter(Mandatory=$True)]
        [String]$UserPrincipalName,

        [Parameter(Mandatory=$True)]
        [String]$OneDriveTrustee
        
    )

    try {
        $SPOSiteUrl  = Get-SPOSite -Filter { Url -like "/personal/" } -IncludePersonalSite $true | Where-Object{$_.Owner -like $UserPrincipalName} | Select-Object -ExpandProperty Url
    }
    catch {
        throw "[OneDrive] Failed to locate a OneDrive URL for $UserPrincipalName. Unable to grant $OneDriveTrustee access. Error:"
        $_.Exception.Message

    }
    
    try {
        Set-SPOUser -Site $SPOSiteUrl -LoginName $OneDriveTrustee -IsSiteCollectionAdmin $true | Out-Null
        Write-Output "[OneDrive] Granted $OneDriveTrustee access to $UserPrincipalName's OneDrive"
    }
    catch {
        Write-Output "[OneDrive] Failed to grant $OneDriveTrustee access to $UserPrincipalName's OneDrive. Error:"
        $_.Exception.Message
    }
	
}