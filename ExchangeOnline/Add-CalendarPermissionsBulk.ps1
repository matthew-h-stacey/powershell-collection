$users = get-content C:\temppath\clientmeetings_RW.txt
$mailbox = "Phenovista Client Meetings"
$accessRights = "Editor"

function Get-Users {
    foreach ( $u in $users) {

        $warnings = @()
        try {
            $mb = get-mailbox -identity $u -ErrorAction Stop
            Write-Host "Found mailbox: $($mb.Identity)"
        }
        catch {
            $warning = Write-Warning "Unable to find mailbox for $($u)"
            $warnings += $warning

        }
    
    }

}


function Add-CalendarPermissions {
    foreach ($u in $users){
        try {
            Write-Host "Adding user $($u) to calendar $($mailbox) with AccessRights of $($AccessRights)"
            Add-MailboxFolderPermission -Identity  "$($mailbox):\Calendar" -User $u -AccessRights $AccessRights | Out-Null # add user and suppress default output
        }
        catch {
            Write-Warning "Error occurred while adding user $($u) to calendar $($mailbox)"
        }
        
    }
}


#1)  find recipient
Get-Recipient -Filter {DisplayName -like "*sci*"} | select DisplayName,RecipientType*
# if SharedMailbox, proceed
#2) create txt file with users based on Excel sheet
#3) modify lines 1-3 as needed
#4) run Get-Users to verify mailboxes, tehn Add-CalendarPermissions