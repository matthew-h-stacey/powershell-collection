Param(
    [Parameter(Mandatory = $True)][string]$Mailbox
)

# Root directory
$folderPath = "C:\TempPath\$Mailbox"

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

New-Folder $folderPath

### Retrieve all rules for the mailbox, recursively output them to the folder above
# Replace entries to prevent issue with outputting rules that have invalid characters
$userRules = Get-InboxRule -Mailbox $Mailbox -IncludeHidden
foreach ($r in $userRules){
    $file = "$folderPath\" + ($r.Name.Split([IO.Path]::GetInvalidFileNameChars()) -join '_') + ".txt"
    # $file = "$folderPath\" + ($r.Name).Replace("/", " ").Replace('(', "").Replace(')', "").Replace(":", "") + ".txt"
    $r | Select-Object * | Out-File $file
}
Write-Host "Exported rules to: $folderPath"

Get-MailboxJunkEmailConfiguration -Identity $Mailbox  | Select-Object -ExpandProperty BlockedSendersAndDomains | Out-File ("$folderPath\" + "_BlockedSendersAndDomains.txt")
Write-Host "Exported BlockedSendersAndDomains to: $folderPath"

# Example: Remove entry from safe/blocked senders
# Set-MailboxJunkEmailConfiguration -Identity $Mailbox -BlockedSendersAndDomains @{Remove = "success-services@salesforce.com" }
