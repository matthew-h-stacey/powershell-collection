Param
(   
    [Parameter(Mandatory = $true)] [string] $spoURL,
    [Parameter(Mandatory = $true)] [string] $spoSiteURL,
    [Parameter(Mandatory = $true)] [string] $trusteeUser
)
# Used to grant a user access to an SPO/OneDrive site

try {
    $sitecheck = Get-SPOSite $spoSiteURL
}
catch [Microsoft.SharePoint.Client.ServerException] {
    Write-Host -foreground Yellow "[SPO] You are not connected!"
    Connect-SPOService -Url $spoUrl
}

# Get-SPOSite | sort Url for assistance locating the spoSiteURL
Set-SPOUser -Site $spoSiteUrl -LoginName $trusteeUser -IsSiteCollectionAdmin $true
