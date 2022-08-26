# Change these to match the user who needs permissions granted, and the AccessRights permission level
# For the breakdown of AccessRights see https://docs.microsoft.com/en-us/powershell/module/exchange/add-mailboxfolderpermission?view=exchange-ps
$addUser = (Get-EXOMailbox -Identity USER@DOMAIN.COM).UserPrincipalName
$permissionToGrant = "Reviewer"
$exportPath = "C:\TempPath"

# Get all mailboxes. Exclude the user above to leave their own calendar as-is
$allMailboxes = Get-EXOMailbox -ResultSize Unlimited | Sort-Object-Object UserPrincipalName | Select-Object -ExpandProperty UserPrincipalName
$allMailboxesExcl = $allMailboxes | Where-Object { $_ -notLike "$addUser" }

# Back up current calendar permissions
$results = @()
foreach ($m in$allMailboxesExcl) {
    $currentPermission = Get-EXOMailboxFolderPermission -Identity $m":\Calendar" | Select-Object Identity, FolderName, User, AccessRights
    $results += $currentPermission
}
$results | Select-Object Identity, FolderName, User, @{l = 'AccessRights'; e = { $_.AccessRights } } | Export-Csv $exportPath\CalendarPermissionsReport_BEFORE.csv -NoTypeInformation

# Grant user permission to each calendar. Skip any calendars they already have explicit access to
foreach ($m in $allMailboxesExcl) {
    Add-MailboxFolderPermission -Identity $m":\Calendar" -User $addUser -AccessRights $permissionToGrant -ErrorAction SilentlyContinue
}

# Optional block: Re-run and export the updated permissions for review (comment out this block if not needed)
$results = @()
foreach ($m in$allMailboxesExcl) {
    $currentPermission = Get-EXOMailboxFolderPermission -Identity $m":\Calendar" | Select-Object Identity, FolderName, User, AccessRights
    $results += $currentPermission
}
$results | Select-Object Identity, FolderName, User, @{l = 'AccessRights'; e = { $_.AccessRights } } | Export-Csv $exportPath\CalendarPermissionsReport_AFTER.csv -NoTypeInformation