Param(
    [Parameter(Mandatory = $True)]
    [string]$Mailbox
)
# Optional: The built-in "Calendar Logging" folder is hidden, remove the notLike entry for it in the filter if required
Get-MailboxFolderStatistics $Mailbox | Where-Object { $_.FolderPath -like "/Calendar*" -and $_.FolderPath -notlike "/Calendar Logging" } | Select-Object Name, Identity, FolderPath