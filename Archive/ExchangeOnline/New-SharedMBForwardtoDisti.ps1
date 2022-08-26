# I believe that New-SharedMailboxForAutoReply.ps1 supersedes this entirely, that or I don't recall the original intention of this script - whoops!

# Ref: 
# https://docs.microsoft.com/en-us/powershell/module/exchange/new-distributiongroup?view=exchange-ps
# https://docs.microsoft.com/en-us/powershell/module/exchange/new-mailbox?view=exchange-ps

param (
    [Parameter(Mandatory=$true)][string]$DistiGroupName,
    [Parameter(Mandatory = $true)][string]$DistiPrimarySmtpAddress,
    [Parameter(Mandatory = $true)][string]$Manager,
    [Parameter(Mandatory = $true)][boolean]$InternalOnly,
    [Parameter(Mandatory = $true)][string]$SharedMailboxName,
    [Parameter(Mandatory = $true)][string]$SharedMailboxPrimarySmtpAddress
)

# Used to convert a standard DL to a shared mailbox 
# Creates a hidden distribution group with the specified name and PrimarySmtpAddress, owned by whoever requested the setup
# Create new shared mailbox with the auto-reply and forward to the distribution group

# Shared mailbox parameters that will handle the auto-reply and auto-forward


$members = Get-Content C:\TempPath\GroupUsers.txt # txt file with a list of user's DisplayName
$autoReply = "Please note that the 'it@contoso.com' distribution list will be no longer in use by end of November 2021, if you need helpdesk support, please open a ticket using our ticketing system."


# Connect to EXO
Connect-ExchangeOnline

# Create the new distribution group and hide it
New-DistributionGroup -Name $distiGroupName -DisplayName $distiGroupName -ManagedBy $Manager -RequireSenderAuthenticationEnabled $InternalOnly -Type Distribution -PrimarySmtpAddress $distiPrimarySmtpAddress -Confirm:$False 
Set-DistributionGroup -Identity $distiGroupName HiddenFromAddressListsEnabled $true

# Create new shared mailbox with auto-reply and forward
New-Mailbox -Name $sharedMailboxName -DisplayName $sharedMailboxName -Shared -PrimarySmtpAddress $sharedMailboxNameSmtpAddress -Confirm:$False 
Set-Mailbox -Identity $sharedMailboxName  -DeliverToMailboxAndForward $true -ForwardingSMTPAddress $distiPrimarySmtpAddress # optionally, to hide the mailbox, too add: -HiddenFromAddressListsEnabled:$True
Set-MailboxAutoReplyConfiguration -Identity $sharedMailboxName -AutoReplyState Enabled -InternalMessage $autoReply -ExternalMessage $autoReply

# OPTIONAL: Test the auto-reply by emailing the mailbox before proceeding
# Also check message logs to verify that the email was 'expanded' though there are no members of the group yet

# Finally, add the members back to the group
foreach($m in $members){
    # $upn = (Get-Mailbox -Identity $m).UserPrincipalName
    Add-DistributionGroupMember -Identity $name -Member (Get-Mailbox -Identity $m).UserPrincipalName
}

# OPTIONAL:
# Check memberships
# Get-DistributionGroupMember $distiGroupName




