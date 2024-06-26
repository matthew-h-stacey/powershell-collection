<#
.SYNOPSIS
Script to create Active Directory user accounts.

.DESCRIPTION
This script combines a few functions to easily create new Active Directory user accounts in bulk using a CSV filled out with the required properties. 

.\Create-ADUser_template.csv - Template file for entering user properties into.

.NOTES
Author: Matt Stacey
Date:   June 26, 2024
#>

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

function Write-Log {
    
    <#
    .SYNOPSIS
    Log to a specific file/folder path with timestamps

    .EXAMPLE
    Write-Log -Message "[INFO] Attempting to do the thing" -LogFile C:\Scripts\MyScript.log
    Write-Log -Message "[INFO] Attempting to do the thing" -LogFile $LogFile 
    #>
    
    param (
        [Parameter(Mandatory = $true)]
        [String]
        $Message,

        [Parameter(Mandatory = $true)]
        [String]
        $LogFile
    )

    $timeStampMessage = "$((Get-Date -Format "MM/dd/yyyy HH:mm:ss")) $Message"
    Add-Content -Value $timeStampMessage -Path $LogFile

}

function Write-LogAndOutput {

    <#
    .SYNOPSIS
    A quick function to both log and send output to the console

    .EXAMPLE
    Write-LogAndOutput -Message "[INFO] Attempting to do the thing" -LogFile $logFile
    #>

    param (
        [Parameter(Mandatory = $True)]
        [String]
        $Message
    )

    Write-Log $Message -LogFile $logFile
    Write-Output $Message

}

function Get-CultureInfoList {

    <#
    .SYNOPSIS
    Use the [System.Globalization.CultureInfo] .NET class to build an array of culture information. The array can easily be searched for region or culture information

    .EXAMPLE
    $country = "United States"
    $cultureInfo = Get-CultureInfoList
    $countryCode = ($cultureInfo | Where-Object { $_.EnglishName -like $Country -or $_.TwoLetterISORegionName -like $Country }).TwoLetterISORegionName | Select-Object -Unique
    #>

    $allCultures = [System.Globalization.CultureInfo]::GetCultures([System.Globalization.CultureTypes]::SpecificCultures)
    $cultures = @()
    $allCultures | ForEach-Object {
        $displayName = $_.DisplayName.Split("(|)")
        $regionInfo = New-Object System.Globalization.RegionInfo $PsItem.name
        $cultures += [PSCustomObject]@{
            Name                   = $regionInfo.Name
            EnglishName            = $regionInfo.EnglishName
            TwoLetterISORegionName = $regionInfo.TwoLetterISORegionName
            GeoId                  = $regionInfo.GeoId
            ISOCurrencySymbol      = $regionInfo.ISOCurrencySymbol
            CurrencySymbol         = $regionInfo.CurrencySymbol
            LCID                   = $_.LCID
            Lang                   = $displayName[0].Trim()
            Country                = $displayName[1].Trim()
        }
    }
    $cultures
    
}

function Find-ADUser {

    <#
    .SYNOPSIS
    Searches for an ADUser with a UPN, DisplayName, or samAccount name. This allows the input to be more flexible than just using Get-ADUser

    .EXAMPLE
    Find-ADUser -Identity "John Smith"
    Find-ADUser -Identity jsmith@contoso.com -LogFile $logFile
    #>

    param (
        # Identity of the user to locate
        [Parameter(Mandatory = $true)]
        [String]
        $Identity,

        # Properties to retrieve for the user
        # Example 1: All properties - "*"
        # Example 2: Specific properties - "Department,Title,Manager"
        [Parameter(Mandatory = $false)]
        [String[]]
        $Properties,

        # Optionally log to a file
        [Parameter(Mandatory = $false)]
        [String]
        $LogFile
    )

    if ($Identity -match '@') {
        # Identity contains '@', consider it as UPN
        if ( $Properties ) {
            $user = Get-ADUser -Filter { UserPrincipalName -eq $Identity } -Properties $Properties
        } else {
            $user = Get-ADUser -Filter { UserPrincipalName -eq $Identity }
        }
        if ( $user -and $LogFile ) {
            Write-Log -Message "[INFO] Located user $Identity by UserPrincipalName" -LogFile $logFile
        }
    } else {
        # Try to get the user by samAccountName or DisplayName
        if ( $Properties ) {
            $user = Get-ADUser -Filter { samAccountName -eq $Identity -or DisplayName -eq $Identity } -Properties $Properties
        } else {
            $user = Get-ADUser -Filter { samAccountName -eq $Identity -or DisplayName -eq $Identity }
        }
        if ( $user -and $LogFile ) {
            Write-Log -Message "[INFO] Located user $Identity by UserPrincipalName" -LogFile $logFile
        }
    }
    if ( !$user ) {
        if ( $LogFile) {
            Write-LogAndOutput -Message "[ERROR] Unable to locate a user with provided input: $Identity. Please verify that you entered the correct samAccountName/DisplayName/UserPrincipalName of an existing user and try again."
        } else {
            Write-Output "[ERROR] Unable to locate a user with provided input: $Identity. Please verify that you entered the correct samAccountName/DisplayName/UserPrincipalName of an existing user and try again."
        }
        exit 1
    } elseif ( $user.Count -gt 1 ) {
        if ( $LogFile ) {
            Write-LogAndOutput -Message "[ERROR] More than one user located with the provided input: $Identity. Please try a more descriptive identifier and try again (ex: UserPrincipalName versus DisplayName)"
        } else {
            Write-Output "[ERROR] More than one user located with the provided input: $Identity. Please try a more descriptive identifier and try again (ex: UserPrincipalName versus DisplayName)"
        }
        exit 1
    }
    $user

}

function Copy-ADGroupMembership {

    <#
    .SYNOPSIS
    Copies the ADUser group membership from one user to another

    .EXAMPLE
    Copy-ADGroupMembership -Source jsmith@contoso.com -Destination aapple@contoso.com -LogFile $logFile
    #>

    param (
        # The source user to copy membership from
        [Parameter(Mandatory = $true)]
        [String]
        $Source,

        # The destination user to copy membership to
        [Parameter(Mandatory = $true)]
        [String]
        $Destination,

        # Optionally log to a file
        [Parameter(Mandatory = $false)]
        [String]
        $LogFile
    )

    if ( $LogFile ) {
        Write-Log -Message "[INFO] Matching Active Directory group membership from $Source to $Destination" -LogFile $logFile
    }
    $CurrentMembership = Get-ADUser -Identity $Destination -Properties MemberOf | Select-Object -ExpandProperty MemberOf
    $Groups = Get-ADUser -Identity $Source -Properties MemberOf | Select-Object -ExpandProperty MemberOf

    # Add the user to every group they are not already a member of
    foreach ( $Group in $Groups ) {
        if ( $Group -notin $CurrentMembership ) {
            try {
                Add-ADGroupMember -Identity $Group -Members $Destination
                if ( $LogFile ) {
                    Write-Log -Message "[INFO] Added $Destination to $Group" -LogFile $logFile
                }
            } catch {
                if ( $LogFile ) {
                    Write-Log -Message "[ERROR] Failed to add $Destination to group: $Group. Error: $($_.Exception.Message)" -LogFile $logFile
                } else {
                    Write-Output "[ERROR] Failed to add $Destination to group: $Group. Error: $($_.Exception.Message)"
                }
            }
        }
    }
}   

function Set-ADUserAliases {

    <#
    .SYNOPSIS
    Sets the PrimarySmtpAddress (SMTP:) and any aliases (smtp:) on an ADUser

    .EXAMPLE
    Set-ADUserAliases -Identity jsmith -PrimarySmtpAddress jsmith@contoso.com -Aliases @('john@contoso.com','john.smith@contoso.com')
    #>

    param (
        # Identity of the user to set the aliases on
        [Parameter(Mandatory = $true)]
        [String]
        $Identity,

        # User's primary email address (EmailAddress, SMTP:$EmailAddress)
        [Parameter(Mandatory = $true)]
        [String]
        $PrimarySmtpAddress,

        # User's alias (smtp:{$Alias})
        [Parameter(Mandatory = $true)]
        [String[]]
        $Aliases,

        # Optionally log to a file
        [Parameter(Mandatory = $false)]
        [String]
        $LogFile
    )

    if ( $LogFile ) {
        Write-Log -Message "[INFO] Starting to process aliases" -LogFile $logFile
    } 

    # Add the PrimarySmtpAddress (SMTP) to the proxyAddresses property
    $EmailSMTP = "SMTP:" + $PrimarySmtpAddress
    try {
        Set-ADUser -Identity $Identity -Add @{proxyAddresses = $EmailSMTP }
        Write-Log -Message "[INFO] Added proxyAddress value: $EmailSMTP" -LogFile $logFile
    } catch {
        Write-Log -Message "[ERROR] Failed to set proxyAddress value: $EmailSMTP. Error $($_.Exception.Message)" -LogFile $logFile
    }

    # Add any aliases (smtp) to the proxyAddresses property
    $Aliases | ForEach-Object { 
        $AliasSMTP = "smtp:" + $_
        try {
            Set-ADUser -Identity $Identity -Add @{proxyAddresses = $AliasSMTP }
            Write-Log -Message "[INFO] Added proxyAddress value: $AliasSMTP" -LogFile $logFile
        } catch {
            Write-Log -Message "[ERROR] Failed to set proxyAddress value: $AliasSMTP. Error $($_.Exception.Message)" -LogFile $logFile
        }
    }

}

function Export-UserProperties {
    param (
        # Identity of the user to export
        [Parameter(Mandatory = $true)]
        [String]
        $Identity,

        # Output directory
        [Parameter(Mandatory = $true)]
        [String]
        $OutputPath
    )

    $Properties = @(
        'GivenName',
        'Surname',
        'DisplayName',
        'SamAccountName',
        'UserPrincipalName',
        'PasswordExpired',
        'Enabled',
        'Mail',
        'ProxyAddresses',
        'Title',
        'Department',
        'Manager',
        'Company',
        'EmployeeID',
        'StreetAddress',
        'Office',
        'City',
        'State',
        'postalCode',
        'Country',
        'Mobile',
        'Fax',
        'HomePhone',
        'IpPhone',
        'Pager',
        'Description'
        'DistinguishedName',
        'MemberOf'
    )

    # Retrieve the user object for export
    $ADUser = Get-ADUser -Identity $Identity -Properties $Properties | Select-Object $Properties

    # Create an empty array for aliases. Pull proxy addresses that contain "smtp" and then combine into a single comma-separated string
    $Aliases = @()
    $ADUser.proxyAddresses | ForEach-Object {
        if ( $_ -cmatch "smtp") {
            $Aliases += $_.split(":")[1]
        }
    }
    $Aliases = $Aliases -join ", "

    # Create an empty array for groups. Grab only the group's display name, sort them, then combine into a single comma-separated string
    $Groups = @()
    $ADUser.MemberOf | ForEach-Object {
        $Groups += ((($_ -split ",", 2)[0]) -split "=")[1] 
    }
    $Groups = ($Groups | Sort-Object) -join ", " 

    # Create a PsCustomObject for the output and send it to OutputPath
    $Output = [PsCustomObject]@{
        FirstName             = $ADUser.GivenName
        LastName              = $ADUser.Surname
        DisplayName           = $ADUser.DisplayName
        SamAccountName        = $ADUser.SamAccountName
        UserPrincipalName     = $ADUser.UserPrincipalName
        ChangePasswordAtLogon = $ADUser.PasswordExpired
        Enabled               = $ADUser.Enabled
        Path                  = (($ADUser).DistinguishedName -split ",", 2)[1]
        EmailAddress          = $ADUser.Mail
        Aliases               = $Aliases
        Title                 = $ADUser.Title
        Department            = $ADUser.Department
        Manager               = $ADUser.Manager
        Company               = $ADUser.Company
        EmployeeID            = $ADUser.EmployeeID
        StreetAddress         = $ADUser.StreetAddress
        Office                = $ADUser.Office
        City                  = $ADUser.City
        State                 = $ADUser.State
        postalCode            = $ADUser.postalCode
        Country               = $ADUser.Country
        Mobile                = $ADUser.Mobile
        Fax                   = $ADUser.Fax
        HomePhone             = $ADUser.HomePhone
        IpPhone               = $ADUser.IpPhone
        Pager                 = $ADUser.Pager
        Description           = $ADUser.Description
        Groups                = $Groups
    }
    New-Folder -Path $OutputPath
    $Output | Out-File $OutputPath\$($Identity)_output.txt
    Write-Host "[INFO] Exported user property output to $($OutputPath)\$($Identity)_output.txt"

}

function Set-ADUserParams {
    ### Start constructing params with the base parameters from the input file
    $params = @{
        GivenName             = $FirstName
        Surname               = $LastName
        DisplayName           = $DisplayName
        Name                  = $DisplayName
        samAccountName        = $SamAccountName
        UserPrincipalName     = $UserPrincipalName
        ChangePasswordAtLogon = $ChangePasswordAtLogon
        Enabled               = $Enabled
        AccountPassword       = (Read-Host -AsSecureString -Prompt "Enter $($UserPrincipalName)'s password")
    }

    ### Start validating/updating params with optional parameters

    # Match the country input to a valid two-letter country code
    if ( $Country ) {
        $cultureInfo = Get-CultureInfoList
        $countryCode = ($cultureInfo | Where-Object { $_.EnglishName -like $Country -or $_.TwoLetterISORegionName -like $Country }).TwoLetterISORegionName | Select-Object -Unique
        if ( $countryCode ) {
            Write-Log -Message "[INFO] Matched provided country ($Country) to ISO 3166 two-letter region name: $countryCode" -LogFile $logFile
            $Country = $countryCode
        
        } else {
            Write-Output "[ERROR] Failed to match the provided country ($Country) to an ISO 3166 two-letter region name (example: Mexico -> MX). Please set the country to a valid two-letter region name and try again."
            Write-Log -Message "[ERROR] Failed to match the provided country ($Country) to an ISO 3166 two-letter region name (example: Mexico -> MX)" -LogFile $logFile
            exit 1
        }
    }

    # Add the optional properties that are a one-to-one property match
    $optionalProperties = @('EmailAddress', 'Title', 'Department', 'Company', 'EmployeeID', 'StreetAddress', 'Office', 'City', 'State', 'postalCode', 'Country', 'Mobile', 'Fax', 'HomePhone', 'Description')
    $optionalProperties | ForEach-Object {
        $Value = Get-Variable -Name $_ -ErrorAction SilentlyContinue -ValueOnly
        if ( $Value ) {
            $params.$_ = $Value
            Write-Log -Message "[INFO] Added optional parameter value: $_ - $Value" -LogFile $logFile
        }
    }
    # Add the user's manager
    if ( $Manager ) {
        Write-Log -Message "[INFO] Attempting to locate Active Directory user using input: $Manager" -LogFile $logFile
        if ( $Manager = (Find-ADUser -Identity $Manager -LogFile $logFile).SamAccountName ) {
            $params.Manager = $Manager
            Write-Log -Message "[INFO] Added manager parameter value: $Manager" -LogFile $logFile
        } else {
            Write-Log -Message "[WARNING] Unable to locate manager using input: $Manager. Manager will need to be set manually" -LogFile $logFile
            Write-Output "[WARNING] Unable to locate manager using input: $Manager. Manager will need to be set manually"
        }
    }

    # If a user was provided in the CopyUser section of the CSV, locate the user by UPN/SamAccountName/DisplayName and provide the user object as the Instance parameter
    # This will be used to copy ADUser group memberships and properties. Note: The new user will use the copied values (ex: City/State/etc.) UNLESS overriden by a different value in the corresponding optional field
    if ( $CopyUser ) {
        Write-Log -Message "[INFO] CopyUser parameter value was provided, attempting to locate $CopyUser" -LogFile $logFile
        $Properties = @(
            'City',
            'Company',
            'Country',
            'Department',
            'logonHours',
            'MemberOf',
            'PostalCode',
            'scriptPath',
            'State',
            'StreetAddress',
            'Title'
        )
        $script:UserToCopy = Find-ADUser -Identity $CopyUser -Properties $Properties -LogFile $logFile -ErrorAction Stop
        if ($UserToCopy) {
            $params.Instance = $UserToCopy # Instance is the parameter in Set-ADUser which take an existing ADUser object as input
            $Path = ($UserToCopy.DistinguishedName -split ",", 2)[1] # This pulls just the target OU path of the user being copied so the new user is created in the same OU
            $params.Path = $Path
            Write-Log -Message "[INFO] Added to CopyUser parameter value: $($UserToCopy.samAccountName)" -LogFile $logFile
            Write-Log -Message "[INFO] Added path parameter value from CopyUser: $Path" -LogFile $logFile
        } else {
            Write-Output "[ERROR] A user to copy (CopyUser) was provided in the input, but the user could not be found. Exiting script."
            Write-Log -Message "[ERROR] A user to copy (CopyUser) was provided in the input, but the user could not be found. Exiting script" -LogFile $logFile
            exit 1
        }
    }

    ### Add other user attributes that do not have a dedicated parameter in New-ADUser
    $otherAttributes = @{}

    # Add the user's pager and IP phone, if present
    if ( $Pager ) { $otherAttributes.Pager = $Pager }
    if ( $IpPhone ) { $otherAttributes.IpPhone = $IpPhone }
    if ( $otherAttributes.Keys.Count -gt 0 ) { $params.otherAttributes = $otherAttributes }

    $params
    
}

function Start-ADUserCreationWorkflow {
    <#
    .SYNOPSIS
    This function starts the execution of all related functions using the provided parameters for user creation
    #>

    [CmdletBinding()]
    param (
        # User's first name
        [Parameter(Mandatory = $true)]
        [String]
        $FirstName,

        # User's last name
        [Parameter(Mandatory = $true)]
        [String]
        $LastName,

        # User's display name. Often just "FirstName LastName" but could include an occupational title, etc.
        [Parameter(Mandatory = $true)]
        [String]
        $DisplayName,

        # User's username in pre-Windows 2000 NetBIOS format (ex: "jsmith")
        [Parameter(Mandatory = $true)]
        [String]
        $SamAccountName,

        # User's username in email-like format (ex: jsmith@contoso.com)
        [Parameter(Mandatory = $true)]
        [String]
        $UserPrincipalName,

        # Whether or not the user should be forced to change their password at next login. This should set to $true in most scenarios except cases where internal IT may do their own first-time setup under the user profile
        [Parameter(Mandatory = $true)]
        [Boolean]
        $ChangePasswordAtLogon,

        # Whether or not the user account should be enabled for login upon creation. Should be $true in most scenarios except some niche cases where an account may not be enabled until the user actually starts
        [Parameter(Mandatory = $true)]
        [Boolean]
        $Enabled,

        # To copy properties and group membership from an existing user, enter the source user's SamAccountName/UserPrincipalName/DisplayName
        [Parameter(Mandatory = $false)]
        [String]
        $CopyUser,

        # User's primary email address (EmailAddress, SMTP:$EmailAddress)
        [Parameter(Mandatory = $false)]
        [String]
        $EmailAddress,

        # User's alias (smtp:{$Alias}). Supports either a single string or multiple aliases separated by a semicolon (;)
        [Parameter(Mandatory = $false)]
        [String]
        $Alias,

        # User's title
        [Parameter(Mandatory = $false)]
        [String]
        $Title,

        # User's department
        [Parameter(Mandatory = $false)]
        [String]
        $Department,

        # User's manager
        [Parameter(Mandatory = $false)]
        [String]
        $Manager,

        # User's company
        [Parameter(Mandatory = $false)]
        [String]
        $Company,

        # User's employee ID
        [Parameter(Mandatory = $false)]
        [String]
        $EmployeeID,

        # User's street address
        [Parameter(Mandatory = $false)]
        [String]
        $StreetAddress,

        # User's office number (physicalDeliveryOfficeName or physical office name/number, not an office phone number)
        [Parameter(Mandatory = $false)]
        [String]
        $Office,

        # User's city
        [Parameter(Mandatory = $false)]
        [String]
        $City,

        # User's state
        [Parameter(Mandatory = $false)]
        [String]
        $State,

        # User's zip code. Note: Excel might drop leading zero's in the zip code if the cell isn't formatted properly
        [Parameter(Mandatory = $false)]
        [String]
        $postalCode,

        # Two-letter ISO 3166 region code (ex: US) that signifies the country where the user resides
        [Parameter(Mandatory = $false)]
        [string]
        $Country,

        # User's cellphone or mobile number
        [Parameter(Mandatory = $false)]
        [String]
        $Mobile,

        # User's fax number
        [Parameter(Mandatory = $false)]
        [String]
        $Fax,

        # User's home phone number
        [Parameter(Mandatory = $false)]
        [String]
        $HomePhone,

        # User's IP phone number
        [Parameter(Mandatory = $false)]
        [String]
        $IpPhone,

        # User's pager phone number
        [Parameter(Mandatory = $false)]
        [String]
        $Pager,

        # Optional description for the Active Directory user object
        [Parameter(Mandatory = $false)]
        [String]
        $Description
    
    )

    ### Logging
    $logFile = "C:\Scripts\Create-ADUser_$($SamAccountName).log"
    Write-Output "Log file: $logfile"
    Write-Log -Message "[START] Starting processing for user: $UserPrincipalName" -LogFile $logFile

    # Construct $params and attempt to create the user account
    $params = Set-ADUserParams
    try {
        Write-LogAndOutput -Message "[INFO] Attempting to create new user: $($params.samAccountName)"
        New-ADUser @params
        Write-LogAndOutput "[INFO] Successfully created new user"
    } catch [System.UnauthorizedAccessException] {
        Write-LogAndOutput "[ERROR] Error encountered while attempting to create $($params.Name): $($_.Exception.Message). Make sure you are running the script as Administrator and try again."
        exit 1
    } catch [Microsoft.ActiveDirectory.Management.ADPasswordComplexityException] {
        Write-LogAndOutput "[WARNING] The password entered for $($params.Name) does not meet the length, complexity, or history requirement of the domain.The user was created successfully but the password needs to be reset and then the account can be enabled."
    } catch {
        Write-LogAndOutput "[ERROR] Failed to create $($params.Name). Error message: $($_.Exception.Message)"
        exit 1
    }

    ### Post user creation changes

    # Set the user's PrimarySmtpAddress and alias
    if ( $Alias ) {
        # Create an array from $Aliases, splitting by a semicolon
        $Aliases = $Alias.Split(";")

        # Run the function to set both the PrimarySmtpAddress and any aliases
        Set-ADUserAliases -Identity $SamAccountName -PrimarySmtpAddress $EmailAddress -Aliases $Aliases -LogFile $logFile

    }

    # Copy group membership
    if ( $CopyUser ) {
        Copy-ADGroupMembership -Source $UserToCopy.SamAccountName -Destination $params['SamAccountName'] -LogFile $logFile        
    }

    Export-UserProperties -Identity $SamAccountName -OutputPath C:\Scripts
    Write-Log -Message "[FINISH] User creation script has finished for $UserPrincipalName" -LogFile $logFile

}

# The default path to pull the CSV from without needing to specify the path. Otherwise, the user is required to provide the full folder/file path of the CSV
$defaultCsvPath = ".\Create-ADUser_template.csv"

# If CSV switch is used, first try to locate the file at its default path ($defaultCsvPath)
# If it does exist at the default path, ask the user for the location
# Once found, loop through each of the users and run the function to start the creation workflow
if ( Test-Path $defaultCsvPath) {
    $csvPath = $defaultCsvPath
} else {
    $csvPath = Read-Host "Please type the folder/file path for the CSV file for bulk creation of Active Directory users (example: C:\Scripts\Create-ADUser_template.csv)"
    $fileExists = $false
    while ( $fileExists -eq $false) {
        if ( Test-Path $csvPath ) {
            $fileExists = $true
        } else {
            $csvPath = Read-Host "File not found. Please try again"
        }
    }
    Write-Output "[CSV] Found CSV file for bulk user creation: $csvPath. Proceeding ..."
    $users = Import-Csv -Path $csvPath
foreach ($user in $users) {
        # Initialize an empty hashtable for parameters
        $params = @{}
        # Mandatory parameters
        $params.FirstName = $user.FirstName
        $params.LastName = $user.LastName
        $params.DisplayName = $user.DisplayName
        $params.SamAccountName = $user.SamAccountName
        $params.UserPrincipalName = $user.UserPrincipalName
        $params.ChangePasswordAtLogon = [System.Convert]::ToBoolean($user.ChangePasswordAtLogon)
        $params.Enabled = [System.Convert]::ToBoolean($user.Enabled)
        # Loop through $optionalParams and add the properties to $params if present in $user
        $optionalParams = @('CopyUser', 'Email', 'Alias', 'Title', 'Department', 'Manager', 'Company', 'EmployeeID', 'StreetAddress', 'Office', 'City', 'State', 'postalCode', 'Country', 'Mobile', 'Fax', 'HomePhone', 'IpPhone', 'Pager', 'Description')
        foreach ($paramName in $optionalParams) {
            if ($user.$paramName) {
                $params.$paramName = $user.$paramName
            }
        }
        # Remove any trailing spaces from the input
        $trimmedParams = @{}
        foreach ($key in $params.Keys) {
            if ( $params[$key] -is [String]) {
                $trimmedParams[$key] = $params[$key] -replace '\s+$'
            } else {
                $trimmedParams[$key] = $params[$key]
            }
        }
        Start-ADUserCreationWorkflow @trimmedParams
    }
}