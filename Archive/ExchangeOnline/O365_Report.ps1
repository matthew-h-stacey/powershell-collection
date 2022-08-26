# Establish variables
$directory = "C:\TempPath"

# 0) Gather initial information to be used in the script
$AllMailboxes = Get-Mailbox -ResultSize Unlimited
$AllDistributionGroups = Get-DistributionGroup -ResultSize Unlimited 
$AllMailContacts = Get-MailContact -ResultSize Unlimited 
$AllPublicFolders = Get-PublicFolder -ResultSize Unlimited -Recurse
$AllMailPublicFolders = Get-MailPublicFolder -ResultSize Unlimited

# 1) Get distribution groups
$results = @()
foreach ($group in $AllDistributionGroups) {
    $distiObject = [PSCustomObject]@{
        DisplayName                          = $group.DisplayName
        PrimarySmtpAddress                   = $group.PrimarySmtpAddress
        EmailAddresses                       = $group.EmailAddresses
        HiddenFromAddressListsEnabled        = $group.HiddenFromAddressListsEnabled
        ManagedBy                            = $group.ManagedBy
        MemberJoinRestriction                = $group.MemberJoinRestriction
        MemberDepartRestriction              = $group.MemberDepartRestriction
        GrantSendOnBehalfTo                  = $group.GrantSendOnBehalfTo
        ModerationEnabled                    = $group.ModerationEnabled
        RequireSenderAuthenticationEnabled   = $group.RequireSenderAuthenticationEnabled
    }
    $results += $distiObject
}
$results | Export-Csv $directory\DistributionGroups.csv -NoTypeInformation

# 2) Get distribution group members
$GroupMembers = foreach($member in $AllDistributionGroups){
                       $memberID = $member.Identity
                        Get-DistributionGroupMember $memberID | Select-Object @{n='DistributionGroup';e={$member.DisplayName}},DisplayName,PrimarySmtpAddress
                        }
                        $GroupMembers | Export-CSV $directory\DistributionGroupsMembers.csv -Notypeinformation

# 3) Get distribution groups recipient permissions
$AllDistributionGroups | Get-RecipientPermission | Select-Object Identity, Trustee, AccessRights | Export-CSV $directory\DistributionGroupsPermissions.csv -Notypeinformation

# 4) Get MailPublicFolders
$results = @()
foreach ($folder in $AllMailPublicFolders) {
    try{
    $folderObject = [PSCustomObject]@{
        DisplayName                            = $folder.DisplayName
        Alias                                  = $folder.Alias
        PrimarySmtpAddress                     = $folder.PrimarySmtpAddress
        EmailAddresses                         = $folder.EmailAddresses
        RequireSenderAuthenticationEnabled     = $folder.RequireSenderAuthenticationEnabled
        HiddenFromAddressListsEnabled          = $folder.HiddenFromAddressListsEnabled
        ContentMailbox                         = $folder.ContentMailbox
        DeliverToMailboxAndForward             = $folder.DeliverToMailboxAndForward
        ExternalEmailAddress                   = $folder.ExternalEmailAddress
        ForwardingAddress                      = $folder.ForwardingAddress
        AcceptMessagesOnlyFrom                 = $folder.AcceptMessagesOnlyFrom
        AcceptMessagesOnlyFromDLMembers        = $folder.AcceptMessagesOnlyFromDLMembers
        AcceptMessagesOnlyFromSendersOrMembers = $folder.AcceptMessagesOnlyFromSendersOrMembers
        GrantSendOnBehalfTo                    = $folder.GrantSendOnBehalfTo
    }
        $results += $folderObject
}
catch { "An error occurred"}
}
$results | Export-Csv $directory\MailPublicFolders.csv -NoTypeInformation

# 5) Get MailPublicFolder send-as permissions
$AllPublicFolders | Where-Object { ($_.MailEnabled -eq $True) } | Get-PublicFolderClientPermission | Select-Object FolderName, User, AccessRights | Export-Csv $directory\PublicFolderSendAsPermissions.csv -NoTypeInformation

# 6) Get mailboxes
$results = @()
foreach ($mailbox in $AllMailboxes) {
    $mailboxObject = [PSCustomObject]@{
        DisplayName                           = $mailbox.DisplayName
        Alias                                 = $mailbox.Alias
        PrimarySmtpAddress                    = $mailbox.PrimarySmtpAddress
        EmailAddresses                        = $mailbox.EmailAddresses
        ForwardingAddress                     = $mailbox.ForwardingAddress
        ForwardingSmtpAddress                 = $mailbox.ForwardingSmtpAddress
        GrantSendOnBehalfTo                   = $mailbox.GrantSendOnBehalfTo
        RequireSenderAuthenticationEnabled    = $mailbox.RequireSenderAuthenticationEnabled
        HiddenFromAddressListsEnabled         = $mailbox.HiddenFromAddressListsEnabled
        WhenMailboxCreated                    = $mailbox.WhenMailboxCreated
    }
    $results += $mailboxObject
}
$results | Export-Csv $directory\Mailboxes.csv -NoTypeInformation

# 7) Get all FullAccess mailbox permissions
$AllMailboxes | Get-MailboxPermission | Where-Object{ ($_.AccessRights -eq "FullAccess") -and ($_.IsInherited -eq $false) -and ($_.IsValid -eq $true)} | Select-Object User,Identity,@{n='AccessRights';expression={$_.AccessRights}},IsInherited | Export-CSV $directory\MailboxesFullAccessPermissions.csv -NoTypeInformation

# 8) Get all mail contacts
$AllMailContacts | Select-Object Alias,PrimarySmtpAddress,ExternalEmailAddress,@{n='EmailAddresses';expression={$_.EmailAddresses}},HiddenFromAddressListsEnabled | Export-CSV $directory\MailContacts.csv -NoTypeInformation