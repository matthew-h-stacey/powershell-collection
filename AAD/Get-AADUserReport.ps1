<#
TO-DO:
- Add full notes block
- Replace phone number and manager checks with MG Graph requests
#>

function Get-AADUserReport {

    [SkyKickCommand(DisplayName = "Set Parameter Sections", Sections = { "Scope", "Activity", "Licenses", "Company Information", "Location", "Phone numbers" })]
    param(
	
        [SkyKickParameter(
            DisplayName = "Only show active users",    
            Section = "Scope",
            DisplayOrder = 1,
            HintText = "Setting this to True filters out all unlicensed users, and any members of this Azure AD group: CM_ActiveUsers."
        )]
        [Boolean]$OnlyActiveUsers = $false, # "user" here implies a human user

        [SkyKickParameter(
            DisplayName = "Last Login",    
            Section = "Activity",
            DisplayOrder = 1,
            HintText = "Display user's last login timestamp."
        )]
        [Boolean]$IncludeLastLogin = $true,

        [SkyKickParameter(
            DisplayName = "Days since last login",    
            Section = "Activity",
            DisplayOrder = 2,
            HintText = "Display the number of days since the last login."
        )]
        [Boolean]$IncludeInactiveDays = $true,

        [SkyKickParameter(
            DisplayName = "Last password change",
            Section = "Activity",
            DisplayOrder = 3,
            HintText = "Display the timestamp of the last password change."
        )]
        [Boolean]$IncludeLastPasswordChange = $true,

        [SkyKickParameter(
            DisplayName = "Days since last password change",    
            Section = "Activity",
            DisplayOrder = 4,
            HintText = "Display the number of days since the last password change."
        )]
        [Boolean]$IncludeDaysSincePwChange = $true,

        [SkyKickParameter(
            DisplayName = "Assigned licenses",    
            Section = "Licenses",
            DisplayOrder = 5,
            HintText = "Display the licenses assigned to the user."
        )]
        [Boolean]$IncludeLicenses = $true,
		
        [SkyKickParameter(
            DisplayName = "Company name",    
            Section = "Company Information",
            DisplayOrder = 6,
            HintText = "Display the company name."
        )]
        [Boolean]$IncludeCompanyName = $true,

        [SkyKickParameter(
            DisplayName = "Department",    
            Section = "Company Information",
            DisplayOrder = 7,
            HintText = "Display the user's department."
        )]
        [Boolean]$IncludeDepartment = $true,

        [SkyKickParameter(
            DisplayName = "Job title",    
            Section = "Company Information",
            DisplayOrder = 8,
            HintText = "Display the user's job title."
        )]
        [Boolean]$IncludeJobTitle = $true,

        [SkyKickParameter(
            DisplayName = "Manager",    
            Section = "Company Information",
            DisplayOrder = 9,
            HintText = "Display the user's job title."
        )]
        [Boolean]$IncludeManager = $true,

        [SkyKickParameter(
            DisplayName = "Employee ID",    
            Section = "Company Information",
            DisplayOrder = 10,
            HintText = "Display the user's employee ID."
        )]
        [Boolean]$IncludeEmployeeId = $true,

        [SkyKickParameter(
            DisplayName = "Street Address",    
            Section = "Location",
            DisplayOrder = 11,
            HintText = "Display the user's street address."
        )]
        [Boolean]$IncludeStreetAddress = $true,

        [SkyKickParameter(
            DisplayName = "City",    
            Section = "Location",
            DisplayOrder = 12,
            HintText = "Display the user's city."
        )]
        [Boolean]$IncludeCity = $true,
		
        [SkyKickParameter(
            DisplayName = "State",    
            Section = "Location",
            DisplayOrder = 13,
            HintText = "Display the user's state."
        )]
        [Boolean]$IncludeState = $true,

        [SkyKickParameter(
            DisplayName = "Country",    
            Section = "Location",
            DisplayOrder = 14,
            HintText = "Display the user's country."
        )]
        [Boolean]$IncludeCountry = $true,

        [SkyKickParameter(
            DisplayName = "Phone number",    
            Section = "Phone numbers",
            DisplayOrder = 15,
            HintText = "Display the user's phone number."
        )]
        [Boolean]$IncludePhoneNumber = $true ,
		
        [SkyKickParameter(
            DisplayName = "Teams number",    
            Section = "Phone numbers",
            DisplayOrder = 16,
            HintText = "Display the user's Teams phone number."
        )]
        [Boolean]$IncludeTeamsNumber = $true
    )

    # Return one array ($MSGraphOutput) with all objects, supporting count past the default 999
    $URI = 'https://graph.microsoft.com/beta/users?$select=DisplayName,UserPrincipalName,Mail,UserType,AccountEnabled,signInActivity,AssignedLicenses,LastPasswordChangeDateTime,CompanyName,EmployeeId,Department,JobTitle,StreetAddress,City,State,Country,BusinessPhones,MobilePhone&$top=999'
    $MSGraphOutput = @()
    $nextLink = $null
    do {
        $uri = if ($nextLink) { $nextLink } else { $URI }
        $response = Invoke-MgGraphRequest -Uri $uri -Method GET
        $output = $response.Value
        $MSGraphOutput += $output
        $nextLink = $response.'@odata.nextLink'
    } until (-not $nextLink)

    if ( $OnlyActiveUsers ) {
        # If the scope is set to active users only, filter out accounts in CM_NonUserAccounts and those without a license

        try {
            $ID = (Get-MgGroup -Filter "DisplayName eq 'CM_NonUserAccounts'" -WarningAction Stop -ErrorAction Stop).Id
        }
        catch {
            Write-Error "Group missing from Azure AD: CM_NonUserAccounts. Please ensure the group is created and populated with the service/admin accounts that should be excluded from this report."
            exit
        }
        $URI = 'https://graph.microsoft.com/v1.0/groups/{0}/members/microsoft.graph.user?$select=UserPrincipalName' -f $ID
        $NonUserAccounts = (Invoke-MgGraphRequest -Uri $URI).Value.Values | Sort-Object # object with UPNs of members of CM_NonUserAccounts
        $MSGraphOutput = $MSGraphOutput | Where-Object { $_.UserPrincipalName -notin $NonUserAccounts } # removes $NonUserAccounts from $MSGraphOutput
        $MSGraphOutput = $MSGraphOutput | Where-Object { $_.AssignedLicenses -ne @() } # removes users that don't have licenses
    }


    $ClientName = (Get-CustomerContext).CustomerName

    # Empty array to store PSCustomObjects for later reporting
    $results = @()

    # Table for Microsoft SKU ID to friendly names
    $SKUsMappingTable = Get-Microsoft365LicensesMappingTable

    # All Teams numbers associated with users
    $allTeamsNumbers = Get-CsOnlineUser | Where-Object { $_.LineURI -notlike $null } | Select-Object DisplayName, UserPrincipalName, LineURI

    foreach ( $User in $MSGraphOutput) {

        $UPN = $User.UserPrincipalName
        $AADUser = Get-AzureADUser -ObjectId $UPN

        # Retrieve sign-in information
        if ($IncludeLastLogin) { 
            $LastLogin = $user.signInActivity.lastSignInDateTime
            if ($LastLogin) {
                $InactiveDays = (New-TimeSpan -Start $user.signInActivity.lastSignInDateTime).Days
            }
            else {
                $InactiveDays = "N/A" 
            }
        }

        # Assigned licenses. Pulls SKUs via Graph then converts to friendly name using the helper file
        $Licenses = @()
        foreach ($SKU in $User.AssignedLicenses.SKUID) {
            $Licenses += ($SKUsMappingTable | Where-Object { $_.GUID -eq "$SKU" } | Select-Object -expand DisplayName -Unique)
        }

        # Retrieve Teams number, if the user has one
        $TeamsNumber = $allTeamsNumbers | Where-Object { $_.UserPrincipalName -like $UPN } | Select-Object -ExpandProperty LineURI

        $userHashTable = @{
            DisplayName    = $User.DisplayName
            UPN            = $UPN
            Mail           = $User.Mail
            UserType       = $User.UserType
            AccountEnabled = $User.AccountEnabled
        }
        $optionalProperties = @(
            @{
                Name    = 'LastLogin'  
                Include = $IncludeLastLogin
                Value   = $LastLogin
            },
            @{
                Name    = 'InactiveDays'
                Include = $IncludeInactiveDays      	
                Value   = $InactiveDays
            },
            @{
                Name    = 'LastPasswordChange'
                Include = $IncludeLastPasswordChange      	
                Value   = $User.LastPasswordChangeDateTime
            },
            @{
                Name    = 'DaysSincePwChange'
                Include = $IncludeDaysSincePwChange    	
                Value   = (New-TimeSpan -Start $User.LastPasswordChangeDateTime).Days
            },
            @{
                Name    = 'Licenses'
                Include = $IncludeLicenses      	
                Value   = $Licenses -join "; "
            },
            @{
                Name    = 'CompanyName'
                Include = $IncludeCompanyName      	
                Value   = $User.CompanyName
            },
            @{
                Name    = 'Department'
                Include = $IncludeDepartment      	
                Value   = $User.Department
            },
            @{
                Name    = 'JobTitle'
                Include = $IncludeJobTitle      	
                Value   = $User.JobTitle
            },
            @{
                Name    = 'Manager'
                Include = $IncludeManager      	
                Value   = (Get-AzureADUserManager -ObjectId $AADUser.UserPrincipalName).DisplayName
            },
            @{
                Name    = 'EmployeeId'
                Include = $IncludeEmployeeId      	
                Value   = $User.employeeId
            },
            @{
                Name    = 'StreetAddress'
                Include = $IncludeStreetAddress      	
                Value   = $User.StreetAddress
            },
            @{
                Name    = 'City'
                Include = $IncludeCity      	
                Value   = $User.City
            },
            @{
                Name    = 'State'
                Include = $IncludeState      	
                Value   = $User.State
            },
            @{
                Name    = 'Country'
                Include = $IncludeCountry  	
                Value   = $User.Country
            },
            @{
                Name    = 'PhoneNumber'
                Include = $IncludePhoneNumber      	
                Value   = $AADUser.TelephoneNumber
            },
            @{
                Name    = 'TeamsNumber'
                Include = $IncludeTeamsNumber      	
                Value   = $TeamsNumber
            }
        )
        foreach ($property in $optionalProperties) {
            if ($property.Include) {
                $userHashTable.Add($property.Name, $property.Value)
            }
        }
        $results += $userHashTable
    }


    # This is a static array to ensure the properties are listed in the desired order. It is called in the results export
    $PropertyOrder = @(
        "DisplayName",
        "UPN",
        "Mail",
        "UserType",
        "AccountEnabled",
        "LastLogin",
        "InactiveDays",
        "LastPasswordChange",
        "DaysSincePwChange",
        "Licenses",
        "CompanyName",
        "Department",
        "JobTitle",
        "Manager",
        "EmployeeID",
        "StreetAddress",
        "City",
        "State",
        "Country",
        "PhoneNumber",
        "TeamsNumber"
    )


    $results | select-object $PropertyOrder | Out-SkyKickTableToHtmlReport -IncludePartnerLogo -ReportTitle "$($ClientName) M365 User Report" -ReportFooter "Report created using SkyKick Cloud Manager" -OutTo NewTab

}