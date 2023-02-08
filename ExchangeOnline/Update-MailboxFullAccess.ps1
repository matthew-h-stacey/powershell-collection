[CmdletBinding()]
param (
    [Parameter()][string]$Mailbox,
    [Parameter()][string]$Trustee,
    [Parameter()][string]$AccessRights,
    [Parameter()][boolean]$AutoMapping
)

# DESCRIPTION: Backs up current permissions of a mailbox, then removes and re-adds (AccessRights) for a user with (AutoMaping) as specified
# Example: .\Update-MailboxFullAccess.ps1 -Mailbox jsmith@contoso.com -Trustee aroberts@contoso.com -AccessRights FullAccess -AutoMapping $False
# Example (bulk): $users = get-content C:\TempPath\users.txt; foreach($u in $users){.\Update-MailboxFullAccess.ps1 -Mailbox $u -Trustee aroberts@contoso.com -AccessRights fullaccess -AutoMapping:$False}

function New-Folder {
    Param([Parameter(Mandatory = $True)][String] $folderPath)
    if (-not (Test-Path -LiteralPath $folderPath)) {
        try {
            New-Item -Path $folderPath -ItemType Directory -ErrorAction Stop | Out-Null
            Write-Host "Created folder: $folderPath"
        }
        catch {
            Write-Error -Message "Unable to create directory '$folderPath'. Error was: $_" -ErrorAction Stop
        }
    }
    else {
        "$folderPath already exists, continuing ..."
    }

}

$outputPath = "C:\TempPath\"
New-Folder $outputPath
$permissionsBackup = ($outputPath + $Mailbox + "_permissions_backup_" + (Get-Date -Format "MM-dd-yyyy_HHmm") + ".csv")

Write-Host "[MODULE] Connecting to EXO"
Connect-ExchangeOnline -ShowBanner:$false

Write-Host
try{
    Get-Mailbox $Mailbox -ErrorAction Stop | Out-Null
    Write-Host "Located mailbox" $Mailbox
}
Catch{
    Write-Host "ERROR: Mailbox not found. Please try again."
    exit
}

Write-Host "Exporting backup of $($Mailbox) mailbox permissions to $permissionsBackup"
Get-MailboxPermission -Identity $Mailbox | Export-CSV $permissionsBackup -notypeinformation

# Remove and re-add permissions
write-host "Removing $Trustee $AccessRights from $Mailbox"
try {
    Remove-MailboxPermission -Identity $Mailbox -User $Trustee -AccessRights $AccessRights -Confirm:$false -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
}
catch {
    Write-Host "No permissions to remove, continuing ..."
}

write-host "Granting $Trustee $AccessRights to $Mailbox, AutoMapping set to $AutoMapping"
Add-MailboxPermission -Identity $Mailbox -User $Trustee -AccessRights $AccessRights -AutoMapping:$AutoMapping | Out-Null

Write-Host "[MODULE] Disconnecting from EXO"
Disconnect-ExchangeOnline -Confirm:$False