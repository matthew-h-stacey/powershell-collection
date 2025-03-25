<#
TO-DO:
- Add full notes block
- Add first and last name
- Implement option for all users vs. a specific entra group
- Finish implementing password info. Pw expired not functioning, test on AD and Entra-only users
#>

function Get-EntraUserReport {

    [SkyKickCommand(DisplayName = "Set Parameter Sections", Sections = { "Scope", "Optional Parameters" })]
    param(

        [SkyKickParameter(
            DisplayName = "All users",
            Section = "Scope",
            DisplayOrder = 1
        )]
        [boolean]
        $AllUsers = $true,

        [SkyKickConditionalVisibility({
                param($AllUsers)
                return (
                    ($AllUsers -eq $false)
                )
            },
            IsMandatoryWhenVisible = $true
        )]
        [ArgumentCompleter({
                [PSTypeName("Group")]
                param ($CommandName, $ParameterName, $WordToComplete, $CommandAst, $FakeBoundParameters)
                Get-MgGroup -All | Sort-Object DisplayName | ForEach-Object {
                    New-SkyKickCompletionResult -Value $_.Id -DisplayName $_.DisplayName
                }
            })] 
        [Parameter(Mandatory = $false)]
        [SkyKickParameter(
            DisplayName = "Entra Group",
            Section = "Scope",
            DisplayOrder = 2
        )] 
        [string] $GroupId,

        [SkyKickParameter(
            DisplayName = "Exclude members of CM_NonUserAccounts",    
            Section = "Scope",
            DisplayOrder = 3,
            HintText = "Enabling this settings filters out all unlicensed users, and any members of this Azure AD group: CM_NonUserAccounts. Before enabling this, ensure that the group is present and populated with the service/admin accounts that should be excluded from this report."
        )]
        [Boolean]$IncludeOnlyActiveUsers = $false, # "user" here implies a human user

        [SkyKickParameter(
            DisplayName = "Directory info",    
            Section = "Optional Parameters",
            DisplayOrder = 1,
            HintText = "Display user type, account enablement, and source (cloud-only or synced)"
        )]
        [Boolean]$IncludeDirectoryInfo = $true,

        [SkyKickParameter(
            DisplayName = "Mailbox info",    
            Section = "Optional Parameters",
            DisplayOrder = 1,
            HintText = "Display email address, email aliases, and alias property"
        )]
        [Boolean]$IncludeMailboxInfo = $true,

        [SkyKickParameter(
            DisplayName = "Employment and company info",    
            Section = "Optional Parameters",
            DisplayOrder = 1,
            HintText = "Include department, job title, company name, employee type, etc."
        )]
        [Boolean]$IncludeEmploymentCompanyInfo = $true,

        [SkyKickParameter(
            DisplayName = "Manager",    
            Section = "Optional Parameters",
            DisplayOrder = 2,
            HintText = "Display the user's manager."
        )]
        [Boolean]$IncludeManager = $false,

        [SkyKickParameter(
            DisplayName = "Contact and address info",    
            Section = "Optional Parameters",
            DisplayOrder = 3,
            HintText = "Include address, city, state, phone numbers, etc."
        )]
        [Boolean]$IncludeContactInfo = $true,

        [SkyKickParameter(
            DisplayName = "Assigned licenses",    
            Section = "Optional Parameters",
            DisplayOrder = 4,
            HintText = "Display the licenses assigned to the user."
        )]
        [Boolean]$IncludeLicenses = $true,        

        [SkyKickParameter(
            DisplayName = "Login activity",
            Section = "Optional Parameters",
            DisplayOrder = 5,
            HintText = "Display user's last login timestamp and days since login."
        )]
        [Boolean]$IncludeLoginActivity = $true,

        [SkyKickParameter(
            DisplayName = "Password info",
            Section = "Optional Parameters",
            DisplayOrder = 6,
            HintText = "Display last password change, password expiration, etc."
        )]
        [Boolean]$IncludePasswordInfo = $true,

        [SkyKickParameter(
            DisplayName = "Entra roles",
            Section = "Optional Parameters",
            DisplayOrder = 7,
            HintText = "Display assigned Entra roles"
        )]
        [Boolean]$IncludeEntraRoles = $true,

        [SkyKickParameter(
            DisplayName = "Tenant license report",    
            Section = "Optional Parameters",
            DisplayOrder = 8,
            HintText = "Enabling this settings will generate a second report for all licenses on the tenant."
        )]
        [Boolean]$IncludeM365LicenseReport = $false
    )

    ### PROPERTIES
    ## Create initial properties array
    $properties = @(
        # Identity
        "id"
        "displayName"
        "userPrincipalName"
        "mail"
        "userType"
        "accountEnabled"
        "onPremisesSyncEnabled"
    
        # Employment/company
        "companyName"
        "employeeId"
        "department"
        "jobTitle"
        "employeeType"
        "employeeHireDate"

        # Licensing
        "assignedLicenses"
        
        # Location and contact info
        "streetAddress"
        "city"
        "state"
        "country"
        "businessPhones"
        "mobilePhone"

        # Activity
        "createdDateTime"
        "lastPasswordChangeDateTime"
    )
    # Store date to use for both a script timestamp and password info (optional)
    $today = Get-Date
    ## Optional: signInActivity - Entra Premium licensing is required to retrieve signInActivity
    if ( $IncludeLoginActivity ) {
        $entraLicense = Get-AzureADLicense
        if ( $entraLicense.Premium -eq $true ) {
            $properties += "signInActivity"
        } 
    }
    ## Optional: password information
    if ( $IncludePasswordInfo ) {
        $properties += "passwordPolicies"
        $pwExpirationPolicy = Get-MgDomainPasswordExpiration
        
    }

    ### RETRIEVE USERS/GOUPS VIA GRAPH
    ## Construct the URI with support for 1000+ objects
    $batchRequired = $false
    if ( $AllUsers ) {
        # All properties are available via the /users endpoint
        $uri = 'https://graph.microsoft.com/beta/users?$select=' + ($properties -join ',') + '&$top=999'
    } elseif ( $GroupId ) {
        # Batching will be required to pull properties for all users. Start by retrieving the users of the desired group
        $uri = "https://graph.microsoft.com/beta/groups/$GroupId/members?`$top=999"
        $batchRequired = $true
    }
    $graphResponse = @()
    $nextLink = $null
    do {
        $uri = if ($nextLink) { $nextLink } else { $uri }
        $response = try {
            Invoke-MgGraphRequest -Uri $uri -Method GET
        } catch {
            Write-Error "Failed to retrieve users via MS Graph. Error: $($_.Exception.Message)"
            exit 1
        }
        $output = $response.Value
        $graphResponse += $output
        $nextLink = $response.'@odata.nextLink'
    } until (-not $nextLink)
    ## If batching is required, group users into batches of 20 to send to the batch endpoint
    ## This process creates a single  
    if ( $batchRequired ) {
        # Take $graphResponse and create batches of HTTP calls using the URL template, replacing "{Id}" with the user ID
        $urlTemplate = "users/{Id}?`$select=$($properties -join ',')"
        $users = Invoke-GraphBatchRequest -InputObjects $graphResponse -ApiQuery $urlTemplate -Placeholder "Id"
    } else {
        $users = $graphResponse
    }
    
    if ( -not $users ) {
        Write-Output "[INFO] No users found to report on"
        exit
    }
    
    ### OPTIONAL: ACTIVE USERS FILTER
    ## Remove users from the output that are either members of Entra security group
    ## "CM_NonUserAccounts" or those without a license
    if ( $IncludeOnlyActiveUsers ) { 
        $excludedGroupID = (Get-MgGroup -Filter "DisplayName eq 'CM_NonUserAccounts'" -WarningAction Stop -ErrorAction Stop).Id
        if ( $null -eq $excludedGroupID ) {
            Write-Output "Group missing from Azure AD: CM_NonUserAccounts. Please ensure the group is created and populated with the service/admin accounts that should be excluded from this report."
            exit
        }
        $uri = 'https://graph.microsoft.com/v1.0/groups/{0}/members/microsoft.graph.user?$select=UserPrincipalName' -f $excludedGroupID # force string formatting, inserting $excludedGroupID into {0}
        $nonUserAccounts = (Invoke-MgGraphRequest -Uri $uri).Value.Values | Sort-Object # object with UPNs of members of CM_NonUserAccounts
        $users = $users | Where-Object { $_.UserPrincipalName -notin $nonUserAccounts } # removes non-userAccounts from the Graph response
        $users = $users | Where-Object { $_.AssignedLicenses -ne @() } # removes users that don't have licenses
    }

    ### REPORT VARIABLES
    $customerContext = Get-CustomerContext
    $clientName = $customerContext.CustomerName
    $reportTitle = "$($clientName) Entra ID User Report" 
    $reportFooter = "Report created using SkyKick Cloud Manager"
    
    ### REPORT LOOKUPS
    ## Table for Microsoft SKU ID to friendly names
    $skusMappingTable = Get-Microsoft365LicensesMappingTable
    ## All Teams numbers associated with users
    $allTeamsNumbers = Get-CsOnlineUser | Where-Object { $_.LineURI -notlike $null } | Select-Object DisplayName, UserPrincipalName, LineURI
    $teamsNumLookup = @{}
    foreach ($number in $allTeamsNumbers) {
        $teamsNumLookup[$number.UserPrincipalName] = $number 
    }
    ## All mailboxes where the UPN is contained in the MS Graph output
    $mailboxes = Get-EXOMailbox -ResultSize Unlimited | Where-Object { $_.UserPrincipalName -in $graphResponse.UserPrincipalName }
    # Create a mailbox lookup hash table for all mailboxes
    $mailboxLookup = @{}
    foreach ($mb in $mailboxes) {
        $mailboxLookup[$mb.UserPrincipalName] = $mb
    }
    ## Directory roles and membership
    if ( $IncludeEntraRoles ) {
        $allRoleMemberships = @()
        Get-MgDirectoryRole | ForEach-Object {
            $member = Get-MgDirectoryRoleMember -DirectoryRoleId $_.Id
            $allRoleMemberships += [pscustomobject]@{
                Role   = $_.DisplayName
                Member = @($member.AdditionalProperties.userPrincipalName)
            }
        }
    }    

    # Empty array used to store output before exporting the report to HTML
    $results = [System.Collections.Generic.List[System.Object]]::new()

    ### FOREACH PROCESSING START
    <#
    - Iterate through each user in the Graph output
    - Create a user hash table with basic properties and create a second hash table for all the other optional properties
    - Based on the options selected at runtime, add the selected optional properties to the original user hash table
    - Add the user hash table to the results array as a PSCustomObject for easy reporting
    #>
    foreach ( $user in $users) {
        $upn = $user.UserPrincipalName
        ## Retrieve sign-in information
        if ($IncludeLoginActivity) { 
            $lastLogin = $user.signInActivity.lastSignInDateTime
            if ($lastLogin) {
                $inactiveDays = (New-TimeSpan -Start $user.signInActivity.lastSignInDateTime).Days
            } else {
                $inactiveDays = "N/A" 
            }
        }
        ## Retrieve password information
        if ( $IncludePasswordInfo ) {
            # Both user types
            $pwLastChanged = $user.lastPasswordChangeDateTime
            $pwNeverExpires = $user.passwordPolicies -eq "DisablePasswordExpiration"
            if ( -not $pwNeverExpires ) {
                if ( $user.onPremisesSyncEnabled -eq $true) {
                    # AD synced
                    $pwExpired = "Check AD"
                } else {
                    # Cloud-only
                    $pwMaxAge = $pwExpirationPolicy.PasswordMaxAge
                    if ( $null -eq $pwMaxAge ) {
                        $pwMaxAge = "Infinite"
                    } else {
                        $pwExpiresOn = $pwLastChanged.AddDays($pwMaxAge)
                        $pwExpired = (New-TimeSpan -Start $today -End $pwExpiresOn) -lt 1
                    }
                }
            }
        }
        ## Assigned licenses. Pulls SKUs via Graph then converts to friendly name using the helper file
        $licenses = @()
        foreach ($sku in $user.AssignedLicenses.SKUID) {
            $licenses += ($skusMappingTable | Where-Object { $_.GUID -eq "$sku" } | Select-Object -expand DisplayName -Unique)
        }
        ## Initial hash table
        $userHashTable = [ordered]@{
            DisplayName       = $user.DisplayName
            UserPrincipalName = $upn
        }
        ## Manager
        if ( $IncludeManager ) {
            try {
                $manager = Get-MgUserManager -UserId $User.Id -ErrorAction Stop
            } catch {
                # User does not have a manager
                $null
            }
        }
        
        <### Source
        if ( $IncludeDirectoryInfo ) {
            $source = if ( $user.onPremisesSyncEnabled -eq $True ) { "On-premises" } else { "Cloud only" }
        }
        #>

        ## Optional properties
        # Create a hash table with all optional properties and their computed values
        # Then, for-each loop through them conditionally add the object to the output list object
        $optionalProperties = @(
            @{
                Name    = 'UserType'  
                Include = $IncludeDirectoryInfo
                Value   = $user.UserType
            },
            @{
                Name    = 'Enabled'  
                Include = $IncludeDirectoryInfo
                Value   = $user.AccountEnabled
            },
            @{
                Name    = 'Source'  
                Include = $IncludeDirectoryInfo
                Value   = if ( $user.onPremisesSyncEnabled -eq $True ) { "On-premises" } else { "Cloud only" }
            },
            @{
                Name    = 'Mail'  
                Include = $IncludeMailboxInfo
                Value   = $user.Mail
            },
            @{
                Name    = 'SharedMailbox'  
                Include = $IncludeMailboxInfo
                Value   = $mailboxLookup[$upn].RecipientTypeDetails -eq 'SharedMailbox'
            },
            @{
                Name    = 'MailboxName'  
                Include = $IncludeMailboxInfo
                Value   = $mailboxLookup[$upn].Alias
            },
            @{
                Name    = 'MailboxAliases'  
                Include = $IncludeMailboxInfo
                Value   = ($mailboxLookup[$upn].EmailAddresses | Where-Object { $_ -match '^smtp:' } | ForEach-Object { $_ -split ':' | Select-Object -Last 1 }) -join "; "
            },
            @{
                Name    = 'LastLogin'  
                Include = $IncludeLoginActivity
                Value   = $lastLogin
            },
            @{
                Name    = 'InactiveDays'
                Include = $IncludeLoginActivity      	
                Value   = $inactiveDays
            },
            @{
                Name    = 'PasswordNeverExpires'
                Include = $IncludePasswordInfo    	
                Value   = $pwNeverExpires
            },
            @{
                Name    = 'PasswordExpired'
                Include = $IncludePasswordInfo    	
                Value   = $pwExpired
            },
            @{
                Name    = 'LastPasswordChange'
                Include = $IncludePasswordInfo    	
                Value   = $pwLastChanged
            },
            @{
                Name    = 'PasswordExpiresOn'
                Include = $IncludePasswordInfo    	
                Value   = $pwExpiresOn 
            },
            @{
                Name    = 'DaysSincePwChange'
                Include = $IncludePasswordInfo    	
                Value   = if ( $user.LastPasswordChangeDateTime ) { 
                    (New-TimeSpan -Start $user.LastPasswordChangeDateTime).Days
                } else { "N/A" }
            },
            @{
                Name    = 'Licenses'
                Include = $IncludeLicenses      	
                Value   = $licenses -join "; "
            },
            @{
                Name    = 'CompanyName'
                Include = $IncludeEmploymentCompanyInfo      	
                Value   = $user.CompanyName
            },
            @{
                Name    = 'Department'
                Include = $IncludeEmploymentCompanyInfo      	
                Value   = $user.Department
            },
            @{
                Name    = 'JobTitle'
                Include = $IncludeEmploymentCompanyInfo      	
                Value   = $user.JobTitle
            },
            @{
                Name    = 'ManagerName'
                Include = $IncludeManager      	
                Value   = if ( $null -ne $manager ) {
                    $manager.AdditionalProperties.displayName
                }
            },
            @{
                Name    = 'ManagerEmail'
                Include = $IncludeManager      	
                Value   = if ( $null -ne $manager ) {
                    $manager.AdditionalProperties.mail
                }
            },
            @{
                Name    = 'EmployeeId'
                Include = $IncludeEmploymentCompanyInfo
                Value   = $User.employeeId
            },
            @{
                Name    = 'EmployeeType'
                Include = $IncludeEmploymentCompanyInfo
                Value   = $User.EmployeeType
            },
            @{
                Name    = 'HireDate'
                Include = $IncludeEmploymentCompanyInfo
                Value   = if ( $User.EmployeeHireDate ) {
                    (Get-Date ($User.EmployeeHireDate) -Format "MM/dd/yyyy")
                }                
            },
            @{
                Name    = 'Created'
                Include = $IncludeEmploymentCompanyInfo
                Value   = $User.createdDateTime
            },
            @{
                Name    = 'StreetAddress'
                Include = $IncludeContactInfo      	
                Value   = $user.StreetAddress
            },
            @{
                Name    = 'City'
                Include = $IncludeContactInfo      	
                Value   = $user.City
            },
            @{
                Name    = 'State'
                Include = $IncludeContactInfo      	
                Value   = $user.State
            },
            @{
                Name    = 'Country'
                Include = $IncludeContactInfo  	
                Value   = $user.Country
            },
            @{
                Name    = 'Roles'
                Include = $IncludeEntraRoles  	
                Value   = ($allRoleMemberships | Where-Object { $_.Member -like $upn } | Sort-Object | Select-Object -ExpandProperty role) -join ", "
            },
            @{
                Name    = 'BusinessPhones'
                Include = $IncludeContactInfo   	
                Value   = $user.BusinessPhones
            },
            @{
                Name    = 'TeamsNumber'
                Include = $IncludeContactInfo   	
                Value   = $teamsNumLookup[$upn].LineUri
            }
        )
        foreach ($property in $optionalProperties) {
            if ($property.Include) {
                $userHashTable.Add($property.Name, $property.Value)
            }
        }
        $results.Add([PSCustomObject]$userHashTable)
    }

    ### OUTPUT REPORT
    $results = $results | Sort-Object DisplayName
    Out-SKSolutionReport -Content $results -ReportTitle $reportTitle -ReportFooter $reportFooter -SeparateReportFileForEachCustomer
    if ( $IncludeM365LicenseReport ) {
        Get-M365LicenseReportBeta -UnderallocatedSKUsOnly $false -Clients $customerContext -Scope 'All' 
    }
    
    ### OUTPUT TIMESTAMP
    $end = Get-Date
    $startFormatted = $start.ToString("yyyy-MM-dd HH:mm:ss")
    $endFormatted = $end.ToString("yyyy-MM-dd HH:mm:ss")
    $duration = New-TimeSpan -Start $today -End $end
    Write-Host "Script started at $startFormatted"
    if ($duration.TotalMinutes -lt 1) {
        Write-Host "Script finished at $endFormatted. Duration: $($duration.Seconds) seconds."
    } else {
        Write-Host "Script finished at $endFormatted. Duration: $($duration.Minutes) minutes and $($duration.Seconds) seconds."
    }

}