[CmdletBinding()]
param (
    [Parameter()][string]$Mailbox,
    [Parameter()][string]$Trustee,
    [Parameter()][string]$AccessRights,
    [Parameter()][boolean]$AutoMapping
)

# DESCRIPTION: Backs up current permissions of a mailbox, then removes and re-adds (AccessRights) for a user with (AutoMaping) as specified
# Example: .\Fix-MailboxFullAccess.ps1 -Mailbox jsmith@contoso.com -Trustee aroberts@contoso.com -AccessRights FullAccess -AutoMapping $False
# Example (bulk): $users = get-content C:\TempPath\users.txt; foreach($u in $users){.\Fix-MailboxFullAccess.ps1 -Mailbox $u -Trustee aroberts@contoso.com -AccessRights fullaccess -AutoMapping:$False}

$outputPath = "C:\TempPath\"
$permissionsBackup = ($outputPath + $Mailbox + "_permissions_backup.csv")

# Before: Check permissions of the mailbox
Write-Host
try{
    Get-Mailbox $Mailbox -ErrorAction Stop | Out-Null
    Write-Host "Located mailbox" $Mailbox
}
Catch{
    Write-Host "ERROR: Mailbox not found. Please try again."
    exit
}

if ( $null -eq (Get-Content $permissionsBackup)) { 
    Write-Host "Exporting backup of $Mailbox mailbox permissions to $permissionsBackup"
    Get-MailboxPermission -Identity $Mailbox | Export-CSV $permissionsBackup -notypeinformation
}

# Remove and re-add permissions
write-host "Removing $Trustee $AccessRights from $Mailbox"
try {
    Remove-MailboxPermission -Identity $Mailbox -User $Trustee -AccessRights $AccessRights -Confirm:$false -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
}
catch {
    Write-Host "No permissions to remove, continuing ..."
}

write-host "Granting $Trustee $AccessRights to $Mailbox, AutoMapping set to $AutoMapping"
Add-MailboxPermission -Identity $Mailbox -User $Trustee -AccessRights $AccessRights -AutoMapping:$AutoMapping -Verbose | Out-Null

# Optional: Check permissions after
# Get-MailboxPermission -Identity $Mailbox
