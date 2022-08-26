Param
(   
    [Parameter(Mandatory = $true)] [string] $Mailbox
)

$Calendar = $Mailbox + ":\Calendar" # Establish calendar path (ex: "John Smith:\Calendar" or "jsmith@contoso.com:\Calendar")
Get-MailboxFolderPermission -Identity $Calendar | select User,AccessRights # Retrieve user permissions for the specified calendar