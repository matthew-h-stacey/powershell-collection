param
(   
    [Parameter(Mandatory = $True)] [string] $UserPrincipalName, # The UserPrincipalName of the user being offboarded
    [Parameter(Mandatory = $False)] [string] $Delegate, # grant mailbox/calendar/contacts of $UserPrincipalName to this user
    [Parameter(Mandatory = $False)] [string] $ForwardTo # forward email sent to $UserPrincipalName to this user
)

$UserPrincipalName = "ssue@bcservice.tech" # User to offboard

# https://www.thecodeasylum.com/office-365-offboarding-users-with-powershell/
# https://www.cyberdrain.com/automating-with-powershell-quickly-offboarding-a-m365-user/


# ~~~ Code below ~~~ #

$workDir = "C:\TempPath"
$logFile = "$workDir\$($UserPrincipalName)_User_Offboard_Report_$((Get-Date -Format "MM-dd-yyyy_HHmm")).log" 
$spoURL = "https://"+($UserPrincipalName.Split("@")[1]).Split(".")[0]+"-admin.sharepoint.com"

# Connect to required modules
Write-Host "Connecting to AzureAD, check for a pop-up authentication window"
Connect-AzureAD | Out-Null

$sitecheck = $null
while ($null -eq $sitecheck) {
    try { 
        $sitecheck = Get-SPOSite $spoURL
    }
    catch {
    Write-Host "Connecting to SharePointOnline, check for a pop-up authentication window"
        try {
        Connect-SPOService -Url $spoURL -ErrorAction Stop
        }  
        catch {
            Write-Warning "Unable to connect to SharePointOnline, please manually enter the admin URL (ex: https://contoso-admin.sharepoint.com) and try again"
            Write-Host "NOTE: If this continues to fail, verify you have permissions to connect to SharePointOnline before proceeding"
            $spoURL = Read-Host "SPO admin URL"
            Connect-SPOService -Url $spoURL -ErrorAction Stop
        }
    }
}


Write-Host "Connecting to ExchangeOnline, check for a pop-up authentication window"
Connect-ExchangeOnline -ShowBanner:$False


# Standard variables - do not touch
$AADUser = Get-AzureADUser -ObjectId $UserPrincipalName
$Manager = get-AzureADUsermanager -ObjectId $UserPrincipalName
$Mailbox = Get-Mailbox -Identity $UserPrincipalName




Function Write-Log{
    Param ([string]$logstring)
    Add-Content $logFile -Value "$(Get-Date -Format "MM/dd/yyyy HH:mm") $logstring"
    }
# 

# [Reset user password] - Done
. "C:\Users\mstacey\OneDrive - bcservicenet\Documents\Scripts\AAD\Reset-AADUserPassword.ps1" -UserPrincipalName $UserPrincipalName -Random

# [Hide from GAL] - Done
Write-Host "[EXO] Hiding mailbox from GAL"
Set-Mailbox -Identity $UserPrincipalName -HiddenFromAddressListsEnabled:$True

# [Remove from all groups (AAD)] - Done
$AADReport = @()
$AADGroups = (Get-AzureADUserMembership -ObjectId $AADUser.objectID -All:$True) | Where-Object {$_.MailEnabled -eq $False}
Write-Host "[AAD] Removing $($UserPrincipalName) from all AzureAD groups"
foreach($g in $AADGroups){

    # First notate the DisplayName of each group the user is a member of and store in $results
    $AADGroupExport = [PSCustomObject]@{
        AADGroup = $g.DisplayName
    }
    $AADReport += $AADGroupExport

    # Remove the user from the group
    try{
        Remove-AzureADGroupMember -ObjectId $g.objectID -MemberId $AADUser.ObjectId
    }
    catch{
        Write-Warning "[AAD] Group skipped, check log"
        Write-Log "[AAD] Skipped Group: $($g.DisplayName), group is likely a Dynamic Group"
    }
}

# [Remove from all groups (EXO)]  - Done
$distis = Get-DistributionGroup -Filter "Members -eq '$($Mailbox.DistinguishedName)'"

$distiReport = @()
foreach ($d in $distis) {
    $distiExport = [PSCustomObject]@{
        DistributionGroup = $d.PrimarySmtpAddress
    }
    $distiReport += $distiExport

    Write-Host "[EXO] Removing $($UserPrincipalName) from $($d.PrimarySmtpAddress)"
    Remove-DistributionGroupMember -Identity $d.PrimarySmtpAddress -member $UserPrincipalName -Confirm:$false
}

# [Re-assign 365 group ownership to user's manager] Done? To be tested
# Objective: Find all groups that a user is a member of. If they are the only owner, change the owner to be their manager
# If there are already other users present, just remove the user from the owners list

$o365groupOwnerReport = @()
Write-Host "[365] Retrieving all Groups and their owner(s). This may take some time ..."
$allO365Groups = Get-UnifiedGroup -ResultSize Unlimited | sort PrimarySmtpAddress
 
foreach($group in $allO365Groups){
    $owners = Get-UnifiedGroupLinks -Identity $group.Name -LinkType Owners | select -ExpandProperty PrimarySmtpAddress
    if ($owners -like $UserPrincipalName){ # find ONLY Groups that the user is an Owner of
        if ($owners.Count -eq 1){ # add manager, remove offboarded user
            Write-Host "[365] $($group.DisplayName) is ONLY owned by the user. Changing ownership to $($Manager.UserPrincipalName)"
            Add-UnifiedGroupLinks -Identity $group.Alias -LinkType Member -Links $Manager.UserPrincipalName
            Add-UnifiedGroupLinks -Identity $group.Alias -LinkType Owner -Links $Manager.UserPrincipalName
            Remove-UnifiedGroupLinks -Identity $group.Alias -LinkType Owners -Links $UserPrincipalName -Confirm:$false
        } 
        if ($owners.Count -gt 1){ # there are already other owners, just remove the user
            Write-Host "[365] There are other owners present on $($group.DisplayName). Removing user from owners list"
            Remove-UnifiedGroupLinks -Identity $group.Alias -LinkType Owners -Links $UserPrincipalName -Confirm:$false            
        }
        # Add a list of the groups that the user was an Owner of to an object for export/review
        $o365groupOwnerExport = [PSCustomObject]@{
            O365Group = $group.DisplayName
            Owner   =   $UserPrincipalName
        } 
        $o365groupOwnerReport += $o365groupOwnerExport
    }
}

# [Remove from all UnifiedGroups (365 Groups and Teams)]

$o365groupMembershipReport = @()
foreach ($grp in $allO365Groups){
    $groupMembers = Get-UnifiedGroup -Identity $grp.Name | Get-UnifiedGroupLinks -LinkType Member | select -expand PrimarySmtpAddress
    foreach($m in $groupMembers){
        if ($m -like $UserPrincipalName){ # find ONLY Groups that the user is a member of
            $o365groupMemberExport = [PSCustomObject]@{
                O365Group = $grp.DisplayName
                MemberName  = $UserPrincipalName
            }
            $o365groupMembershipReport += $o365groupMemberExport 
            Write-Host "[EXO] Removing $($UserPrincipalName) from UnifiedGroup $($grp.DisplayName)"
            Remove-UnifiedGroupLinks -Identity $grp.Alias -LinkType Member -Links $UserPrincipalName -Confirm:$false
        }
    }
}
if( $o365groupMembershipReport.Length -eq 0){ Write-Host "[EXO] $($UserPrincipalName) is not a member of any groups"}

# [Grant OneDrive file access to manager] - Done
# Attempt to build the spoAdminURL based off of the UPN of the user. If this fails a URL will need to be provided manually

$spoSiteUrl  = Get-SPOSite -Filter { Url -like "/personal/" } -IncludePersonalSite $true | ?{$_.Owner -like $UserPrincipalName} | select -ExpandProperty Url
Write-Host "[SPO] Granting $($Manager.UserPrincipalName) access to $($UserPrincipalName) OneDrive Personal site"
. "C:\Users\mstacey\OneDrive - bcservicenet\Documents\Scripts\SPO\Add-SPOSiteOwner.ps1" -spoURL $spoURL -spoSiteUrl $spoSiteUrl -trusteeUser $Manager.UserPrincipalName | Out-Null

# [Optional: Grant delegate access to mailbox/calendar/contacts ] - Done? To be tested
if ($Delegate.IsPresent) {
    Write-Host "[EXO] Granting $($Delegate) access to $($UserPrincipalName) mailbox, contacts, and calendar"
    . "C:\Users\mstacey\OneDrive - bcservicenet\Documents\Scripts\EXO\Add-MailboxContactCalendarPermissions.ps1" -UserPrincipalName $UserPrincipalName -Trustee $Delegate
}

# [Convert to Shared mailbox] - Done
Write-Host "[EXO] Setting mailbox of $($UserPrincipalName) to a SharedMailbox"
Set-Mailbox -Identity $UserPrincipalName -Type Shared

# [Remove license] - Done
Write-Host "[MSONLINE] Removing all licenses from $($UserPrincipalName)"
. "C:\Users\mstacey\OneDrive - bcservicenet\Documents\Scripts\AAD\Remove-UserLicenses.ps1" -UserPrincipalName $UserPrincipalName


# [Remove any/all MFA authentication methods] - Not started
# https://docs.microsoft.com/en-us/azure/active-directory/authentication/howto-mfa-userdevicesettings
Write-Host "[MSONLINE] Resetting MFA for $($UserPrincipalName)"
Reset-MsolStrongAuthenticationMethodByUpn -UserPrincipalName $UserPrincipalName

# [Email forwarding] - Done? To be tested
if ($ForwardTo.IsPresent) {
    Write-Host "[EXO] Setting mailbox forwarding to $($ForwardTo)"
    Set-Mailbox -Identity $UserPrincipalName -ForwardingAddress $ForwardTo
}

# [Remove user properties: Department, Manager, Phone number ]
# note: Set-AzureADUser does NOT allow for setting $null
# multiple lines seemd to make this more consistent
Write-Host "[MSONLINE] Clearing properties from user: AlternateEmailAddresses, MobilePhone, PhoneNumber, Department, Manager"
Set-MsolUser -UserPrincipalName $UserPrincipalName -AlternateEmailAddresses $null
Set-MsolUser -UserPrincipalName $UserPrincipalName -MobilePhone "$null"
Set-MsolUser -UserPrincipalName $UserPrincipalName -PhoneNumber "$null"
Set-MsolUser -UserPrincipalName $UserPrincipalName -Department "$null"
Remove-AzureADUserManager -ObjectId $AADUser.ObjectId

# Export data
Write-Host "Exporting reports to $($workDir)"
$AADReport | export-csv -Path "$workDir\$($UserPrincipalName)_Offboard_AADGroups.csv" -NoTypeInformation
$distiReport | export-csv -Path "$workDir\$($UserPrincipalName)_Offboard_DistiMembership.csv" -NoTypeInformation
$o365groupOwnerReport  | export-csv -Path "$workDir\$($UserPrincipalName)_Offboard_O365OwnedGroups.csv" -NoTypeInformation
$o365groupMembershipReport | export-csv -Path "$workDir\$($UserPrincipalName)_Offboard_O365GroupMembership.csv" -NoTypeInformation





