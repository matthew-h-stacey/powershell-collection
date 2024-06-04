function Add-EXOMailboxFullAccess {

    param(
        [Parameter(Mandatory = $true)]
        [String]
        $UserPrincipalName,
        
        [Parameter(Mandatory = $true)]
        [String]
        $Trustee,

        [Parameter(Mandatory = $true)]
        [Boolean]
        $AutoMapping

    )

    if ( !(Test-EXOMailbox -UserPrincipalName $UserPrincipalName) ) {
        return "[Mailbox access] Skipped, no mailbox found for $UserPrincipalName"
        exit
    }

    $trusteeMailbox = Get-Mailbox -Identity $Trustee

    # Mailbox
    if (((Get-MailboxPermission -Identity $UserPrincipalName -User $Trustee).AccessRights) -ne "FullAccess") { 
        
        try {
            Add-MailboxPermission -Identity $UserPrincipalName -User $Trustee -AccessRights FullAccess -AutoMapping $AutoMapping | Out-Null
            Write-Output "[Mailbox access] Granted $Trustee access to $UserPrincipalName's mailbox"
        } catch {
            Write-Output "[Mailbox access] Failed to grant $Trustee access to $UserPrincipalName's mailbox. Error:"
            $_.Exception.Message
        }
        
    } else {
        Write-Output "[Mailbox access] $Trustee already has access to $UserPrincipalName's mailbox"
    }

    # Calendar
    if ((Get-MailboxFolderPermission -Identity ${UserPrincipalName}:\Calendar).User.DisplayName -contains $trusteeMailbox.DisplayName) {
        # User already has access. Removing so Owner can be granted
        try {
            Remove-MailboxFolderPermission -Identity ${UserPrincipalName}:\Calendar -User $Trustee -Confirm:$False
        } catch {
            Write-Output "[Mailbox access] Failed to remove $Trustee's existing access to $UserPrincipalName's calendar. Error:"
            $_.Exception.Message
        }
    }
    try { 
        Add-MailboxFolderPermission -Identity ${UserPrincipalName}:\Calendar -User $Trustee -AccessRights Owner | Out-Null
        Write-Output "[Mailbox access][Calendar] Granted $Trustee access to $UserPrincipalName's calendar"
    } catch {
        Write-Output "[Mailbox access][Calendar] Failed to grant $Trustee's access to $UserPrincipalName's calendar. Error:"
        $_.Exception.Message
    }

    # Contacts
    if ((Get-MailboxFolderPermission -Identity ${UserPrincipalName}:\Contacts).User.DisplayName -contains $trusteeMailbox.DisplayName) {
        # User already has access. Removing so Owner can be granted
        try {
            Remove-MailboxFolderPermission -Identity ${UserPrincipalName}:\Contacts -User $Trustee -Confirm:$False
        } catch {
            Write-Output "[Mailbox access] Failed to remove $Trustee's existing access to $UserPrincipalName's contacts. Error:"
            $_.Exception.Message
        }
    }
    try { 
        Add-MailboxFolderPermission -Identity ${UserPrincipalName}:\Contacts -User $Trustee -AccessRights Owner | Out-Null
        Write-Output "[Mailbox access][Contacts] Granted $Trustee access to $UserPrincipalName's contacts"
    } catch {
        Write-Output "[Mailbox access][Contacts] Failed to grant $Trustee's access to $UserPrincipalName's contacts. Error:"
        $_.Exception.Message
    }

}