param(
    [Parameter(Mandatory = $True)]
    [string]
    $Mailbox,

    [Parameter(Mandatory = $False)]
    [switch]
    $Archive
)

if ($Archive){
    Get-MailboxFolderstatistics -Identity $Mailbox -Archive | Where-Object { $_.FolderPath -like "*inbox*" } | Sort-Object FolderPath | Select-Object FolderPath
} else {
    Get-MailboxFolderstatistics -Identity $Mailbox | Where-Object { $_.FolderPath -like "*inbox*" } | Sort-Object FolderPath | Select-Object FolderPath
}