param
(   
    [Parameter(Mandatory = $True)] [string] $TenantID, # The ID of the Azure tenant
    [Parameter(Mandatory = $True)] [string] $ClientID, # The Client/Application ID of the Azure App Registration
    [Parameter(Mandatory = $True)] [string] $UserPrincipalName, # The UserPrincipalName of the user being offboarded
    [Parameter(Mandatory = $False)] [string] $Delegate, # grant mailbox of $UserPrincipalName to this user
    [Parameter(Mandatory = $False)] [boolean] $AutoMapping, # map the inbox of $UserPrincipalName to the delegate's Outlook profile via AutoDiscover
    [Parameter(Mandatory = $False)] [boolean] $Calendar, # grant calendar of $UserPrincipalName to this user
    [Parameter(Mandatory = $False)] [boolean] $Contacts, # grant contacts of $UserPrincipalName to this user
    [Parameter(Mandatory = $False)] [string] $ForwardTo, # forward email sent to $UserPrincipalName to this user
    [Parameter(Mandatory = $False)] [string] $OneDriveTrustee, # if present, grant access to $UserPrincipalName's OneDrive files access to this user
    [Parameter(Mandatory = $False)] [boolean] $RemoveLicenses # if yes, remove licenses from $UserPrincipalName
)

function New-Folder {
    Param([Parameter(Mandatory = $True)][String] $folderPath)
    if (-not (Test-Path -LiteralPath $folderPath)) {
        try {
            New-Item -Path $folderPath -ItemType Directory -ErrorAction Stop | Out-Null
            Write-Host "Created folder: $folderPath"
        }
        catch {
            Write-Error -Message "Unable to create directory '$folderPath'. Error was: $_" -ErrorAction Stop
        }
    }
    else {
        "$folderPath already exists, continuing ..."
    }

}

function Write-Log {
    Param ([string]$logstring)
    Add-Content $logFile -Value "$(Get-Date -Format "MM/dd/yyyy HH:mm") $logstring"
}

function Install-RequiredModules {

    # Install ExchangeOnlineManagement if it is not already installed
    if ($null -eq (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
        Write-Host "[MODULE] Required module ExchangeOnlineManagement is not installed"
        Write-Host "[MODULE] Installing ExchangeOnlineManagement" -ForegroundColor Cyan
        Install-Module ExchangeOnlineManagement -Repository PSGallery -AllowClobber -Force -Scope CurrentUser
    } 
    else { 
        Write-Host "[MODULE] ExchangeOnlineManagement is installed, continuing ..." 
    }
    
    # Install Microsoft.Graph if it is not already installed
    if ($null -eq (Get-InstalledModule Microsoft.Graph)) {
        Write-Host "[MODULE] Required module Microsoft.Graph is not installed"
        Write-Host "[MODULE] Installing Microsoft.Graph" -ForegroundColor Cyan
        Install-Module Microsoft.Graph -Scope CurrentUser -Repository PSGallery -Force
    } 
    else { 
        Write-Host "[MODULE] Microsoft.Graph is installed, continuing ..." 
    }

}

function Connect-Modules {
    param (
        [Parameter(Mandatory=$True)][String]$TenantID,
        [Parameter(Mandatory=$True)][String]$ClientID,
        [Parameter(Mandatory=$True)][String]$certThumbprint
    )

    # Connect to MgGraph, if not already connected
    $isConnected = Get-MgContext
    while ( $null -eq $isConnected ) { # while loop to connect to MsGraph
        Write-Host "[MODULE] Connecting to MgGraph ..."
        Connect-MgGraph -TenantId $tenantID -ClientID $clientID -CertificateThumbprint $certThumbprint | Out-Null
        $isConnected = Get-MgContext
        if ( $null -ne $isConnected) { # if connected
            Write-Output "[MODULE] Connected to MgGraph"
        }
    }

    # Check if already connected to ExchangeOnline, connect if not connected
    $isConnected = Get-PSSession | Where-Object { $_.Name -like "ExchangeOnlineInternalSession*" -and $_.Availability -like "Available" }
    while ( $null -eq $isConnected ) { # while loop to connect to EXO
        Write-Host "[MODULE] Connecting to ExchangeOnline ..."
        Connect-ExchangeOnline -CertificateThumbprint $certThumbprint -AppId $clientID -Organization $domain -ShowBanner:$false
        $isConnected = Get-PSSession | Where-Object { $_.Name -like "ExchangeOnlineInternalSession*" -and $_.Availability -like "Available" }
        if ( $null -ne $isConnected ) {
            Write-Output "[MODULE] Connected to ExchangeOnline"
        }
    }   
    
}

function Disconnect-Modules {

    Disconnect-MgGraph
    Disconnect-ExchangeOnline -Confirm:$false -InformationAction Ignore -ErrorAction SilentlyContinue
    Get-PSSession | Remove-PSSession

}

function Remove-AzureADGroupMembership {

    <#
    This function will remove a user from any AzureAD groups (not MailEnabled Office 365 groups) they are a member of
    #>

    $AADGroupMembershipReport = @() # Array used for the total output of group removal
    $MgUserGroups = Get-MgUserMemberOf -UserId $MgUser.Id # all groups 

    foreach ($g in $MgUserGroups) {
        $groupDisplayName = ($g | Select-Object -ExpandProperty AdditionalProperties).Item('displayName')
        $isMailEnabled = ($g | Select-Object -ExpandProperty AdditionalProperties).Item('mailEnabled')

        if ( $isMailEnabled ) { 
            # This loop is only going to remove AzureAD groups, so take no action if the group is MailEnabled
        }
        else {
            # Group is not MailEnabled, proceed
            if (( Get-MgGroup -GroupId $g.Id).GroupTypes -like "DynamicMembership" ) {
                # if Dynamic, do nothing
            }
            else { 
                # Groups that match this 
                # https://docs.microsoft.com/en-us/graph/api/group-delete-members?view=graph-rest-beta&tabs=http
                # https://rakhesh.com/azure/graph-powershell-remove-member-from-group/
                $AADGroupMembershipReport += $groupDisplayName # Add the group DisplayName to the array for output
                Write-Log "[AAD] Removing $($MgUser.UserPrincipalName) from AzureAD group: $($groupDisplayName)"
                $ref = '$ref'
                try {
                    Invoke-MgGraphRequest -Method Delete -Uri "https://graph.microsoft.com/v1.0/groups/$($g.Id)/members/$($MgUser.Id)/$ref"
                }
                catch {
                    Write-Log "[AAD] An error occurred attempting to remove $($MgUser.UserPrincipalName) from AzureAD group: $($groupDisplayName)"
                }
            }
        }
    }
    
    $AADGroupMembershipReport = $AADGroupMembershipReport | Sort-Object # sort alphbetically
    
    # Write to summary file
    "[AAD] Removed $($UserPrincipalName) from AzureAD group(s): " + ($AADGroupMembershipReport -join ', ') | Out-File $summaryFile -Append

    # Export report
    $AADGroupMembershipReport | Select-Object @{Name = 'AAD_Group'; Expression = { $_ } } | Export-CSV -Path "$workDir\$($UserPrincipalName)_Offboard_AADGroups.csv" -NoTypeInformation

}

function Hide-Mailbox {

    <#
    This function will hide the mailbox from the GAL
    #>

    if (((Get-Mailbox -Identity $UserPrincipalName).HiddenFromAddressListsEnabled) -eq $True) {
        Write-Log "[EXO] SKIPPED: Hide mailbox from GAL; Reason: Mailbox is already hidden"
        "[EXO] SKIPPED: Hide mailbox from GAL; Reason: Mailbox is already hidden" | Out-File $summaryFile -Append
    }
    else {
        Write-Log "[EXO] Hiding mailbox from GAL"
        Set-Mailbox -Identity $UserPrincipalName -HiddenFromAddressListsEnabled:$True
        "[EXO] Hid mailbox from GAL" | Out-File $summaryFile -Append
    }
}

function Remove-MobileDeviceData {

    <#
    This function will initiate a command to mobile devices to remove the email account from the device
    #>

    Write-Log "[EXO] Checking for any mobile devices to delete data from..."
    $userPhones = Get-MobileDevice -Mailbox $UserPrincipalName
    if ($null -eq $userPhones) {
        Write-Log "[EXO] SKIPPED: Email account wipe from mobile devices; Reason: No mobile devices found"
        "[EXO] SKIPPED: Email account wipe from mobile devices; Reason: No mobile devices found" | Out-File $summaryFile -Append
    }
    else {
        Write-Log "[EXO] Found mobile device(s). Removing the account from mobile device(s)"
        foreach ($p in $userPhones) {    
            Clear-MobileDevice -Identity $p.DistinguishedName -AccountOnly -Confirm:$false
            "[EXO] Initiated email account wipe from mobile devices" | Out-File $summaryFile -Append
        }
    }

}

function Remove-DistributionGroupMembership {

    <#
    This function will remove a user from all distribution groups they are members of
    #>

    $distiReport = @() # Array used for the total output of group removal
    $distis = Get-DistributionGroup -Filter "Members -eq '$(Get-Mailbox -Identity $UserPrincipalName | select -ExpandProperty DistinguishedName)'"
    foreach ($d in $distis) {
        $distiExport = [PSCustomObject]@{
            DistributionGroup = $d.PrimarySmtpAddress
        }
        $distiReport += $distiExport
        Write-Log "[EXO] Removing $($UserPrincipalName) from $($d.PrimarySmtpAddress)"
        Remove-DistributionGroupMember -Identity $d.PrimarySmtpAddress -member $UserPrincipalName -Confirm:$false
    }

    # Write to summary file
    "[EXO] Removed $($UserPrincipalName) from Distribution group(s): " + ($distiReport.DistributionGroup -join ', ') | Out-File $summaryFile -Append

    # Export report
    $distiReport | export-csv -Path "$workDir\$($UserPrincipalName)_Offboard_DistiMembership.csv" -NoTypeInformation

}

function Remove-O365GroupOwnership {

    <#
    Find all groups that a user is a member of. If they are the only owner, change the owner to be their manager
    If there are already other users (owners) present, just remove the user from the owners list
    #>

    $o365groupOwnerReport = @()  # Array used for the total output of group removal
 
    foreach ($group in $allO365Groups) {
        
        $owners = Get-MgGroupOwner -GroupId $group.Id
        if ($owners.id -like $MgUser.id) {
            # User is an Owner of this Group
            if ($owners.Count -eq 1) {
                # If User is the ONLY Owner of the Group
                Write-Log "[EXO] $($group.DisplayName) is ONLY owned by $($UserPrincipalName). Changing ownership to $($MgUserManager.UserPrincipalName)"
                
                $ManagerOData = @{
                    "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$($MgUserManager.Id)"
                }

                New-MgGroupMemberByRef -GroupId $group.Id -BodyParameter $ManagerOData # add Manager as a Member of the Group
                New-MgGroupOwnerByRef -GroupId $group.Id -BodyParameter $ManagerOData # add Manager as an Owner of the Group
                Remove-MgGroupOwnerByRef -GroupId $group.Id -DirectoryObjectId $MgUser.Id # remove User's ownership of group
            }
            if ($owners.Count -gt 1) {
                # If there are other Owners, just remove User's ownership of Group
                Write-Log "[EXO] There are other owners present on $($group.DisplayName). Removing user from owners list"
                Remove-MgGroupOwnerByRef -GroupId $group.Id -DirectoryObjectId $MgUser.Id
            }

            # Add a list of the groups that the user was an Owner of to an object for export/review
            $o365groupOwnerExport = [PSCustomObject]@{
                O365Group = $group.DisplayName
            } 
            $o365groupOwnerReport += $o365groupOwnerExport

        }
    }
        
    if ( $o365groupOwnerReport.Length -eq 0) { 
        Write-Log "[EXO] $($UserPrincipalName) is not an owner of any groups"
    }
        
    # Write to summary file
    "[EXO] Removed $($UserPrincipalName) Ownership from 365 Group(s): " + ($o365groupOwnerReport.O365Group -join ', ') | Out-File $summaryFile -Append

    # Export report
    $o365groupOwnerReport  | export-csv -Path "$workDir\$($UserPrincipalName)_Offboard_O365OwnedGroups.csv" -NoTypeInformation

}

function Remove-O365GroupMembership {

    <#
    Remove from all UnifiedGroups (365 Groups and Teams)
    #>
    
    $o365groupMembershipReport = @()  # Array used for the total output of group removal

    foreach ($grp in $allO365Groups) {
        $groupMembers = Get-UnifiedGroup -Identity $grp.Name | Get-UnifiedGroupLinks -LinkType Member | Select-Object -expand PrimarySmtpAddress
        foreach ($m in $groupMembers) {
            if ($m -like $UserPrincipalName) {
                # find ONLY Groups that the user is a member of
                $o365groupMemberExport = [PSCustomObject]@{
                    O365Group = $grp.DisplayName
                }
                $o365groupMembershipReport += $o365groupMemberExport 
                Write-Log "[EXO] Removing $($UserPrincipalName) from UnifiedGroup $($grp.DisplayName)"
                Remove-UnifiedGroupLinks -Identity $grp.Alias -LinkType Member -Links $UserPrincipalName -Confirm:$false
            }
        }
    }
    if ( $o365groupMembershipReport.Length -eq 0) { 
        Write-Log "[EXO] $($UserPrincipalName) is not a member of any groups"
    }

    # Write to summary file
    "[EXO] Removed $($UserPrincipalName) membership from 365 Group(s): " + ($o365groupMembershipReport.O365Group -join ', ') | Out-File $summaryFile -Append

    # Export report
    $o365groupMembershipReport | export-csv -Path "$workDir\$($UserPrincipalName)_Offboard_O365GroupMembership.csv" -NoTypeInformation


}

function Convert-ToSharedMailbox { 

    <#
    This function converts the UserMailbox to a SharedMailbox
    #>

    if ((get-mailbox -Identity $UserPrincipalName).RecipientTypeDetails -eq "SharedMailbox") {
        Write-Log "[EXO] Mailbox $($UserPrincipalName) is already a SharedMailbox, skipping..."
        "[EXO] SKIPPED: Convert mailbox to a SharedMailbox; Reason: Mailbox is already a SharedMailbox" | Out-File $summaryFile -Append
    }
    else {
        Write-Log "[EXO] Setting mailbox of $($UserPrincipalName) to a SharedMailbox"
        Set-Mailbox -Identity $UserPrincipalName -Type Shared
        "[EXO] Converted mailbox of $($UserPrincipalName) to a SharedMailbox" | Out-File $summaryFile -Append
    }

}

function Add-DelegatePermissions {

    <#
    This function will grant optional delegate permissions, depending on variable input
    #>

    if ( $Delegate) {
        $delegateParams = @{
            UserPrincipalName = $UserPrincipalName
            Trustee           = $Delegate   
            Calendar          = $Calendar
            Contacts          = $Contacts
            AutoMapping       = $AutoMapping
        }
        $delegateOutput = .\Add-MailboxContactCalendarPermissions.ps1 @delegateParams
        Write-Log $delegateOutput
        "[EXO] Granted delegate $($Delegate) access to $($UserPrincipalName) inbox" | Out-File $summaryFile -Append
    }

    if ($Calendar) {
        "[EXO] Granted delegate $($Delegate) access to $($UserPrincipalName) Calendar" | Out-File $summaryFile -Append
    }
    if ($Contacts) { 
        "[EXO] Granted delegate $($Delegate) access to $($UserPrincipalName) Contacts" | Out-File $summaryFile -Append
    }
}

function Set-MailboxForwarding {

    <#
    This function sets mailbox forwarding, depending on variable input
    #>
    
    if ($ForwardTo) {
        Write-Log "[EXO] Setting mailbox forwarding to $($ForwardTo)"
        Set-Mailbox -Identity $UserPrincipalName -ForwardingAddress $ForwardTo -DeliverToMailboxAndForward:$True
        "[EXO] Forwarded email from $($UserPrincipalName) to $($ForwardTo)" | Out-File $summaryFile -Append
    }

}

function Remove-UserLicenses {

    <#
    This function will remove all licenses from a user account
    #>

    Write-Output "[GRAPH] Processing licenses for user $($UserPrincipalName)..."
    $filter = "startsWith(UserPrincipalName,'" + $UserPrincipalName + "')"
    $user = Get-MgUser -Filter $filter -ErrorAction Stop 
    if ( $null -eq $user) {
        Write-Output "ERROR: Unable to find user"
        break # Stop if the user cannot be found
    }

    $SKUs = (Get-MgUserLicenseDetail -UserId $user.Id).SkuPartNumber
    $priorLicenses = @() # store all current licenses in a variable
    foreach ($SKU in $SKUs) { 
        $priorLicenses += $SKU # populate $priorLicenses
        Write-Output "[GRAPH] Removing license $($SKU) from user $($user.UserPrincipalName)"
        $skuId = (Get-MgSubscribedSku -All | Where SkuPartNumber -eq $SKU).SkuId
        Set-MgUserLicense -UserId $user.Id -AddLicenses @() -RemoveLicenses @($skuId) | Out-Null
    }

    if ( $priorLicenses.Length -eq 0) { 
        Write-Log "[365] $($UserPrincipalName) does not have any licenses applied to their account"
    }

    # Write to summary file
    "[365] Removed the following license(s) from $($UserPrincipalName): " + ($priorLicenses -join ', ') | Out-File $summaryFile -Append

    # Export report
    $priorLicenses | export-csv -Path "$workDir\$($UserPrincipalName)_Offboard_Licenses.csv" -NoTypeInformation

}

# Standard variables
$domain = $UserPrincipalName.Split("@")[1]
$certName = [System.Environment]::UserName + "-" + [system.environment]::MachineName
$certThumbprint = Get-ChildItem Cert:\CurrentUser\My\ | Where-Object { $_.Subject -like "*$certName*" } | Select-Object -ExpandProperty Thumbprint
$workDir = "C:\TempPath\$($UserPrincipalName)"
$logFile = "$workDir\$($UserPrincipalName)_User_Offboard_Report_$((Get-Date -Format "MM-dd-yyyy_HHmm")).log" 
$transcript = "$workDir\$($UserPrincipalName)_User_Offboard_Transcript.txt" 
$summaryFile = "$workDir\$($UserPrincipalName)_User_Offboard_Summary.txt" 
$spoURL = "https://" + ($UserPrincipalName.Split("@")[1]).Split(".")[0] + "-admin.sharepoint.com" # Attempt to build spoAdminURL off of the UPN


Start-Transcript -Path $transcript
New-Folder -folderPath $workDir
Install-RequiredModules
Connect-Modules -TenantID $tenantID -ClientID $clientID -certThumbprint $certThumbprint

# Retrieve objects for manipulation later
$filter = "startsWith(UserPrincipalName,'" + $UserPrincipalName + "')"
$MgUser = Get-MgUser -Filter $filter -ErrorAction Stop 
if ( $null -eq $MgUser) {
    Write-Output "ERROR: Unable to find user"
    exit # Stop if the user cannot be found
}
$MgUserManagerDisplayName = (Get-MgUserManager -UserId $MgUser.Id | Select-Object -ExpandProperty AdditionalProperties).Item('displayName')
$filter = "startsWith(DisplayName,'" + $MgUserManagerDisplayName + "')"
$MgUserManager = Get-MgUser -Filter $filter -ErrorAction Stop 
if ( $null -eq $MgUser) {
    Write-Output "ERROR: Unable to find user"
    exit # Stop if the user cannot be found
}

$allO365Groups = Get-MgGroup

### AAD: Reset user password 
<# MISSING #>




### SPO, Optional: Grant OneDrive file access to another user
<# MISSING #>






# MSONLINE: Remove any/all MFA authentication methods - Doesn't seem to remove phone number from authentication profile or app passwords
<# MISSING #>

# MSONLINE: Remove user properties: Department, Manager, Phone number
<# MISSING #>

# Export data
Write-Host "Summary file and reports have been exported to $($workDir)"

# Wrap-up
Write-Host "Disconnecting from all Powershell sessions"
# Disconnect-Modules



