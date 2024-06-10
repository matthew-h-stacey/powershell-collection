param(   
    # Mailbox that contains the calendar to query
    [Parameter(Mandatory = $true)]
    [String]
    $Mailbox,

    # Optional: Specify calendar name other than the default "Calendar"
    [Parameter(Mandatory=$false)]
    [String]
    $CalendarName
)

if ( $CalendarName ) {
    $calendar = "${Mailbox}:\$CalendarName"
} else {
    $calendar = "${Mailbox}:\Calendar"
}

Get-MailboxFolderPermission -Identity $calendar | Select-Object User,AccessRights