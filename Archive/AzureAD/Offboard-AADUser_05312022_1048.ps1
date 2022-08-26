param
(   
    [Parameter(Mandatory = $True)] [string] $UserPrincipalName, # The UserPrincipalName of the user being offboarded
    [Parameter(Mandatory = $False)] [string] $Delegate, # grant mailbox of $UserPrincipalName to this user
    [Parameter(Mandatory = $False)] [boolean] $Calendar, # grant calendar of $UserPrincipalName to this user
    [Parameter(Mandatory = $False)] [boolean] $Contacts, # grant contacts of $UserPrincipalName to this user
    [Parameter(Mandatory = $False)] [string] $ForwardTo, # forward email sent to $UserPrincipalName to this user
    [Parameter(Mandatory = $False)] [string] $OneDriveTrustee # if present, grant access to $UserPrincipalName's OneDrive files access to this user
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
    try {
         
    }
    catch{
        $_
    }

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
    Write-Host "[MODULE] Connecting to AzureAD, check for a pop-up authentication window"
    try { 
        Get-AzureADTenantDetail -ErrorAction Stop
    } 
    catch {
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
$spoURL = "https://" + ($UserPrincipalName.Split("@")[1]).Split(".")[0] + "-admin.sharepoint.com" # Attempt to build spoAdminURL off of the UPN

New-Folder -folderPath C:\TempPath
Install-RequiredModules
Connect-Modules

# Retrieve objects for manipulation later
$AADUser = Get-AzureADUser -ObjectId $UserPrincipalName
$Manager = get-AzureADUsermanager -ObjectId $UserPrincipalName
$Mailbox = Get-Mailbox -Identity $UserPrincipalName

# AAD: Reset user password
$aadResetOutput = .\Reset-AADUserPassword.ps1 -UserPrincipalName $UserPrincipalName -Random
Write-Log $aadResetOutput

# AAD: Remove from all groups
$AADReport = @()
$AADGroups = (Get-AzureADUserMembership -ObjectId $AADUser.objectID -All:$True) | Where-Object { $_.MailEnabled -eq $False }
Write-Host "[AAD] Removing $($UserPrincipalName) from all AzureAD groups"
Write-Log "[AAD] Removing $($UserPrincipalName) from all AzureAD groups"
foreach ($g in $AADGroups) {

    # First notate the DisplayName of each group the user is a member of and store in $results
    $AADGroupExport = [PSCustomObject]@{
        AADGroup = $g.DisplayName
    }
    $AADReport += $AADGroupExport

    # Remove the user from the group
    try {
        Remove-AzureADGroupMember -ObjectId $g.objectID -MemberId $AADUser.ObjectId
    }
    catch {
        Write-Host "[AAD] Skipped Group: $($g.DisplayName), group is likely a Dynamic Group"
        Write-Log "[AAD] Skipped Group: $($g.DisplayName), group is likely a Dynamic Group"
    }
}

# EXO: Hide from GAL
if (((Get-Mailbox -Identity $UserPrincipalName).HiddenFromAddressListsEnabled) -eq $True){
    Write-Log "[EXO] Mailbox is already hidden from GAL, skipping..."
}
else {
    Write-Log "[EXO] Hiding mailbox from GAL"
    Set-Mailbox -Identity $UserPrincipalName -HiddenFromAddressListsEnabled:$True
}

# EXO: Remove data from mobile devices
Write-Log "[EXO] Checking for any mobile devices to delete data from..."
$userPhones = Get-MobileDevice -Mailbox $UserPrincipalName
if ($null -eq $userPhones){
    Write-Log "[EXO] No mobile devices found for $($UserPrincipalName), skipping..."
}
else {
    Write-Log "[EXO] Found mobile device(s). Removing the account from mobile device(s)"
    foreach ($p in $userPhones) {    
        Clear-MobileDevice -Identity $p.DistinguishedName -Confirm:$false
    }
}


# EXO: Remove from all groups
$distis = Get-DistributionGroup -Filter "Members -eq '$($Mailbox.DistinguishedName)'"

$distiReport = @()
foreach ($d in $distis) {
    $distiExport = [PSCustomObject]@{
        DistributionGroup = $d.PrimarySmtpAddress
    }
    $distiReport += $distiExport

    Write-Host "[EXO] Removing $($UserPrincipalName) from $($d.PrimarySmtpAddress)"
    Write-Log "[EXO] Removing $($UserPrincipalName) from $($d.PrimarySmtpAddress)"
    Remove-DistributionGroupMember -Identity $d.PrimarySmtpAddress -member $UserPrincipalName -Confirm:$false
}

# EXO: Re-assign 365 group ownership to user's manager
# Find all groups that a user is a member of. If they are the only owner, change the owner to be their manager
# If there are already other users present, just remove the user from the owners list

$o365groupOwnerReport = @()
Write-Host "[EXO] Retrieving all Groups and their owner(s). This may take some time ..."
Write-Log "[EXO] Retrieving all Groups and their owner(s). This may take some time ..."
$allO365Groups = Get-UnifiedGroup -ResultSize Unlimited | Sort-Object PrimarySmtpAddress
 
foreach($group in $allO365Groups){
    $owners = Get-UnifiedGroupLinks -Identity $group.Name -LinkType Owners | Select-Object -ExpandProperty PrimarySmtpAddress
    if ($owners -like $UserPrincipalName){ # find ONLY Groups that the user is an Owner of
        if ($owners.Count -eq 1){ # add manager, remove offboarded user
            Write-Host "[EXO] $($group.DisplayName) is ONLY owned by the user. Changing ownership to $($Manager.UserPrincipalName)"
            Write-Log "[EXO] $($group.DisplayName) is ONLY owned by the user. Changing ownership to $($Manager.UserPrincipalName)"
            Add-UnifiedGroupLinks -Identity $group.Alias -LinkType Member -Links $Manager.UserPrincipalName
            Add-UnifiedGroupLinks -Identity $group.Alias -LinkType Owner -Links $Manager.UserPrincipalName
            Remove-UnifiedGroupLinks -Identity $group.Alias -LinkType Owners -Links $UserPrincipalName -Confirm:$false
        } 
        if ($owners.Count -gt 1){ # there are already other owners, just remove the user
            Write-Host "[EXO] There are other owners present on $($group.DisplayName). Removing user from owners list"
            Write-Log "[EXO] There are other owners present on $($group.DisplayName). Removing user from owners list"
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
if ( $o365groupOwnerReport.Length -eq 0) { 
    Write-Host "[EXO] $($UserPrincipalName) is not an owner of any groups"
    Write-Log "[EXO] $($UserPrincipalName) is not an owner of any groups"
 }

# EXO: Remove from all UnifiedGroups (365 Groups and Teams)

$o365groupMembershipReport = @()
foreach ($grp in $allO365Groups){
    $groupMembers = Get-UnifiedGroup -Identity $grp.Name | Get-UnifiedGroupLinks -LinkType Member | Select-Object -expand PrimarySmtpAddress
    foreach($m in $groupMembers){
        if ($m -like $UserPrincipalName){ # find ONLY Groups that the user is a member of
            $o365groupMemberExport = [PSCustomObject]@{
                O365Group = $grp.DisplayName
                MemberName  = $UserPrincipalName
            }
            $o365groupMembershipReport += $o365groupMemberExport 
            Write-Host "[EXO] Removing $($UserPrincipalName) from UnifiedGroup $($grp.DisplayName)"
            Write-Log "[EXO] Removing $($UserPrincipalName) from UnifiedGroup $($grp.DisplayName)"
            Remove-UnifiedGroupLinks -Identity $grp.Alias -LinkType Member -Links $UserPrincipalName -Confirm:$false
        }
    }
}
if( $o365groupMembershipReport.Length -eq 0){ 
    Write-Host "[EXO] $($UserPrincipalName) is not a member of any groups"
    Write-Log "[EXO] $($UserPrincipalName) is not a member of any groups"
}

# EXO: Convert to Shared mailbox
if ((get-mailbox -Identity $UserPrincipalName).RecipientTypeDetails -eq "SharedMailbox") {
    Write-Host "[EXO] Mailbox $($UserPrincipalName) is already a SharedMailbox, skipping..."
    Write-Log "[EXO] Mailbox $($UserPrincipalName) is already a SharedMailbox, skipping..."
}
else {
    Write-Host "[EXO] Setting mailbox of $($UserPrincipalName) to a SharedMailbox"
    Write-Log "[EXO] Setting mailbox of $($UserPrincipalName) to a SharedMailbox"
    Set-Mailbox -Identity $UserPrincipalName -Type Shared
}

# EXO, Optional: Grant delegate access to mailbox/calendar/contacts
if ( $Delegate) {
    $delegateParams = @{
        UserPrincipalName   = $UserPrincipalName
        Trustee             = $Delegate   
        Calendar            = $Calendar
        Contacts            = $Contacts
    }
    $delegateOutput = .\Add-MailboxContactCalendarPermissions.ps1 @delegateParams
    Write-Log $delegateOutput
}

# EXO, Optional: Email forwarding
if ($ForwardTo) {
    Write-Host "[EXO] Setting mailbox forwarding to $($ForwardTo)"
    Write-Log "[EXO] Setting mailbox forwarding to $($ForwardTo)"
    Set-Mailbox -Identity $UserPrincipalName -ForwardingAddress $ForwardTo -DeliverToMailboxAndForward:$True
}

# SPO, Optional: Grant OneDrive file access to another user

if ($OneDriveTrustee) {
    $spoSiteUrl  = Get-SPOSite -Filter { Url -like "/personal/" } -IncludePersonalSite $true | Where-Object{$_.Owner -like $UserPrincipalName} | Select-Object -ExpandProperty Url
    Write-Host "[SPO] Granting $($OneDriveTrustee) access to $($UserPrincipalName) OneDrive Personal site"
    Write-Log "[SPO] Granting $($OneDriveTrustee) access to $($UserPrincipalName) OneDrive Personal site"
    .\Add-SPOSiteOwner.ps1 -spoURL $spoURL -spoSiteUrl $spoSiteUrl -TrusteeUser $OneDriveTrustee | Out-Null
}

# MSONLINE: Remove license(s)
Write-Log "[MSONLINE] Removing all licenses from $($UserPrincipalName)..."
.\Remove-UserLicenses.ps1 -UserPrincipalName $UserPrincipalName

# MSONLINE: Remove any/all MFA authentication methods - Doesn't seem to remove phone number from authentication profile or app apsswords
Write-Host "[MSONLINE] Resetting MFA for $($UserPrincipalName)"
Write-Log "[MSONLINE] Resetting MFA for $($UserPrincipalName)"
Reset-MsolStrongAuthenticationMethodByUpn -UserPrincipalName $UserPrincipalName

# MSONLINE: Remove user properties: Department, Manager, Phone number
# Note - Set-AzureADUser does NOT allow for setting $null
# Multiple lines seem to make this more consistent
Write-Host "[MSONLINE] Clearing properties from user: AlternateEmailAddresses, MobilePhone, PhoneNumber, Department, Manager"
Write-Log "[MSONLINE] Clearing properties from user: AlternateEmailAddresses, MobilePhone, PhoneNumber, Department, Manager"
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

# Wrap-up
Write-Host "Disconnecting from all Powershell sessions"
# Disconnect-Modules



