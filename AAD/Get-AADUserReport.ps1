<#
TO-DO:
- Add full notes block
- Replace phone number and manager checks with MG Graph requests
#>

function Get-AADUserReport {

[SkyKickCommand(DisplayName = "Set Parameter Sections", Sections = { "Scope","Activity", "Licenses", "Company Information", "Location", "Phone numbers" })]
    param(
	
        [SkyKickParameter(
            DisplayName = "Only show active users",    
            Section = "Scope",
            DisplayOrder = 1,
            HintText = "Enabling this settings filters out all unlicensed users, and any members of this Azure AD group: CM_NonUserAccounts. Before enabling this, ensure that the group is present and populated with the service/admin accounts that should be excluded from this report."
        )]
        [Boolean]$OnlyActiveUsers = $false, # "user" here implies a human user

        [SkyKickParameter(
            DisplayName = "Include tenant license report",    
            Section = "Scope",
            DisplayOrder = 1,
            HintText = "Enabling this settings will generate a second report for licenses on the tenant."
        )]
        [Boolean]$IncludeM365LicenseReport = $false,

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
            HintText = "Display the user's manager."
        )]
        [Boolean]$IncludeManager = $false,

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
        [Boolean]$IncludePhoneNumber = $true,
		
		[SkyKickParameter(
            DisplayName = "Teams number",    
            Section = "Phone numbers",
            DisplayOrder = 16,
            HintText = "Display the user's Teams phone number."
        )]
        [Boolean]$IncludeTeamsNumber = $false
	)

    # Return one array ($MSGraphOutput) with all objects, supporting count past the default 999
    $Method = "GET"
    $Uri = 'https://graph.microsoft.com/beta/users?$select=DisplayName,UserPrincipalName,Mail,UserType,AccountEnabled,onPremisesSyncEnabled,signInActivity,AssignedLicenses,LastPasswordChangeDateTime,CompanyName,EmployeeId,Department,JobTitle,StreetAddress,City,State,Country,BusinessPhones,MobilePhone&$top=999'
    $MSGraphOutput = @()
    $nextLink = $null
    do {
        $Uri = if ($nextLink) { $nextLink } else { $Uri }
        $response = Invoke-MgGraphRequest -Uri $Uri -Method $Method
        $output = $response.Value
        $MSGraphOutput += $output
        $nextLink = $response.'@odata.nextLink'
    } until (-not $nextLink)

    # If the scope is set to active users only, filter out accounts in CM_NonUserAccounts and those without a license
    if ( $OnlyActiveUsers ) { 
        $ID = (Get-MgGroup -Filter "DisplayName eq 'CM_NonUserAccounts'" -WarningAction Stop -ErrorAction Stop).Id
        if ( $null -eq $ID ){
            Write-Output "Group missing from Azure AD: CM_NonUserAccounts. Please ensure the group is created and populated with the service/admin accounts that should be excluded from this report."
            exit
        }
        $URI = 'https://graph.microsoft.com/v1.0/groups/{0}/members/microsoft.graph.user?$select=UserPrincipalName' -f $ID # force string formatting, inserting $ID into {0}
        $NonUserAccounts = (Invoke-MgGraphRequest -Uri $URI).Value.Values | Sort-Object # object with UPNs of members of CM_NonUserAccounts
        $MSGraphOutput = $MSGraphOutput | Where-Object { $_.UserPrincipalName -notin $NonUserAccounts } # removes $NonUserAccounts from $MSGraphOutput
        $MSGraphOutput = $MSGraphOutput | Where-Object { $_.AssignedLicenses -ne @() } # removes users that don't have licenses
    }

    # Report variables
    $ClientName = (Get-CustomerContext).CustomerName
    $ReportTitle = "$($ClientName) AzureAD User Report" 
    $ReportFooter = "Report created using SkyKick Cloud Manager"

    # Empty array used to store output before exporting the report to HTML
    $results = @()

    # Table for Microsoft SKU ID to friendly names
    $SKUsMappingTable = Get-Microsoft365LicensesMappingTable

    # All Teams numbers associated with users
    if ( $IncludeTeamsNumber ) {
        $allTeamsNumbers = Get-CsOnlineUser | Where-Object { $_.LineURI -notlike $null } | Select-Object DisplayName, UserPrincipalName, LineURI
    }

    # Iterate through each user in the Graph output
    # Create a user hash table with basic properties and create a second hash table for all the other optional properties
    # Based on the options selected at runtime, add the selected optional properties to the original user hash table
    # Add the user hash table to the results array as a PSCustomObject for easy reporting
    foreach ( $User in $MSGraphOutput) {

        $UPN = $User.UserPrincipalName
        #$AADUser = Get-AzureADUser -ObjectId $UPN

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

        $Source = if ( $User.onPremisesSyncEnabled -eq $True ) { "On-premises" } else { "Cloud only" }

        $userHashTable = [ordered]@{
            DisplayName                 =   $User.DisplayName
            UPN                         =   $UPN
            Mail                        =   $User.Mail
            UserType                    =   $User.UserType
            AccountEnabled              =   $User.AccountEnabled
            Source                      =   $Source
        }
        $optionalProperties = @(
            @{
		        Name = 'LastLogin'  
		        Include = $IncludeLastLogin
		        Value = $LastLogin
	        },
            @{
                Name = 'InactiveDays'
                Include = $IncludeInactiveDays      	
                Value = $InactiveDays
            },
            @{
                Name = 'LastPasswordChange'
                Include = $IncludeLastPasswordChange      	
                Value = $User.LastPasswordChangeDateTime
            },
            @{
                Name = 'DaysSincePwChange'
                Include = $IncludeDaysSincePwChange    	
                Value = (New-TimeSpan -Start $User.LastPasswordChangeDateTime).Days
            },
            @{
                Name = 'Licenses'
                Include = $IncludeLicenses      	
                Value = $Licenses -join "; "
            },
            @{
                Name = 'CompanyName'
                Include = $IncludeCompanyName      	
                Value = $User.CompanyName
            },
            @{
                Name = 'Department'
                Include = $IncludeDepartment      	
                Value = $User.Department
            },
            @{
                Name = 'JobTitle'
                Include = $IncludeJobTitle      	
                Value = $User.JobTitle
            },
            @{
                Name = 'Manager'
                Include = $IncludeManager      	
                Value = if ($IncludeManager) {
                        (Get-MgUserManager -UserId $User.Id).AdditionalProperties.displayName
                    }
            },
            @{
                Name = 'EmployeeId'
                Include = $IncludeEmployeeId      	
                Value = $User.employeeId
            },
            @{
                Name = 'StreetAddress'
                Include = $IncludeStreetAddress      	
                Value = $User.StreetAddress
            },
            @{
                Name = 'City'
                Include = $IncludeCity      	
                Value = $User.City
            },
            @{
                Name = 'State'
                Include = $IncludeState      	
                Value = $User.State
            },
            @{
                Name = 'Country'
                Include = $IncludeCountry  	
                Value = $User.Country
            },
            @{
                Name = 'PhoneNumber'
                Include = $IncludePhoneNumber      	
                Value = $User.BusinessPhones
            },
            @{
                Name = 'TeamsNumber'
                Include = $IncludeTeamsNumber      	
                Value = $TeamsNumber
            }
        )
        foreach ($property in $optionalProperties) {
            if ($property.Include) {
                $userHashTable.Add($property.Name, $property.Value)
            }
        }
        $results += [PSCustomObject]$userHashTable
    }

    Out-SKSolutionReport -Content $results -ReportTitle $ReportTitle -ReportFooter $ReportFooter -SeparateReportFileForEachCustomer

    if ( $IncludeM365LicenseReport ) {
        Get-M365LicenseReport
    }


}