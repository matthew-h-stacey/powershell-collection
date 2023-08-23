param
(   
    [Parameter(Mandatory = $True)] [string] $UserPrincipalName, # The UserPrincipalName of the user being offboarded
    [Parameter(Mandatory = $False)] [string] $Delegate, # grant mailbox of $UserPrincipalName to this user
    [Parameter(Mandatory = $False)] [boolean] $AutoMapping, # map the inbox of $UserPrincipalName to the delegate's Outlook profile via AutoDiscover
    [Parameter(Mandatory = $False)] [boolean] $Calendar, # grant calendar of $UserPrincipalName to this user
    [Parameter(Mandatory = $False)] [boolean] $Contacts, # grant contacts of $UserPrincipalName to this user
    [Parameter(Mandatory = $False)] [string] $ForwardTo, # forward email sent to $UserPrincipalName to this user
    [Parameter(Mandatory = $False)] [string] $OneDriveTrustee, # if present, grant access to $UserPrincipalName's OneDrive files access to this user
    [Parameter(Mandatory = $False)] [boolean] $RemoveLicenses # if present, remove licenses from $UserPrincipalName
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

    # Check if ExchangeOnlineManagement is installed and connect if no connection exists
    if ($null -eq (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
        Write-Host "[MODULE] Required module ExchangeOnlineManagement is not installed"
        Write-Host "[MODULE] Installing ExchangeOnlineManagement" -ForegroundColor Cyan
        Install-Module ExchangeOnlineManagement -Repository PSGallery -AllowClobber -Force -Scope CurrentUser
    } 
    else { 
        Write-Host "[MODULE] ExchangeOnlineManagement is installed, continuing ..." 
    }

    # Check if AzureAD/AzureADPreview is installed and connect if no connection exists
    if (($null -eq (Get-Module -ListAvailable -Name AzureAD)) -and ($null -eq (Get-Module -ListAvailable -Name AzureADPreview))) {
        Write-Host "[MODULE] Required module  AzureAD/AzureADPreview is not installed"
        Write-Host "[MODULE] Installing AzureAD" -ForegroundColor Cyan
        Install-Module AzureAD -Repository PSGallery -AllowClobber -Force -Scope CurrentUser
    } 
    else { 
        Write-Host "[MODULE] AzureAD/AzureADPreview is installed, continuing ..." 
    }

    # Check if MSOnline is installed and connect if no connection exists
    if ($null -eq (Get-Module -ListAvailable -Name MSOnline)) {
        Write-Host "[MODULE] Required module MSOnline is not installed"
        Write-Host "[MODULE] Installing MSOnline" -ForegroundColor Cyan
        Install-Module MSOnline -Repository PSGallery -AllowClobber -Force -Scope CurrentUser
    } 
    else { 
        Write-Host "[MODULE] MSOnline is installed, continuing ..." 
    }

    # Check if Microsoft.Online.SharePoint.PowerShell is installed and connect if no connection exists
    if ($null -eq (Get-Module -ListAvailable -Name Microsoft.Online.SharePoint.PowerShell)) {
        Write-Host "[MODULE] Required module Microsoft.Online.SharePoint.PowerShell is not installed"
        Write-Host "[MODULE] Installing Microsoft.Online.SharePoint.PowerShell" -ForegroundColor Cyan
        Install-Module Microsoft.Online.SharePoint.PowerShell -Repository PSGallery -AllowClobber -Force -Scope CurrentUser
    } 
    else { 
        Write-Host "[MODULE] Microsoft.Online.SharePoint.PowerShell is installed, continuing ..." 
    }

    # added for Powershell 7 compatibility
    if ( $PSVersionTable.PSVersion.Major -ge 7) { # adding for Powershell 7 compatibility
        try { Import-Module AzureAD -UseWindowsPowershell -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
        }
        catch {
            [System.Management.Automation.RemoteException]
        }
        try {
            Import-Module AzureADPreview -UseWindowsPowershell  -ErrorAction SilentlyContinue -WarningAction SilentlyContinue | Out-Null 
        }
        catch {
            [System.Management.Automation.RemoteException]
        }
        Import-Module MSOnline -UseWindowsPowershell -WarningAction SilentlyContinue | Out-Null 
        Import-Module Microsoft.Online.SharePoint.PowerShell -UseWindowsPowershell -WarningAction SilentlyContinue | Out-Null
    }
}

function Connect-Modules {


    # Check if already connected to ExchangeOnline, connect if not connected
    $isConnected = Get-PSSession | Where-Object { $_.Name -like "ExchangeOnlineInternalSession*" -and $_.Availability -like "Available" }

    if ($null -eq $isConnected) {
        Write-Host "[MODULE] Connecting to ExchangeOnline, check for a pop-up authentication window"
        Connect-ExchangeOnline -ShowBanner:$False
    }

    # Check if already connected to MSOnline, connect if not connected
    
    try {
        Get-MsolDomain -ErrorAction Stop > $null
    }
    catch {
        Write-Host "[MODULE] Connecting to MsolService, check for a pop-up authentication window"
        
        Connect-MsolService
    }
    
    # Check if already connected to AzureAD, connect if not connected

    try { 
        Get-AzureADTenantDetail -ErrorAction Stop | Out-Null
    } 
    catch {
        Write-Host "[MODULE] Connecting to AzureAD, check for a pop-up authentication window"
        Connect-AzureAD | Out-Null
    }

    # Check if already connected to SharePointOnline, connect if not connected
    $sitecheck = $null
    while ($null -eq $sitecheck) {
        try { 
            $sitecheck = Get-SPOSite $spoURL -ErrorAction Stop
        }
        catch {
            Write-Host "[MODULE] Connecting to SharePointOnline, check for a pop-up authentication window"
            try {
                Connect-SPOService -Url $spoURL -ErrorAction Stop
            }  
            catch {
                Write-Warning "[MODULE] Unable to connect to SharePointOnline, please manually enter the admin URL (ex: https://contoso-admin.sharepoint.com) and try again"
                Write-Host "NOTE: If this continues to fail, verify you have permissions to connect to SharePointOnline before proceeding"
                $spoURL = Read-Host "Enter the SPO admin URL"
                Connect-SPOService -Url $spoURL
                $sitecheck = Get-SPOSite $spoURL
            }
        }
    }
    
    
}

function Disconnect-Modules {

    Disconnect-AzureAD -Confirm:$false # AzureAD
    Disconnect-ExchangeOnline -Confirm:$false -InformationAction Ignore -ErrorAction SilentlyContinue # EXO
    # SPO
    try {
        Disconnect-SPOService -InformationAction Ignore -ErrorAction SilentlyContinue
    }
    catch [System.InvalidOperationException] {
        # No SPOService session to disconnect, do nothing and internalize the error
    }    
    if ( $PSVersionTable.PSVersion.Major -lt 7) {
        # adding for Powershell 7 compatibility
        [Microsoft.Online.Administration.Automation.ConnectMsolService]::ClearUserSessionState() # MSOnline
    }
    else { 
        Get-PSSession | Remove-PSSession
    }
}

# Standard variables
$workDir = "C:\TempPath"
$logFile = "$workDir\$($UserPrincipalName)_User_Offboard_Report_$((Get-Date -Format "MM-dd-yyyy_HHmm")).log" 
$transcript = "$workDir\$($UserPrincipalName)_User_Offboard_Transcript.txt" 
$summaryFile = "$workDir\$($UserPrincipalName)_User_Offboard_Summary.txt" 
$spoURL = "https://" + ($UserPrincipalName.Split("@")[1]).Split(".")[0] + "-admin.sharepoint.com" # Attempt to build spoAdminURL off of the UPN

Start-Transcript -Path $transcript
New-Folder -folderPath C:\TempPath
Install-RequiredModules
Connect-Modules

# Retrieve objects for manipulation later
$AADUser = Get-AzureADUser -ObjectId $UserPrincipalName
$MSOLUser = Get-MsolUser -UserPrincipalName $UserPrincipalName
$Manager = get-AzureADUsermanager -ObjectId $UserPrincipalName
$Mailbox = Get-Mailbox -Identity $UserPrincipalName

### AAD: Reset user password
$aadResetOutput = .\Reset-AADUserPassword.ps1 -UserPrincipalName $UserPrincipalName -Random
Write-Log $aadResetOutput
$aadResetOutput | Out-File $summaryFile -Append

###  AAD: Remove from all groups
$AADReport = @() # Array used for the total output of group removal
$excludedGroups = @() # Array used to exclude groups from the removal. Currently this will only exclude Dynamic Groups

$AADGroups = (Get-AzureADUserMembership -ObjectId $AADUser.objectID -All:$True) | Where-Object { $_.MailEnabled -eq $False } # All Azure group membership
foreach ( $g in $AADGroups) { # build up the $excludedGroups array with any dynamic groups
    $displayName = $g.DisplayName
    $filter = "startsWith(DisplayName,'" + $displayName + "')"
    if (((Get-AzureADMSGroup -Filter $filter).GroupTypes) -eq "DynamicMembership") { # If this matches, group is dynamic and should be skipped from the group removal process below
        $excludedGroups += $g.DisplayName
    }
}

foreach ($g in $AADGroups) {
    if ( $excludedGroups -notcontains $g.DisplayName ) {
        $AADGroupExport = [PSCustomObject]@{
            AADGroup = $g.DisplayName
        }
        $AADReport += $AADGroupExport
        Write-Log "[AAD] Removing $($UserPrincipalName) from AzureAD group: $($g.DisplayName)"
        try {
            Remove-AzureADGroupMember -ObjectId $g.objectID -MemberId $AADUser.ObjectId
        }
        catch {
            Write-Log "[AAD] An error occured attempting to remove $($UserPrincipalName) from AzureAD group: $($g.DisplayName)"
        }      
    }

}

# Write to summary file
"[AAD] Removed $($UserPrincipalName) from AzureAD group(s): " + ($AADReport.AADGroup -join ', ') | Out-File $summaryFile -Append


### EXO: Hide from GAL
if (((Get-Mailbox -Identity $UserPrincipalName).HiddenFromAddressListsEnabled) -eq $True){
    Write-Log "[EXO] SKIPPED: Hide mailbox from GAL; Reason: Mailbox is already hidden"
    "[EXO] SKIPPED: Hide mailbox from GAL; Reason: Mailbox is already hidden" | Out-File $summaryFile -Append
}
else {
    Write-Log "[EXO] Hiding mailbox from GAL"
    Set-Mailbox -Identity $UserPrincipalName -HiddenFromAddressListsEnabled:$True
    "[EXO] Hid mailbox from GAL" | Out-File $summaryFile -Append
}


### EXO: Remove data from mobile devices
Write-Log "[EXO] Checking for any mobile devices to delete data from..."
$userPhones = Get-MobileDevice -Mailbox $UserPrincipalName
if ($null -eq $userPhones){
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

### EXO: Remove from all distribution groups
$distiReport = @() # Array used for the total output of group removal

$distis = Get-DistributionGroup -Filter "Members -eq '$($Mailbox.DistinguishedName)'"
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

### EXO: Re-assign 365 group ownership to user's manager
# Find all groups that a user is a member of. If they are the only owner, change the owner to be their manager
# If there are already other users present, just remove the user from the owners list

$o365groupOwnerReport = @()  # Array used for the total output of group removal
$allO365Groups = Get-UnifiedGroup -ResultSize Unlimited | Sort-Object PrimarySmtpAddress
 
foreach($group in $allO365Groups){
    $owners = Get-UnifiedGroupLinks -Identity $group.Name -LinkType Owners | Select-Object -ExpandProperty PrimarySmtpAddress
    if ($owners -like $UserPrincipalName){ # find ONLY Groups that the user is an Owner of
        if ($owners.Count -eq 1){ # add manager, remove offboarded user
            Write-Log "[EXO] $($group.DisplayName) is ONLY owned by the user. Changing ownership to $($Manager.UserPrincipalName)"
            Add-UnifiedGroupLinks -Identity $group.Alias -LinkType Member -Links $Manager.UserPrincipalName
            Add-UnifiedGroupLinks -Identity $group.Alias -LinkType Owner -Links $Manager.UserPrincipalName
            Remove-UnifiedGroupLinks -Identity $group.Alias -LinkType Owners -Links $UserPrincipalName -Confirm:$false
        } 
        if ($owners.Count -gt 1){ # there are already other owners, just remove the user
            Write-Log "[EXO] There are other owners present on $($group.DisplayName). Removing user from owners list"
            Remove-UnifiedGroupLinks -Identity $group.Alias -LinkType Owners -Links $UserPrincipalName -Confirm:$false            
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


### EXO: Remove from all UnifiedGroups (365 Groups and Teams)
$o365groupMembershipReport = @()  # Array used for the total output of group removal

foreach ($grp in $allO365Groups){
    $groupMembers = Get-UnifiedGroup -Identity $grp.Name | Get-UnifiedGroupLinks -LinkType Member | Select-Object -expand PrimarySmtpAddress
    foreach($m in $groupMembers){
        if ($m -like $UserPrincipalName){ # find ONLY Groups that the user is a member of
            $o365groupMemberExport = [PSCustomObject]@{
                O365Group = $grp.DisplayName
            }
            $o365groupMembershipReport += $o365groupMemberExport 
            Write-Log "[EXO] Removing $($UserPrincipalName) from UnifiedGroup $($grp.DisplayName)"
            Remove-UnifiedGroupLinks -Identity $grp.Alias -LinkType Member -Links $UserPrincipalName -Confirm:$false
        }
    }
}
if( $o365groupMembershipReport.Length -eq 0){ 
    Write-Log "[EXO] $($UserPrincipalName) is not a member of any groups"
}

# Write to summary file
"[EXO] Removed $($UserPrincipalName) membership from 365 Group(s): " + ($o365groupMembershipReport.O365Group -join ', ') | Out-File $summaryFile -Append


### EXO: Convert to Shared mailbox
if ((get-mailbox -Identity $UserPrincipalName).RecipientTypeDetails -eq "SharedMailbox") {
    Write-Log "[EXO] Mailbox $($UserPrincipalName) is already a SharedMailbox, skipping..."
    "[EXO] SKIPPED: Convert mailbox to a SharedMailbox; Reason: Mailbox is already a SharedMailbox" | Out-File $summaryFile -Append
}
else {
    Write-Log "[EXO] Setting mailbox of $($UserPrincipalName) to a SharedMailbox"
    Set-Mailbox -Identity $UserPrincipalName -Type Shared
    "[EXO] Converted mailbox of $($UserPrincipalName) to a SharedMailbox" | Out-File $summaryFile -Append
}

### EXO, Optional: Grant delegate access to mailbox/calendar/contacts
if ( $Delegate) {
    $delegateParams = @{
        UserPrincipalName   = $UserPrincipalName
        Trustee             = $Delegate   
        Calendar            = $Calendar
        Contacts            = $Contacts
        AutoMapping         = $AutoMapping
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

### EXO, Optional: Email forwarding
if ($ForwardTo) {
    Write-Log "[EXO] Setting mailbox forwarding to $($ForwardTo)"
    Set-Mailbox -Identity $UserPrincipalName -ForwardingAddress $ForwardTo -DeliverToMailboxAndForward:$True
    "[EXO] Forwarded email from $($UserPrincipalName) to $($ForwardTo)" | Out-File $summaryFile -Append
}

### SPO, Optional: Grant OneDrive file access to another user

if ($OneDriveTrustee) {
    $spoSiteUrl  = Get-SPOSite -Filter { Url -like "/personal/" } -IncludePersonalSite $true | Where-Object{$_.Owner -like $UserPrincipalName} | Select-Object -ExpandProperty Url
    Write-Log "[SPO] Granting $($OneDriveTrustee) access to $($UserPrincipalName) OneDrive Personal site"
    .\Add-SPOSiteOwner.ps1 -spoURL $spoURL -spoSiteUrl $spoSiteUrl -TrusteeUser $OneDriveTrustee | Out-Null
    "[SPO] Granting $($OneDriveTrustee) access to $($UserPrincipalName) OneDrive Personal site" | Out-File $summaryFile -Append
}
else {
    Write-Log "[SPO] SKIPPED: Grant access to $($UserPrincipalName) OneDrive Personal site; Reason: No delegate specified"
    "[SPO] SKIPPED: Grant access to $($UserPrincipalName) OneDrive Personal site; Reason: No delegate specified" | Out-File $summaryFile -Append
}

# MSONLINE: Remove license(s)
if ($RemoveLicenses) {
    Write-Log "[MSONLINE] Removing all licenses from $($UserPrincipalName)..."
    .\Remove-UserLicenses.ps1 -UserPrincipalName $UserPrincipalName
    "[MSONLINE] Removed all licenses from $($UserPrincipalName)" | Out-File $summaryFile -Append
}
else {
    "[MSONLINE] SKIPPED: Remove user licenses; Reason: Option not selected" | Out-File $summaryFile -Append
}



# MSONLINE: Remove any/all MFA authentication methods - Doesn't seem to remove phone number from authentication profile or app passwords
Write-Log "[MSONLINE] Resetting MFA for $($UserPrincipalName)"
Reset-MsolStrongAuthenticationMethodByUpn -UserPrincipalName $UserPrincipalName
"[MSONLINE] Reset MFA methods for $($UserPrincipalName)" | Out-File $summaryFile -Append


# MSONLINE: Remove user properties: Department, Manager, Phone number
# Note - Set-AzureADUser does NOT allow for setting $null
# Multiple lines seem to make this more consistent

# Object for writing particular propreties to summary log file
$userExport = [PSCustomObject]@{
    Department              = $MSOLUser.Department
    Manager                 = (Get-AzureADUserManager -ObjectId $AADUser.UserPrincipalName).DisplayName
    StreetAddress           = $MSOLUser.StreetAddress
    City                    = $MSOLUser.City
    State                   = $MSOLUser.State
    Zip                     = $MSOLUser.PostalCode
    Office                  = $MSOLUser.Office
    PhoneNumber             = $MSOLUser.PhoneNumber
    MobilePhone             = $MSOLUser.MobilePhone
    AlternateEmailAddresses = $MSOLUser.AlternateEmailAddresses
}

Set-MsolUser -UserPrincipalName $UserPrincipalName -Department "$null"
Set-MsolUser -UserPrincipalName $UserPrincipalName -StreetAddress "$null"
Set-MsolUser -UserPrincipalName $UserPrincipalName -City "$null"
Set-MsolUser -UserPrincipalName $UserPrincipalName -State "$null"
Set-MsolUser -UserPrincipalName $UserPrincipalName -PostalCode "$null"
Set-MsolUser -UserPrincipalName $UserPrincipalName -Office "$null"
Set-MsolUser -UserPrincipalName $UserPrincipalName -PhoneNumber "$null"
Set-MsolUser -UserPrincipalName $UserPrincipalName -MobilePhone "$null"
Set-MsolUser -UserPrincipalName $UserPrincipalName -AlternateEmailAddresses @()
Set-MsolUser -UserPrincipalName $UserPrincipalName -ImmutableId "$null"

Write-Log "[MSONLINE] Cleared the following properties from user: AlternateEmailAddresses, City, Department, Manager, MobilePhone, Office, PhoneNumber, State, StreetAddress, Zip"

Remove-AzureADUserManager -ObjectId $AADUser.ObjectId

"[MSONLINE] Wiped the following properties from the user"  | Out-File $summaryFile -Append

foreach ($p in $userExport.PSObject.Properties) {
    "$($p.Name): $($p.Value)" | Out-File $summaryFile -Append
}

# Export data
Write-Host "Exporting reports to $($workDir)"
$AADReport | export-csv -Path "$workDir\$($UserPrincipalName)_Offboard_AADGroups.csv" -NoTypeInformation
$userExport | export-csv -Path "$workDir\$($UserPrincipalName)_Offboard_AADUserProperties.csv" -NoTypeInformation
$distiReport | export-csv -Path "$workDir\$($UserPrincipalName)_Offboard_DistiMembership.csv" -NoTypeInformation
$o365groupOwnerReport  | export-csv -Path "$workDir\$($UserPrincipalName)_Offboard_O365OwnedGroups.csv" -NoTypeInformation
$o365groupMembershipReport | export-csv -Path "$workDir\$($UserPrincipalName)_Offboard_O365GroupMembership.csv" -NoTypeInformation

# Wrap-up
Write-Host "Disconnecting from all Powershell sessions"
# Disconnect-Modules



