<#
.SYNOPSIS
Script to create Active Directory user accounts.

.DESCRIPTION
This script combines a few functions to to easily create new Active Directory user accounts in bulk, with the primary method being a CSV filled out with the required properties.
The CSV is imported and then run against a foreach loop to pass all the inputted information to the proper parameters.

.\Create-ADUser_execute.ps1 - Helpful pre-created execution script to import a CSV and run the script
.\Create-ADUser_template.csv - Template file for entering user properties into

.PARAMETER (ALL)
Each parameter should be fairly self explanatory as they correlate to an Active Directory user object. Each parameter below has a note preceding it which explains what it is.
Given the amount of parameters in this script it would be excessive to list a description for each of them separately in this notes block.

.NOTES
Author: Matt Stacey
Date:   December 27, 2023

To do:
[ ] Add additional fields: Description, Home phone, Pager phone, IP phone, EmployeeID
[ ] Find cleaner way to output and log instead of duplicate lines

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

    # User's office number (physicalDeliveryOfficeName or physical office name/number, not an office phone number)
    [Parameter(Mandatory = $false)]
    [String]
    $Office,

    # User's street address
    [Parameter(Mandatory = $false)]
    [String]
    $StreetAddress,

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
    $Company
)
function New-Folder {
        Param([Parameter(Mandatory = $True)][String] $Path)
        if (-not (Test-Path -LiteralPath $Path)) {
            try {
                New-Item -Path $Path -ItemType Directory -ErrorAction Stop | Out-Null
                Write-Host "Created folder: $Path"
            }
            catch {
                Write-Error -Message "Unable to create directory '$Path'. Error was: $_" -ErrorAction Stop
            }
        }
        else {
            # Path already exists, continue"
        }

    }
function Write-Log {
    param (
        [String]
        $LogString
    )
    Add-Content -Path $LogFile -Value "$(Get-Date -Format 'MM/dd/yyyy HH:mm:ss') $LogString"
}
function Get-CultureInfoList {

    $allCultures = [System.Globalization.CultureInfo]::GetCultures([System.Globalization.CultureTypes]::SpecificCultures)
    $cultures = @()
    $allCultures | ForEach-Object {
        $dn = $_.DisplayName.Split("(|)");
        $regionInfo = New-Object System.Globalization.RegionInfo $PsItem.name;
        $cultures += [PSCustomObject]@{
            Name                   = $regionInfo.Name;
            EnglishName            = $regionInfo.EnglishName;
            TwoLetterISORegionName = $regionInfo.TwoLetterISORegionName;
            GeoId                  = $regionInfo.GeoId;
            ISOCurrencySymbol      = $regionInfo.ISOCurrencySymbol;
            CurrencySymbol         = $regionInfo.CurrencySymbol;
            LCID                   = $_.LCID;
            Lang                   = $dn[0].Trim();
            Country                = $dn[1].Trim();
        }
    }

    return $cultures
    
}
function Find-ADUser {
    # Searches for an ADUser with a UPN, DisplayName, or samAccount name. This allows the input to be more flexible than just using Get-ADUser

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
        $Properties
    )

    if ($Identity -match '@') {
        # Identity contains '@', consider it as UPN
        if ( $Properties ) {
            $User = Get-ADUser -Filter { UserPrincipalName -eq $Identity } -Properties $Properties
            Write-Log "[INFO] Located user $Identity by UserPrincipalName"
        }
        else {
            $User = Get-ADUser -Filter { UserPrincipalName -eq $Identity }
            Write-Log "[INFO] Located user $Identity by UserPrincipalName"
        }
    }
    else {
        # Try to get the user by samAccountName or DisplayName
        if ( $Properties ) {
            $User = Get-ADUser -Filter { samAccountName -eq $Identity -or DisplayName -eq $Identity } -Properties $Properties
            Write-Log "[INFO] Located user $Identity by samAccountName/DisplayName"
        }
        else {
            $User = Get-ADUser -Filter { samAccountName -eq $Identity -or DisplayName -eq $Identity }
            Write-Log "[INFO] Located user $Identity by samAccountName/DisplayName"
        }
    }

    if ( !$User ) {
        Write-Output "[ERROR] Unable to locate a user with provided input: $Identity. Please verify that you entered the correct samAccountName/DisplayName/UserPrincipalName of an existing user and try again."
        Write-Log "[ERROR] Unable to locate a user with provided input: $Identity. Please verify that you entered the correct samAccountName/DisplayName/UserPrincipalName of an existing user and try again."
        exit 1
    }
    elseif ( $User.Count -gt 1 ) {
        Write-Output "[ERROR] More than one user located with the provided input: $Identity. Please try a more descriptive identifier and try again (ex: UserPrincipalName versus DisplayName)"
        Write-Log "[ERROR] More than one user located with the provided input: $Identity. Please try a more descriptive identifier and try again (ex: UserPrincipalName versus DisplayName)"
        exit 1
    }
    return $User

}
function Copy-ADGroupMembership {
    # Copies the ADUser group membership from one user to another
    # Example: Copy-ADGroupMembership -Source jsmith@contoso.com -Destination aapple@contoso.com

    param (
        # The source user to copy membership from
        [Parameter(Mandatory = $true)]
        [String]
        $Source,

        # The destination user to copy membership to
        [Parameter(Mandatory = $true)]
        [String]
        $Destination
    )

    # Copies AD group membership from source user to destination user
    Write-Output "[INFO] Matching Active Directory group membership from $Source to $Destination"
    Write-Log "[INFO] Matching Active Directory group membership from $Source to $Destination"
    $CurrentMembership = Get-ADUser -Identity $Destination -Properties MemberOf | Select-Object -ExpandProperty MemberOf
    $Groups = Get-ADUser -Identity $Source -Properties MemberOf | Select-Object -ExpandProperty MemberOf

    foreach ( $Group in $Groups ) {
        try {
            if ( $Group -notin $CurrentMembership ) {
                Add-ADGroupMember -Identity $Group -Members $Destination
                Write-Log "[INFO] Added $Destination to $Group"
            }
            else {
                # Skip - User is already a member
            }
        }
        catch {
            Write-Log "[ERROR] Failed to add $Destination to group: $Group. Error: $($_.Exception.Message)"
        }
    
    }
}   
function Set-ADUserAliases {
    # Sets the PrimarySmtpAddress and any aliases on an ADUser
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
        $Aliases
    )

    Write-Log "[INFO] Starting to process aliases"

    # Add the PrimarySmtpAddress (SMTP) to the proxyAddresses property
    $EmailSMTP = "SMTP:" + $PrimarySmtpAddress
    try {
        Set-ADUser -Identity $Identity -Add @{proxyAddresses = $EmailSMTP }
        Write-Log "[INFO] Added proxyAddress value: $EmailSMTP"
    }
    catch {
        Write-Log "[ERROR] Failed to set proxyAddress value: $EmailSMTP. Error $($_.Exception.Message)"
    }

    # Add any aliases (smtp) to the proxyAddresses property
    $Aliases | ForEach-Object { 
        $AliasSMTP = "smtp:" + $_
        try {
            Set-ADUser -Identity $Identity -Add @{proxyAddresses = $AliasSMTP }
            Write-Log "[INFO] Added proxyAddress value: $AliasSMTP"
        }
        catch {
            Write-Log "[ERROR] Failed to set proxyAddress value: $AliasSMTP. Error $($_.Exception.Message)"
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
        'Office',
        'StreetAddress',
        'City',
        'State',
        'postalCode',
        'Country',
        'Mobile',
        'Fax',
        'Title',
        'Department',
        'Manager',
        'Company',
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
        Office                = $ADUser.Office
        StreetAddress         = $ADUser.StreetADdress
        City                  = $ADUser.City
        State                 = $ADUser.State
        postalCode            = $ADUser.postalCode
        Country               = $ADUser.Country
        Mobile                = $ADUser.Mobile
        Fax                   = $ADUser.Fax
        Title                 = $ADUser.Title
        Department            = $ADUser.Department
        Manager               = $ADUser.Manager
        Company               = $ADUser.Company
        Groups                = $Groups
    }
    New-Folder -Path $OutputPath
    $Output | Out-File $OutputPath\$($Identity)_output.txt
    Write-Host "[INFO] Exported user property output to $($OutputPath)\$($Identity)_output.txt"

}

### Logging
$LogFile = ".\Create-ADUser.log"
Write-Log "[START] Starting processing for user: $UserPrincipalName"

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

### Start validating/updatring params with optional parameters

# Match the country input to a valid two-letter country code
if ( $Country ) {
    $cultureInfo = Get-CultureInfoList
    $countryCode = ($cultureInfo | Where-Object { $_.EnglishName -like $Country -or $_.TwoLetterISORegionName -like $Country }).TwoLetterISORegionName | Select-Object -Unique
    if ( $countryCode ) {
        Write-Log "[INFO] Matched provided country ($Country) to ISO 3166 two-letter region name: $countryCode"
        $Country = $countryCode
        
    } 
    else {
        Write-Output "[ERROR] Failed to match the provided country ($Country) to an ISO 3166 two-letter region name (example: Mexico -> MX). Please set the country to a valid two-letter region name and try again."
        Write-Log "[ERROR] Failed to match the provided country ($Country) to an ISO 3166 two-letter region name (example: Mexico -> MX)"
        exit 1
    }
}

# Add the optional properties that are a one-to-one property match
$optionalProperties = @('EmailAddress', 'Office', 'StreetAddress', 'City', 'State', 'postalCode', 'Country', 'Mobile', 'Fax', 'Title', 'Department', 'Company')
$optionalProperties | ForEach-Object {
    $Value = Get-Variable -Name $_ -ErrorAction SilentlyContinue -ValueOnly
    if ( $Value ) {
        $params.$_ = $Value
        Write-Log "[INFO] Added optional parameter value: $_ - $Value"
    }
}
# Add the user's manager
if ( $Manager ) {
    Write-Log "[INFO] Attempting to locate Active Directory user using input: $Manager"
    if ( $Manager = (Find-ADUser -Identity $Manager).SamAccountName ) {
        $params.Manager = $Manager
        Write-Log "[INFO] Added manager parameter value: $Manager"
    }
    else {
        Write-Log "[WARNING] Unable to locate manager using input: $Manager. Manager will need to be set manually"
        Write-Output "[WARNING] Unable to locate manager using input: $Manager. Manager will need to be set manually"
    }
}

# If a user was provided in the CopyUser section of the CSV, locate the user by UPN/SamAccountName/DisplayName and provide the user object as the Instance parameter
# This will be used to copy ADUser group memberships and properties. Note: The new user will use the copied values (ex: City/State/etc.) UNLESS overriden by a different value in the corresponding optional field
if ( $CopyUser ) {
    Write-Log "[INFO] CopyUser parameter value was provided, attempting to locate $CopyUser"
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
    $UserToCopy = Find-ADUser -Identity $CopyUser -Properties $Properties -ErrorAction Stop
    if ($UserToCopy) {
        $params.Instance = $UserToCopy # Instance is the parameter in Set-ADUser which take an existing ADUser object as input
        $Path = ($UserToCopy.DistinguishedName -split ",", 2)[1] # This pulls just the target OU path of the user being copied so the new user is created in the same OU
        $params.Path = $Path
        Write-Log "[INFO] Added to CopyUser parameter value: $($UserToCopy.samAccountName)"
        Write-Log "[INFO] Added path parameter value from CopyUser: $Path"
    }
    else {
        Write-Output "[ERROR] A user to copy (CopyUser) was provided in the input, but the user could not be found. Exiting script."
        Write-Log "[ERROR] A user to copy (CopyUser) was provided in the input, but the user could not be found. Exiting script"
        exit 1
    }
}


### Attempt to create the new account using $params
try {
    Write-Output "[INFO] Attempting to create new user: $($params.samAccountName)"
    Write-Log "[INFO] Attempting to create new user: $($params.samAccountName)"
    New-ADUser @params
    Write-Output "[INFO] Successfully created new user: $($params.samAccountName)"
    Write-Log "[INFO] Successfully created new user: $($params.samAccountName)"
}
catch [System.UnauthorizedAccessException] {
    Write-Output "[ERROR] Error encountered while attempting to create $($params.Name): $($_.Exception.Message). Make sure you are running the script as Administrator and try again."
    Write-Log "[ERROR] Error encountered while attempting to create $($params.Name): $($_.Exception.Message). Make sure you are running the script as Administrator and try again."
    exit 1
}
catch [Microsoft.ActiveDirectory.Management.ADPasswordComplexityException] {
    Write-Output "[WARNING] The password entered for $($params.Name) does not meet the length, complexity, or history requirement of the domain.The user was created successfully but the password needs to be reset and then the account can be enabled."
    Write-Log "[WARNING] The password entered for $($params.Name) does not meet the length, complexity, or history requirement of the domain.The user was created successfully but the password needs to be reset and then the account can be enabled."
}
catch {
    Write-Output "[ERROR] Error encountered while attempting to create $($params.Name): $($_.Exception.Message)."
    Write-Log "[ERROR] Error encountered while attempting to create $($params.Name): $($_.Exception.Message)."
    exit 1
}

### Post user creation changes

# Set the user's PrimarySmtpAddress and alias
if ( $Alias ) {
    # Create an array from $Aliases, splitting by a semicolon
    $Aliases = $Alias.Split(";")

    # Run the function to set both the PrimarySmtpAddress and any aliases
    Set-ADUserAliases -Identity $SamAccountName -PrimarySmtpAddress $EmailAddress -Aliases $Aliases

}

# Copy group membership
if ( $CopyUser ) {
    Copy-ADGroupMembership -Source $UserToCopy.SamAccountName -Destination $params.SamAccountName
}

Export-UserProperties -Identity $SamAccountName -OutputPath C:\Scripts
Write-Log "[FINISH] User creation script has finished for $UserPrincipalName"