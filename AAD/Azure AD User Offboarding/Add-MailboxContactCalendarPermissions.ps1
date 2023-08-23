Param
(   
    [Parameter(Mandatory = $true)] [string[]] $UserPrincipalName,
    [Parameter(Mandatory = $true)] [string] $Trustee,
    [Parameter(Mandatory = $false)] [boolean] $Calendar,
    [Parameter(Mandatory = $false)] [boolean] $Contacts,
    [Parameter(Mandatory = $false)] [boolean] $AutoMapping
)

# Grant Trustee access to User's mailbox, calendar, and contacts

foreach ($u in $UserPrincipalName) {

    # Grant access to mailbox if the user doesn't already have access

    if (((Get-MailboxPermission -Identity $u -User $Trustee).AccessRights) -ne "FullAccess") { 
        Write-Output "[EXO] Granting $($Trustee) access to $($UserPrincipalName)'s mailbox"
        Add-MailboxPermission -Identity $u -User $Trustee -AccessRights FullAccess -AutoMapping $AutoMapping | Out-Null
    }
    else {
        write-output "[EXO] $($Trustee) already has access to the mailbox, skipping..."
    }

    # Optional: Grant access to user's calendar if the user doesn't already have access
    if($Calendar) {
        if ((Get-MailboxFolderPermission -Identity ${u}:\Calendar -User $Trustee -ErrorAction SilentlyContinue).AccessRights -ne "Editor") { 
            Write-Output "[EXO] Granting $($Trustee) access to $($UserPrincipalName)'s calendar"
            Add-MailboxFolderPermission -Identity "${u}:\Calendar" -User "$Trustee" -AccessRights Editor | Out-Null
            }
        else {
                write-output "[EXO] $($Trustee) already has access to user calendar, skipping..."
            }
    }


    # Optional: Grant access to the user's contacts if the user doesn't already have access
    if($Contacts) {
        if (((Get-MailboxFolderPermission -Identity ${u}:\Contacts -User $Trustee -ErrorAction SilentlyContinue).AccessRights) -ne "Editor") { 
            Write-Output "[EXO] Granting $($Trustee) access to $($UserPrincipalName)'s contacts"
            Add-MailboxFolderPermission -Identity "${u}:\Contacts" -User "$Trustee" -AccessRights Editor | Out-Null
            }
            else {
                write-output "[EXO] $($Trustee) already has access to user contacts, skipping..."
            }
    }



}