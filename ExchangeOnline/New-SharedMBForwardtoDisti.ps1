# Ref: 
# https://docs.microsoft.com/en-us/powershell/module/exchange/new-distributiongroup?view=exchange-ps
# https://docs.microsoft.com/en-us/powershell/module/exchange/new-mailbox?view=exchange-ps

# Hidden distribution group
$distiName = "ITGroupDisti"
$distiSmtpAddress = "ITgroupdisti@Uphams.org"
$manager = "Samir Hraybi" # manager or owner of group
$internalOnly = $false # whether or not this address should be reachable internally only (true) or not (false)
$members = Get-Content C:\TempPath\GroupUsers.txt # txt file with a list of user's DisplayName

# Shared mailbox parameters that will handle the auto-reply and auto-forward
$sharedMbName = "ITGroup"
$sharedMbSmtpAddress = "ITgroup@Uphams.org"
$autoReply = "Please note the 'ITgroup@Uphams.org' distribution list will be no longer in use by end of November 2021, if you need helpdesk support, please open a ticket using our ticketing system , link is available on your desktop and from Upham’s Intranet also, You can continue sending emails to IT department using  IT@Uphams.org. Thank you, IT Department"

# Connect to EXO
Connect-ExchangeOnline

# Create the new distribution group and hide it
New-DistributionGroup -Name $distiName -DisplayName $distiName -ManagedBy $manager -RequireSenderAuthenticationEnabled $internalOnly -Type Distribution -PrimarySmtpAddress $distiSmtpAddress -Confirm:$False 
Set-DistributionGroup -Identity $distiName HiddenFromAddressListsEnabled $true

# Create new shared mailbox with auto-reply and forward
New-Mailbox -Name $sharedMbName -DisplayName $sharedMbName -Shared -PrimarySmtpAddress $sharedMbNameSmtpAddress -Confirm:$False 
Set-Mailbox -Identity $sharedMbName  -DeliverToMailboxAndForward $true -ForwardingSMTPAddress $distiSmtpAddress # optionally, to hide the mailbox, too add: -HiddenFromAddressListsEnabled:$True
Set-MailboxAutoReplyConfiguration -Identity $sharedMbName -AutoReplyState Enabled -InternalMessage $autoReply -ExternalMessage $autoReply

# OPTIONAL: Test the auto-reply by emailing the mailbox before proceeding
# Also check message logs to verify that the email was 'expanded' though there are no members of the group yet

# Finally, add the members back to the group
foreach($m in $members){
    # $upn = (Get-Mailbox -Identity $m).UserPrincipalName
    Add-DistributionGroupMember -Identity $name -Member (Get-Mailbox -Identity $m).UserPrincipalName
}

# OPTIONAL:
# Check memberships
# Get-DistributionGroupMember $distiName




