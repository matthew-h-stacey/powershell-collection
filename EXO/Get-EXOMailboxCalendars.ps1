param(
    [Parameter(Mandatory = $True)]
    [string]
    $Mailbox
)

Get-MailboxFolderStatistics $Mailbox | Where-Object { $_.FolderPath -like "/Calendar*" -and $_.FolderPath -notlike "/Calendar Logging" } | Select-Object Name, Identity, FolderPath