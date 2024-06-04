# Possibly obsolete, experimental at the moment
$src = "mailbox1@contoso.com"
$dst = "mailbox2@contoso.com"
$searchName = "Copy $($src) to $($dst)"

New-MailboxSearch -Name $searchName -SourceMailboxes $src -TargetMailbox $dst -LogLevel Full
Get-MailboxSearch $searchName | Start-MailboxSearch

# Check status
Get-MailboxSearch $searchName | FT name, status, sourcemailboxes, targetMailbox, PercentComplete, ResultNumber, ResultSize -AutoSize