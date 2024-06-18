<#
.SYNOPSIS
This script updates mailbox permissions for a given trustee

.DESCRIPTION
This script first takes a backup of $Mailbox's current permissions. Then, it checks for existing AccessRights to $Mailbox's mailbox, contacts, and calendars. If there are any, it will remove them and re-apply $AccessRights.

1) Takes a CSV backup of $Mailbox's current permissions
2) If any mailbox AccessRights are present for $User, remove them and re-add $AccessRights (ex: FullAccess). Otherwise, just grant them $AccessRights
3) Grant $User FullAccess to $Mailbox's contacts and calendar

.PARAMETER Mailbox
The mailbox to grant the trustee access to

.PARAMETER Trustee
The user who is being granted access to the mailbox

.PARAMETER AccessRights
The level of permissions to grant trustee. In many scnearios this will be FullAccess

.PARAMETER AutoMapping
Whether or not AutoDiscover in Outlook Desktop should attempt to mount the mailbox to the trustee's mailbox. The user can manually add it to Outlook in their current OST, as a secondary OST, or use Outlook Web Access to view it there, instead

.PARAMETER ExportPath
The local directory to export the script output to

.EXAMPLE
Example: Update-EXOMailboxPermissions.ps1 -Mailbox jsmith@contoso.com -Trustee aroberts@contoso.com -AccessRights FullAccess -AutoMapping $False
Example (bulk): $users = get-content C:\TempPath\users.txt; foreach($u in $users){.\Update-EXOMailboxPermissions.ps1 -Mailbox $u -Trustee aroberts@contoso.com -AccessRights fullaccess -AutoMapping:$False}

.NOTES
This script currently assumes FullAccess is being granted and thus it grants Calendar and Contacts access. This should be updated to be more conditional based on AccessRights
#>

[CmdletBinding()]
param (
    [Parameter()]
    [string]
    $Mailbox,

    [Parameter()]
    [string]
    $Trustee,

    [Parameter()]
    [string]
    $AccessRights,

    [Parameter()]
    [boolean]
    $AutoMapping,

    [Parameter(Mandatory = $true)]
    [String]
    $ExportPath
)

function New-Folder {
    
    <#
    .SYNOPSIS
    Determine if a folder already exists, or create it  if not.

    .EXAMPLE
    New-Folder C:\TempPath
    #>

    param(
        [Parameter(Mandatory = $True)]
        [String]
        $Path
    )
    if (-not (Test-Path -LiteralPath $Path)) {
        try {
            New-Item -Path $Path -ItemType Directory -ErrorAction Stop | Out-Null
        } catch {
            Write-Error -Message "Unable to create directory '$Path'. Error was: $_" -ErrorAction Stop
        }
    } 

}

$ExportPath = $($ExportPath.TrimEnd("\")) # trim trailing "\"
New-Folder $ExportPath
$permissionsBackup = "$ExportPath\${Mailbox}_permissions_backup_$(Get-Date -Format "MM-dd-yyyy_HHmm").csv"
 
$userMailbox = Test-EXOMailbox -PrimarySmtpAddress $Mailbox -User
if ( $userMailbox ) {
    $trusteeMailbox = Test-EXOMailbox -PrimarySmtpAddress $Trustee -User
    if ( $trusteeMailbox ) {
        # 1) Grant/reapply mailbox permissions
        Write-Output "[INFO] Exporting backup of $Mailbox mailbox permissions to $permissionsBackup"
        Get-MailboxPermission -Identity $Mailbox | Export-Csv $permissionsBackup -NoTypeInformation
        # Remove and re-add permissions
        try {
            Remove-MailboxPermission -Identity $Mailbox -User $Trustee -AccessRights $AccessRights -Confirm:$false -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
            Write-Output "[INFO] Removed $Trustee $AccessRights from $Mailbox"
        } catch {
            Write-Output "[INFO] No permissions to remove, continuing ..."
        }
        try { 
            Add-MailboxPermission -Identity $Mailbox -User $Trustee -AccessRights $AccessRights -AutoMapping:$AutoMapping | Out-Null
            Write-Output "[INFO] Granted $Trustee $AccessRights to $Mailbox (AutoMapping: $AutoMapping)"
        } catch {
            Write-Output "[ERROR] Failed to grant $Trustee $AccessRights to $Mailbox. Error $($_.Exception.Message)"
        }
        # 2) Grant calendar access
        try {
            $trusteePerms = Get-MailboxFolderPermission -Identity ${Mailbox}:\Calendar -User $Trustee -ErrorAction SilentlyContinue
        } catch {
            # User does not already have permissions
        }
        if ( $trusteePerms ) {
            # If trustee has Owner, no action needed. Otherwise remove existing permissions and add owner
            if ( $trusteePerms.AccessRights -ne "Owner" ) {
                Remove-MailboxFolderPermission -Identity ${Mailbox}:\Calendar -User $Trustee -Confirm:$False
                Add-MailboxFolderPermission -Identity ${Mailbox}:\Calendar -User $Trustee -AccessRights Owner | Out-Null
                Write-Output "[INFO] Replaced ${Trustee}'s permissions over ${Mailbox}'s calendar with Owner"
            }
        } else {
            # Trustee does not have permissions. Grant them owner
            try {
                Add-MailboxFolderPermission -Identity ${Mailbox}:\Calendar -User $Trustee -AccessRights Owner -ErrorAction Stop | Out-Null
                Write-Output "[INFO] Granted $Trustee Owner to ${Mailbox}'s calendar"
            } catch {
                Write-Output "[ERROR] Failed to grant $Trustee Owner to ${Mailbox}'s calendar. Error $($_.Exception.Message)"

            }
        }
        # 3) Grant contacts access
        try {
            $trusteePerms = Get-MailboxFolderPermission -Identity ${Mailbox}:\Contacts -User $Trustee -ErrorAction SilentlyContinue
        } catch {
            # User does not already have permissions
        }
        if ( $trusteePerms ) {
            # If trustee has Owner, no action needed. Otherwise remove existing permissions and add owner
            if ( $trusteePerms.AccessRights -ne "Owner" ) {
                Remove-MailboxFolderPermission -Identity ${Mailbox}:\Contacts -User $Trustee -Confirm:$False
                Add-MailboxFolderPermission -Identity ${Mailbox}:\Contacts -User $Trustee -AccessRights Owner | Out-Null
                Write-Output "[INFO] Replaced ${Trustee}'s permissions over ${Mailbox}'s contacts with Owner"
            }
        } else {
            # Trustee does not have permissions. Grant them owner
            try {
                Add-MailboxFolderPermission -Identity ${Mailbox}:\Contacts -User $Trustee -AccessRights Owner -ErrorAction Stop | Out-Null
                Write-Output "[INFO] Granted $Trustee Owner to ${Mailbox}'s contacts"
            } catch {
                Write-Output "[ERROR] Failed to grant $Trustee Owner to ${Mailbox}'s contacts. Error $($_.Exception.Message)"

            }
        }     
    } else {
        if ( Test-EXOMailbox -PrimarySmtpAddress $Trustee -Shared ) {
            Write-Output "[ERROR] $Trustee is a shared mailbox and cannot be granted access to another mailbox. Please try again with a user mailbox"
        } else {
            Write-Output "[ERROR] Trustee user mailbox not found: $Mailbox. Please verify the address you entered is a valid user mailbox"
            exit 1
        }
    }
} else {
    Write-Output "[ERROR] User mailbox not found: $Mailbox. Please verify the address you entered is a valid user mailbox"
    exit 1
}