<#
.SYNOPSIS
Grant a trustee access to a user's mailbox/contacts/calendar

.NOTES
[ ] Add skip logic and message if trustee already has Owner over contacts/calendar
#>

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

    # Helper function
    function Add-TaskResult {
        param(
            [string]$Task,
            [string]$Status,
            [string]$Message,
            [string]$ErrorMessage = $null,
            [string]$Details = $null
        )
        $results.Add([PSCustomObject]@{
                FunctionName = $function
                Task         = $Task
                Status       = $Status
                Message      = $Message
                Details      = $Details
                ErrorMessage = $ErrorMessage
            })
    }

    # Initialize output variables
    $function = $MyInvocation.MyCommand.Name
    $task = "Grant FullAccess to mailbox/calendars/contacts"
    $status = "Failure"
    $results = [System.Collections.Generic.List[System.Object]]::new()

    $mailbox = Test-EXOMailbox -UserPrincipalName $UserPrincipalName
    if ( $mailbox ) {
        $trusteeMailbox = Test-EXOMailbox -UserPrincipalName $Trustee
        if ( $trusteeMailbox ) {
            # Grant FullAccess to the user's mailbox
            $task = "Grant FullAccess to mailbox"
            if (((Get-MailboxPermission -Identity $UserPrincipalName -User $Trustee).AccessRights) -ne "FullAccess") { 
                try {
                    Add-MailboxPermission -Identity $UserPrincipalName -User $Trustee -AccessRights FullAccess -AutoMapping $AutoMapping | Out-Null
                    $status = "Success"
                    $message = "Granted $Trustee access to $UserPrincipalName's mailbox"
                    $errorMessage = $null
                } catch {
                    $status = "Failure"
                    $message = "Failed to grant $Trustee access to $UserPrincipalName's mailbox"
                    $errorMessage = $_.Exception.Message
                }
            } else {
                $status = "Skipped"
                $message = "$Trustee already has access to $UserPrincipalName's mailbox"
                $errorMessage = $null
            }
            Add-TaskResult -Task $task -Status $status -Message $message -ErrorMessage $errorMessage
            # Grant Owner to the user's calendar
            $task = "Grant Owner to calendar"
            if ((Get-MailboxFolderPermission -Identity ${UserPrincipalName}:\Calendar).User.DisplayName -contains $trusteeMailbox.DisplayName) {
                # User already has access. Removing so Owner can be granted
                try {
                    Remove-MailboxFolderPermission -Identity ${UserPrincipalName}:\Calendar -User $Trustee -Confirm:$False
                    try { 
                        Add-MailboxFolderPermission -Identity ${UserPrincipalName}:\Calendar -User $Trustee -AccessRights Owner | Out-Null
                        $status = "Success"
                        $message = "Granted $Trustee access to $UserPrincipalName's calendar"
                        $errorMessage = $null
                    } catch {
                        $status = "Failure"
                        $message = "Failed to grant $Trustee's access to $UserPrincipalName's calendar"
                        $errorMessage = $_.Exception.Message
                    }
                } catch {
                    $status = "Failure"
                    $message = "Failed to remove $Trustee's existing access to $UserPrincipalName's calendar"
                    $errorMessage = $_.Exception.Message
                }
            } else {
                Add-MailboxFolderPermission -Identity ${UserPrincipalName}:\Calendar -User $Trustee -AccessRights Owner | Out-Null
                $status = "Success"
                $message = "Granted $Trustee access to $UserPrincipalName's calendar"
                $errorMessage = $null
            }
            Add-TaskResult -Task $task -Status $status -Message $message -ErrorMessage $errorMessage
            # Contacts
            $task = "Grant Owner to contacts"
            if ((Get-MailboxFolderPermission -Identity ${UserPrincipalName}:\Contacts).User.DisplayName -contains $trusteeMailbox.DisplayName) {
                # User already has access. Removing so Owner can be granted
                try {
                    Remove-MailboxFolderPermission -Identity ${UserPrincipalName}:\Contacts -User $Trustee -Confirm:$False
                    try { 
                        Add-MailboxFolderPermission -Identity ${UserPrincipalName}:\Contacts -User $Trustee -AccessRights Owner | Out-Null
                        $status = "Success"
                        $errorMessage = $null
                        $message = "Granted $Trustee access to $UserPrincipalName's contact"
                    } catch {
                        $status = "Failure"
                        $message = "Failed to grant $Trustee's access to $UserPrincipalName's contacts"
                        $errorMessage = $_.Exception.Message                        
                    }
                } catch {
                    $status = "Failure"
                    $message = "Failed to remove $Trustee's existing access to $UserPrincipalName's contacts"
                    $errorMessage = $_.Exception.Message                    
                }
            } else {
                Add-MailboxFolderPermission -Identity ${UserPrincipalName}:\Contacts -User $Trustee -AccessRights Owner | Out-Null
                $status = "Success"
                $errorMessage = $null
                $message = "Granted $Trustee access to $UserPrincipalName's contact"
            }
            Add-TaskResult -Task $task -Status $status -Message $message -ErrorMessage $errorMessage
        } else {
            $status = "Skipped"
            $message = "No trustee mailbox found with UserPrincipalName: $UserPrincipalName"
            Add-TaskResult -Task $task -Status $status -Message $message -ErrorMessage $errorMessage
        }
    } else {
        $status = "Skipped"
        $message = "No source mailbox found with UserPrincipalName: $UserPrincipalName"
        Add-TaskResult -Task $task -Status $status -Message $message -ErrorMessage $errorMessage
    }
    return $results
}