# https://docs.microsoft.com/en-us/onedrive/list-onedrive-urls

$TenantUrl = Read-Host "Enter the SharePoint admin center URL"
$LogFile = [Environment]::GetFolderPath("Desktop") + "\OneDriveSites.log"
Connect-SPOService -Url $TenantUrl
Get-SPOSite -IncludePersonalSite $true -Limit all -Filter "Url -like '-my.sharepoint.com/personal/'" | Select -ExpandProperty Url | Out-File $LogFile -Force
Write-Host "Done! File saved as $($LogFile)."