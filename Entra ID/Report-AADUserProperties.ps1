Param
(   
    [Parameter(Mandatory = $true)] [string] $ClientName, # for naming of the report only
    [Parameter(Mandatory = $true)] [string] $GraphAppID, # App ID of the Azure App registration
    [Parameter(Mandatory = $true)] [string] $GraphAppSecret, # Secret of the Azure App registration
    [Parameter(Mandatory = $true)] [string] $AzureTenantDomain, # Primary domain for the Azure tenant
    [Parameter()] [switch] $EnabledOnly, # Only report on enabled users
    [Parameter()] [switch] $Teams, # Pull Teams data
    [parameter(ParameterSetName = "identityA")] [string] $Group, # Group to run the report
    [parameter(ParameterSetName = "identityB")] [string] $User # User to run report on

)

# Currently uses a combination of AzureAD module, Teams module, and an "App registration" in Azure for Graph API with Users.Read to query properties about either an AzureAD User or Group
# Requires .\M365_License_to_friendlyName.csv and .\Graph-Export.ps1
# Example: .\Report-AADUserProperties.ps1 -ClientName CONTOSO -GraphAppID 25333d31-13976-8d1a-nbe4-faa5ead8237a -GraphAppSecret mJ67Q~0I4Kr7Gx6kOhAwOXBBVes4xmInp-h1S -AzureTenantDomain contoso.com -Group "All Users"

<# Reference:
https://cloudtech.nu/2020/05/03/export-azure-ad-last-logon-with-powershell-graph-api/
https://www.awshole.com/2020/06/18/identifying-stale-users-in-azure-active-directory/
#>

# Change as needed
$exportPath = "C:\TempPath"



function Install-RequiredModules {

    # AzureAD or AzureADPreview
    if (($null -eq (Get-Module -ListAvailable -Name AzureAD)) -and ($null -eq (Get-Module -ListAvailable -Name AzureADPreview))) {
        Write-Host "[MODULE] Required module  AzureAD/AzureADPreview is not installed"
        Write-Host "[MODULE] Installing AzureAD" -ForegroundColor Cyan
        Install-Module AzureAD -Repository PSGallery -AllowClobber -Force -Scope CurrentUser
    } 
    else { 
        Write-Host "[MODULE] AzureAD/AzureADPreview is installed, continuing ..." 
    }

    # MicrosoftTeams (if Teams switch is used)
    if ($Teams){    
        if ($null -eq (Get-Module -ListAvailable -Name MicrosoftTeams)) {
            Write-Host "[MODULE] Required module MicrosoftTeams is not installed"
            Write-Host "[MODULE] Installing MicrosoftTeams" -ForegroundColor Cyan
            Install-Module MicrosoftTeams -Repository PSGallery -AllowClobber -Force -Scope CurrentUser
        } 
        else {
            Write-Host "[MODULE] MicrosoftTeams is installed, continuing ..."
        }
}

}

function Connect-Modules {
    
    # AzureAD - Import and AzureAD module (Import portion has been added for Powershell 7 compatibility)
    if ( $PSVersionTable.PSVersion.Major -ge 7) { 
        try {
            Import-Module AzureAD -UseWindowsPowershell -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
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
    }
    # AzureAD - Check if already connected to AzureAD, connect if not connected
    Write-Host "[MODULE] Connecting to AzureAD, check for a pop-up authentication window"
    try { 
        Get-AzureADTenantDetail -ErrorAction Stop
    } 
    catch {
        Connect-AzureAD | Out-Null
    }
    
    # MicrosoftTeams - Connect
    if ($Teams) { 
        Write-Host "[MODULE] Connecting to MicrosoftTeams, check for a pop-up authentication window"
        Connect-MicrosoftTeams  | Out-Null
    }
}

Function Write-Log {
    Param ([string]$logstring)
    Add-Content $logFile -Value "$(Get-Date -Format "MM/dd/yyyy HH:mm") $logstring"
}


Install-RequiredModules
Connect-Modules

# Report and log file names that will export to the path above
$reportFile = $exportPath + "\" + $ClientName + "_User_Report_$((Get-Date -Format "MM-dd-yyyy_HHmm")).csv" # Ex: Contoso_User_Report_11-24-2021_14:53.csv
$logFile = $exportPath + "\" + $ClientName + "_User_Report_$((Get-Date -Format "MM-dd-yyyy_HHmm"))_errors.log" # Ex: Contoso_User_Report_11-24-2021_14:56_errors.log

# Import the complementing CSV which will allow for conversion of license ID to friendly name
# Graph will pull license GUID, the CSV matches Product_Display_Name to GUID to easier reporting
$licenseToFriendlyName = import-csv .\M365_License_to_friendlyName.csv

# Function for writing errors to log

# Connects to MS Graph and pulls user and licensing data
$graphOutput = .\Graph-Export.ps1 -ClientName $ClientName -GraphAppID $GraphAppID -GraphAppSecret $GraphAppSecret -AzureTenantDomain $AzureTenantDomain

# Format the graph output with the desired properties, then with the proper date-time format
[datetime]::Parse('2020-04-07T16:55:35Z') | out-null
$graphLastLogin = $graphOutput | Select-Object UserPrincipalName, @{n = "LastLoginDate"; e = { [datetime]::Parse($_.signInActivity.lastSignInDateTime) } }

# Retrieve Teams numbers for user and store in a variable, to be searched through later
if ($Teams) {
    $allTeamsNumbers = Get-CsOnlineUser | Where-Object { $_.LineURI -notlike $null } | Select-Object DisplayName, UserPrincipalName, LineURI
}

if ($User -ne '') { # if user parameter was provided
    #$userSearch = $true # set boolean that the report is for a user search
    if($EnabledOnly){ # if option parameter "EnabledOnly" is specified,
        $feed = Get-AzureADUser -ObjectId $User -ErrorAction Stop | Where-Object{$_.AccountEnabled -eq $true} # filter the search only by enabled users
    }
    else {
        $feed = Get-AzureADUser -ObjectId $User -ErrorAction Stop # get user, includes disabled
    }
}

if ($Group -ne '') { # if group parameter was provided
    #$groupSearch = $true # set boolean that the report is for a group search
    if ($EnabledOnly){ # if option parameter "EnabledOnly" is specified,
        $feed = Get-AzureADGroupMember -ObjectId (Get-AzureADGroup -Filter "startswith(DisplayName,'$Group')").ObjectID -All:$true -ErrorAction Stop | Where-Object { $_.AccountEnabled -eq $true } | Sort-Object DisplayName # get all enabled members of group
    }
    else {
        try {
            $feed = Get-AzureADGroupMember -ObjectId 942a38c5-27a7-4312-ac60-f685633df6a9 -All:$true -ErrorAction Stop | Sort-Object DisplayName # get all users of group, includes deleted
            #$feed = Get-AzureADGroupMember -ObjectId (Get-AzureADGroup -Filter "startswith(DisplayName,'$Group')" -ErrorAction Stop).ObjectID -All:$true -ErrorAction Stop | Sort-Object DisplayName # get all users of group, includes deleted
        }
        catch [System.Management.Automation.ParameterBindingException] {
            "ERROR: Multiple group names with DisplayName found: $($Group)"
        }
    }
}

# Create empty array to populate with PSCustomObject results for output later
$results = @()

foreach ($u in $feed) {
    # Start retrieving AAD and licensing info
    
    $UPN = $u.UserPrincipalName
    $AADUser = Get-AzureADUser -ObjectId $UPN

    # Retrieve all assignedLicenses, then convert the license GUID to its "Friendly Name"
    $skuIDs = $graphOutput | Where-Object { $_.UserPrincipalName -like $UPN } | Select-Object -expand assignedlicenses | Select-Object -expand skuid
    $Licenses = @()
    foreach ($sku in $skuIDs) {
        $Licenses += ($licenseToFriendlyName | Where-Object { $_.guid -eq "$sku" } | Select-Object -expand Product_Display_Name -Unique)
    }
    
    $LastLogin = $graphLastLogin | Where-Object { $_.UserPrincipalName -like $UPN } | Select-Object -ExpandProperty LastLoginDate
    try {
        $InactiveDays = (New-TimeSpan -Start $LastLogin).Days
    }
    catch {
        Write-Log "Failed to retrieve LastLogin for $UPN"
        $InactiveDays = "N/A"
    }
    
    if ( $Teams ) {
        try {
            $teamsNumber = $allTeamsNumbers | Where-Object { $_.UserPrincipalName -like $UPN } | Select-Object -ExpandProperty LineURI
        }
        catch {
            Write-Log "No Teams number found for $UPN"
        }
    }
    
    # Compile user data into a PSCustomObject for exporting to CSV
    $userExport = [PSCustomObject]@{
        DisplayName         = $AADUser.DisplayName
        Mail                = $AADUser.Mail
        LastLogin           = $LastLogin
        InactiveDays        = $InactiveDays
        Licenses             = $Licenses -join ";"
        CompanyName         = $AADUser.CompanyName
        Manager             = (Get-AzureADUserManager -ObjectId $AADUser.UserPrincipalName).DisplayName
        Department          = $AADUser.Department
        JobTitle            = $AADUser.JobTitle
        StreetAddress       = $AADUser.StreetAddress
        City                 = $AADUser.City
        PhoneNumber          = $AADUser.TelephoneNumber
        TeamsNumber          = $teamsNumber          
    }
    $results += $userExport
}
# Export user results
$results | Export-Csv $reportFile -NoTypeInformation -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
Write-Host "Exported results to $reportFile"


if ( $Teams ) { 
    Disconnect-MicrosoftTeams -Confirm:$false
}
Disconnect-AzureAD -Confirm:$false