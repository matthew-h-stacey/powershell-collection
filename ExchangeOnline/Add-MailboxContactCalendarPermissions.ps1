Param
(   
    [Parameter(Mandatory = $true)] [string[]] $UserPrincipalName,
    [Parameter(Mandatory = $true)] [string] $Trustee
)

# Grant Trustee access to a user's mailbox, calendar, and contacts (ex: as part of offboarding)

Write-Host "Granting $($Trustee) access to $($UserPrincipalName)'s mailbox, calendar, and contacts"

foreach ($u in $UserPrincipalName) {
    Add-MailboxPermission -Identity "$u" -User "$Trustee" -AccessRights "FullAccess"
    Add-MailboxFolderPermission -Identity "${u}:\Calendar" -User "$Trustee" -AccessRights Editor
    Add-MailboxFolderPermission -Identity "${u}:\Contacts" -User "$Trustee" -AccessRights Editor
}