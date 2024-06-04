param(
    [Parameter(Mandatory = $True)]
    [string]
    $Mailbox,

    # Path to export results to
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

$ExportPath = $($ExportPath.TrimEnd("\")) # trim trailing "\""
New-Folder $ExportPath\$Mailbox

# Retrieve all rules for the mailbox, recursively output them to the folder above
# Replace invalid characters in rule names where applicable
$userRules = Get-InboxRule -Mailbox $Mailbox -IncludeHidden
foreach ($r in $userRules){
    $file = "$ExportPath\" + ($r.Name.Split([IO.Path]::GetInvalidFileNameChars()) -join '_') + ".txt"
    $r | Select-Object * | Out-File $file
}
Write-Output "Exported rules to: $ExportPath"

Get-MailboxJunkEmailConfiguration -Identity $Mailbox  | Select-Object -ExpandProperty BlockedSendersAndDomains | Out-File ("$ExportPath\" + "_BlockedSendersAndDomains.txt")
Write-Output "Exported BlockedSendersAndDomains to: $ExportPath"

# Example: Remove entry from safe/blocked senders
# Set-MailboxJunkEmailConfiguration -Identity $Mailbox -BlockedSendersAndDomains @{Remove = "success-services@salesforce.com" }
