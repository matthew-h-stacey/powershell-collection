Param
(   
    [Parameter(Mandatory = $true)] [string] $spoURL,
    [Parameter(Mandatory = $true)] [string] $spoSiteURL,
    [Parameter(Mandatory = $true)] [string] $trusteeUser
)
# Used to grant a user access to an SPO/OneDrive site

if ( $PSVersionTable.PSVersion.Major -ge 7) { # adding for Powershell 7 compatibility
    Import-Module Microsoft.Online.SharePoint.PowerShell -UseWindowsPowershell -WarningAction SilentlyContinue | Out-Null
}


try { $sitecheck = Get-SPOSite $spoURL }
catch {
Write-Host -foreground Yellow "You are not connected!"
Connect-SPOService -Url $spoUrl
}

# Get-SPOSite | sort Url for assistance locating the spoSiteURL
Set-SPOUser -Site $spoSiteUrl -LoginName $trusteeUser -IsSiteCollectionAdmin $true
