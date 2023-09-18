<#
.SYNOPSIS
    This script adds a secondary site collector to all OneDrive sites in a SharePoint tenant.
    This is a required step when migrating files from an on-prem server to users OneDrive.

.DESCRIPTION
    The Add-OneDriveSecondaryAdmin function connects to the SharePoint Online service and retrieves all OneDrive URLs in the tenant. 
    It then adds the specified user as a secondary site administrator to each OneDrive site.
    Commonly used when migrating from on-prem DFS to OneDrive Known Folder Backup for users Desktop, Documents and Pictures.  

.PARAMETER SiteURL
    The URL of the SharePoint Online admin site.

.PARAMETER SecondaryAdmin
    The username of the user to add as a secondary site administrator.

.NOTES
    Author: CJ Tarbox
    Date: March 28, 2023
    Tags: #OneDriveProject
#>


# define clients Sharepoint URL and the user account that will be added as Secondary admin to each users onedrive
$SiteURL = "https://contoso.sharepoint.com/"
$SecondaryAdmin = "admin@contoso.com"

Function Add-OneDriveSecondaryAdmin {
    Param(
        [Parameter(Mandatory=$true,Position=0)]
        [string]$SiteURL,
        [Parameter(Mandatory=$true,Position=1)]
        [string]$SecondaryAdmin
    )
    
    #Connect SPO service.
    Connect-SPOService -Url $SiteURL

    #Get all OneDrive URL's.
    $OneDriveURLs = Get-SPOSite -IncludePersonalSite $true -Limit All -Filter "Url -like '-my.sharepoint.com/personal/'"
    
    foreach($OneDriveURL in $OneDriveURLs)
    {
        #Add Secondary administrator to Onedrive Site.
        Set-SPOUser -Site $OneDriveURL.URL -LoginName $SecondaryAdmin -IsSiteCollectionAdmin $True -ErrorAction SilentlyContinue
        Write-Host "Added secondary admin to the site $($OneDriveURL.URL)" 
    }
}

Add-OnedriveSecondaryAdmin -SiteURL $SiteURL -SecondaryAdmin $SecondaryAdmin