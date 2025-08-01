<#
.SYNOPSIS
    This script exports all mailbox rules for a mailbox to a folder.

.PARAMETER Mailbox
    The mailbox to export rules from. This can be a user mailbox or a shared mailbox.

.PARAMETER ExportPath
    The path where the exported rules will be saved. If the folder does not exist, it will be created.

.NOTES
    The default "Junk E-mail Rule" is excluded from the export
    Blocked senders and domains are exported to a separate file
        In some cases, a user reports an email was not delivered but message logs show it was
        If a message rule is not the culprit, it may be due to a blocked sender or domain
        For that reason, this script also exports their blocked senders.

.EXAMPLE
    Get-EXOMailboxRules -Mailbox jsmith@contoso.com -ExportPath "C:\TempPath"
#>

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

# Create output folder if it does not exist
$finalExportPath = Join-Path -Path $ExportPath -ChildPath $Mailbox
if (-not (Test-Path -LiteralPath $finalExportPath)) {
    New-Folder -Path $finalExportPath
}

# Retrieve all rules for the mailbox and output them to the folder above
# Note: This excludes the default "Junk E-mail Rule" which is not user-created
$userRules = Get-InboxRule -Mailbox $Mailbox -IncludeHidden | Where-Object { $_.Name -notlike "Junk E-mail Rule" } | Sort-Object Name
if ( $userRules.Count -gt 0 ) {
    foreach ($r in $userRules) {
        $fileName = ($r.Name.Split([IO.Path]::GetInvalidFileNameChars()) -join '_')
        $ruleOutputPath = Join-Path -Path $finalExportPath -ChildPath "$fileName.txt"
        $r | Select-Object * | Out-File $ruleOutputPath
    }
    Write-Output "[INFO] Exported $($userRules.Count) mailbox rule(s) to: $finalExportPath"
} else {
    Write-Output "[INFO] No user-created rules found for $Mailbox"
}

$blockedSenders = Get-MailboxJunkEmailConfiguration -Identity $Mailbox  | Select-Object -ExpandProperty BlockedSendersAndDomains
if ( $blockedSenders ) {
    Write-Output "[INFO] Found $($blockedSenders.Count) blocked senders/domains for $Mailbox"
    $blockedSendersOutputPath = Join-Path $finalExportPath -ChildPath "BlockedSendersAndDomains.txt"
    $blockedSenders | Out-File $blockedSendersOutputPath
    Write-Output "[INFO] Exported BlockedSendersAndDomains to: $blockedSendersOutputPath"
} else {
    Write-Output "[INFO] No blocked senders/domains found for $Mailbox"
}