param(
    [Parameter(Mandatory = $true)]
    [string]
    $ClientName,

    [Parameter(Mandatory = $true)]
    [string]
    $ExportPath
)

function New-Folder {

    <#
.SYNOPSIS
Determine if a folder already exists, or create it  if not.

.EXAMPLE
New-Folder C:\TempPath
#>

    param(
        [Parameter(Mandatory = $True)]
        [String]
        $Path
    )
    if (-not (Test-Path -LiteralPath $Path)) {
        try {
            New-Item -Path $Path -ItemType Directory -ErrorAction Stop | Out-Null
        } catch {
            Write-Error -Message "Unable to create directory '$Path'. Error was: $_" -ErrorAction Stop
        }
    } 

}
function Connect-RequiredModules {

    $allModulesConnected = $true
    Write-Host "######### Starting to connect to required modules ... #########"
    # EXO
    try {
        Write-Host "Connecting to Exchange online ... " -NoNewline
        Connect-ExchangeOnline -ShowBanner:$false
        Get-OrganizationConfig -ErrorAction Stop | Out-Null
        Write-Host "SUCCESS"
    } catch {
        Write-Host "[ERROR] Failed to connect to Exchange Online"
        $allModulesConnected = $false
    }
    # Teams
    try {
        Write-Host "Connecting to Microsoft Teams ... " -NoNewline
        Connect-MicrosoftTeams | Out-Null
        Get-CsTenant -ErrorAction Stop | Out-Null
        Write-Host "SUCCESS"
    } catch {
        Write-Host "[ERROR] Failed to connect to Microsoft Teams"
        $allModulesConnected = $false
    }
    # Graph
    try {
        Write-Host "Connecting to Microsoft Graph ... " -NoNewline
        Connect-MgGraph -Scopes AuditLog.Read.All, User.Read.All, RoleManagement.Read.Directory	
        Get-MgOrganization -ErrorAction Stop | Out-Null
        Write-Host "SUCCESS"
    } catch {
        Write-Host "[ERROR] Failed to connect to Microsoft Teams"
        $allModulesConnected = $false
    }
    return $allModulesConnected

}

function Disconnect-RequiredModules {
    
    Write-Host "[INFO] Disconnecting from required modules"
    Disconnect-MicrosoftTeams | Out-Null
    Disconnect-MgGraph | Out-Null
    Disconnect-ExchangeOnline -Confirm:$false

}

$connected = Connect-RequiredModules
if ( $connected ) {
    # Empty list used to store output
    $results = [System.Collections.Generic.List[System.Object]]::new()

    # Return one array ($msGraphOutput) with all objects, supporting count past the default 999
    $uri = 'https://graph.microsoft.com/beta/users?$select=DisplayName,UserPrincipalName,Mail,UserType,AccountEnabled,onPremisesSyncEnabled,signInActivity,AssignedLicenses,LastPasswordChangeDateTime,CompanyName,EmployeeId,Department,JobTitle,StreetAddress,City,State,Country,BusinessPhones,MobilePhone&$top=999'
    $msGraphOutput = @()
    $nextLink = $null
    Write-Host "[INFO] Retrieving user objects via Microsoft Graph"
    do {
        $uri = if ($nextLink) { 
            $nextLink
        } else {
            $uri
        }
        try {
            $response = Invoke-MgGraphRequest -Method GET -Uri $uri
        } catch {
            Write-Host "[ERROR] Failed to retrieve user objects for report. Error: $($_.Exception.Message). Please review the error and try again"
            exit 1
        }
        $output = $response.Value
        $msGraphOutput += $output
        $nextLink = $response.'@odata.nextLink'
    } until (-not $nextLink)

    # Table for Microsoft SKU ID to friendly names
    $skusMappingTable = Import-Csv -Path "C:\Users\mstacey\powershell-collection\_Resources\M365_License_to_friendlyName.csv"

    # All Teams numbers associated with users
    Write-Host "[INFO] Retrieving Teams users and phone numbers"
    $allTeamsNumbers = Get-CsOnlineUser | Where-Object { $_.LineURI -notlike $null } | Select-Object DisplayName, UserPrincipalName, LineURI

    # All shared mailboxes
    Write-Host "[INFO] Retrieving shared mailboxes"
    $sharedMailboxes = Get-EXOMailbox -ResultSize unlimited -Filter "RecipientTypeDetails -eq 'SharedMailbox'" $upn

    # Retrieve directory roles and membership
    $allRoleMemberships = @()
    Write-Host "[INFO] Retrieving directory role memberships"
    Get-MgDirectoryRole | ForEach-Object {
        $member = Get-MgDirectoryRoleMember -DirectoryRoleId $_.Id
        $allRoleMemberships += [pscustomobject]@{
            Role   = $_.DisplayName
            Member = @($member.AdditionalProperties.userPrincipalName)
        }
    }

    # Iterate through each user in the Graph output
    # Add a PSCustomObject with combined properties to the list object
    $counter = 1
    $totalCount = $msGraphOutput.Count
    Write-Progress -PercentComplete (($counter / $totalCount) * 100) -Status "Processing objects" -CurrentOperation "[INFO] Processing results ($counter/$totalCount)"
    foreach ( $User in $msGraphOutput) {
        $upn = $User.UserPrincipalName

        # Retrieve sign-in information
        if ($IncludeLastLogin) { 
            $LastLogin = $user.signInActivity.lastSignInDateTime
            if ($LastLogin) {
                $InactiveDays = (New-TimeSpan -Start $user.signInActivity.lastSignInDateTime).Days
            } else {
                $InactiveDays = "N/A" 
            }
        }

        # Assigned licenses. Pulls SKUs via Graph then converts to friendly name using the helper file
        $licenses = @()
        foreach ($sku in $User.AssignedLicenses.SKUID) {
            $licenses += ($skusMappingTable | Where-Object { $_.GUID -eq "$sku" } | Select-Object -expand DisplayName -Unique)
        }

        # Retrieve Teams number, if the user has one
        $TeamsNumber = $allTeamsNumbers | Where-Object { $_.UserPrincipalName -like $upn } | Select-Object -ExpandProperty LineURI

        # Check if the user account is a shared mailbox
        if ($sharedMailboxes | Where-Object { $_.UserPrincipalName -like $upn }) {
            $isSharedMailbox = $true
        } else {
            $isSharedMailbox = $false
        }

        $source = if ( $User.onPremisesSyncEnabled -eq $True ) {
            "On-premises"
        } else {
            "Cloud only"
        }
        $manager = try {
            (Get-MgUserManager -UserId $User.Id -ErrorAction Stop).AdditionalProperties.displayName
        } catch {
            "N/A"
        }
        $results.Add([PSCustomObject]@{
            DisplayName        = $User.DisplayName
            UserPrincipalName  = $upn
            Mail               = $User.Mail
            UserType           = $User.UserType
            AccountEnabled     = $User.AccountEnabled
            Roles              = ($allRoleMemberships | Where-Object { $_.Member -like $upn } | Sort-Object | Select-Object -ExpandProperty role) -join ", "
            Source             = $source
            SharedMailbox      = $isSharedMailbox
            LastLogin          = $LastLogin
            InactiveDays       = $InactiveDays
            LastPasswordChange = $User.LastPasswordChangeDateTime
            DaysSincePwChange  = if ($User.LastPasswordChangeDateTime) {
                (New-TimeSpan -Start $User.LastPasswordChangeDateTime).Days
                    } else {
                        "N/A"
                    }
            Licenses           = $licenses -join ", "
            CompanyName        = $User.CompanyName
            Department         = $User.Department
            JobTitle           = $User.JobTitle
            Manager            = $manager
            EmployeeId         = $User.employeeId
            StreetAddress      = $User.StreetAddress
            City               = $User.City
            State              = $User.State
            Country            = $User.Country
            BusinessPhones     = $User.BusinessPhones -join ", "
            TeamsNumber        = $TeamsNumber
        })
        # Increment the counter
        $counter++
    }

    New-Folder -Path $ExportPath
    $filePath = "$ExportPath\${ClientName}_EntraID_User_Report_$((Get-Date -Format 'yyyy-MM-dd_HHmm')).csv"
    try {
        $results | Export-Csv -Path $filePath -NoTypeInformation
        Write-Host "[INFO] Exported report to: $filePath"
    } catch {
        Write-Host "[ERROR] Failed to export report to: $filePath. Error: $($_.Exception.Message)"
    }
    Disconnect-RequiredModules
} else {
    Write-Host "[ERROR] Failed to connect all modules. Please try again"
}