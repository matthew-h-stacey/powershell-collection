# https://docs.microsoft.com/en-us/onedrive/restore-deleted-onedrive

$adminURL = "https://contoso-admin.sharepoint.com"
$personalURL = "https://contoso-my.sharepoint.com/personal/bbob_contoso_com"
$trustee = "jsmith@contoso.com"

Connect-SPOService -Url $adminURL 

Restore-SPODeletedSite -Identity $personalURL

# Assign an administrator to the OneDrive to access the needed data:
Set-SPOUser -Site $personalURL -LoginName $trustee -IsSiteCollectionAdmin $True
