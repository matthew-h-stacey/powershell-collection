# TO DO
# - Add support for adding groups via CSV ..?


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
    [Parameter(Mandatory = $true)]
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

    # User's office number
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

    # User's two-digit country code (ex: US)
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
        $Properties,

        # Show output
        [Parameter(Mandatory = $false)]
        [Switch]
        $ShowOutput
    )

    if ($Identity -match '@') {
        # Identity contains '@', consider it as UPN
        if ( $Properties ) {
            $User = Get-ADUser -Filter { UserPrincipalName -eq $Identity } -Properties $Properties
        }
        else {
            $User = Get-ADUser -Filter { UserPrincipalName -eq $Identity }
        }
    }
    else {
        # Try to get the user by samAccountName or DisplayName
        if ( $Properties ) {
            $User = Get-ADUser -Filter { samAccountName -eq $Identity -or DisplayName -eq $Identity } -Properties $Properties
        }
        else {
            $User = Get-ADUser -Filter { samAccountName -eq $Identity -or DisplayName -eq $Identity }
        }
    }

    if ( !$User ) {
        Write-Output "[ERROR] Unable to locate a user with provided input: $Identity. Please verify that you entered the correct samAccountName/DisplayName/UserPrincipalName of an existing user and try again."
        break
    }
    else {
        if ( $ShowOutput ) {
            Write-Output "[INFO] Located user $($User.Name) ($($User.UserPrincipalName))"
        }
    
    }
    return $User

}
function Copy-ADGroupMembership {
    # Copies the ADUser group membership from one user to another
    # Example: Copy-ADGroupMembership -Identity jsmith@contoso.com -User aapple@contoso.com

    param (
        # The source user to copy membership from
        [Parameter(Mandatory = $true)]
        [String]
        $Identity,

        # The destination user to copy membership to
        [Parameter(Mandatory = $true)]
        [String]
        $User
    )

    # Copies AD group membership from source user to destination user
    Write-Output "[INFO] Matching Active Directory group membership from $Identity to $User"
    $CurrentMembership = Find-ADUser -Identity $User -Properties MemberOf | Select-Object -ExpandProperty MemberOf
    $Groups = Find-ADUser -Identity $Identity -Properties MemberOf | Select-Object -ExpandProperty MemberOf

    foreach ( $Group in $Groups ) {
        try {
            if ( $Group -notin $CurrentMembership ) {
                Add-ADGroupMember -Identity $Group -Members $User
            }
            else {
                # Skip - User is already a member
            }
        }
        catch {
            "[ERROR] Failed to add $User to group: $Group. Error: $($_.Exception.Message)"
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

    # Add the PrimarySmtpAddress (SMTP) to the proxyAddresses property
    $EmailSMTP = "SMTP:" + $PrimarySmtpAddress
    Set-ADUser -Identity $Identity -Add @{proxyAddresses = $EmailSMTP }

    # Add any aliases (smtp) to the proxyAddresses property
    $Aliases | ForEach-Object { 
        $AliasSMTP = "smtp:" + $_
        Set-ADUser -Identity $Identity -Add @{proxyAddresses = $AliasSMTP }
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
        # Path already exists, continue
    }

}

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
# Add the optional properties that are a one-to-one property match
$optionalProperties = @('EmailAddress', 'Office', 'StreetAddress', 'City', 'State', 'postalCode', 'Country', 'Mobile', 'Fax', 'Title', 'Department', 'Company')
$optionalProperties | ForEach-Object {
    $Value = Get-Variable -Name $_ -ErrorAction SilentlyContinue -ValueOnly
    if ( $Value ) {
        $params.$_ = $Value
    }
}
# Add the user's manager
if ( $Manager ) {
    $params.Manager = (Find-ADUser -Identity $Manager).SamAccountName
}

# If a user was provided in the CopyUser section of the CSV, locate the user by UPN/SamAccountName/DisplayName and provide the user object as the Instance parameter
# This will be used to copy ADUser group memberships and properties. Note: The new user will use the copied values (ex: City/State/etc.) UNLESS overriden by a different value in the corresponding optional field
if ( $CopyUser ) {
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
        $params.Path = ($UserToCopy.DistinguishedName -split ",", 2)[1] # This pulls just the target OU path of the user being copied so the new user is created in the same OU
    }
    else {
        Write-Output "[ERROR] A user to copy (CopyUser) was provided in the input, but the user could not be found. Exiting script."
        exit
    }
}


### Attempt to create the new account using $params
try {
    Write-Output "[INFO] Attempting to create new user: $($params.Name)"
    New-ADUser @params
    Write-Output "[INFO] Created new user: $($params.Name)"
}
catch [System.UnauthorizedAccessException] {
    Write-Output "[ERROR] Error encountered while attempting to create $($params.Name): $($_.Exception.Message). Make sure you are running the script as Administrator and try again."
    exit
}
catch [Microsoft.ActiveDirectory.Management.ADPasswordComplexityException] {
    Write-Output "[WARNING] The password entered for $($params.Name) does not meet the length, complexity, or history requirement of the domain.The user was created successfully but the password needs to be reset and then the account can be enabled."
}
catch {
    Write-Output "[ERROR] Error encountered while attempting to create $($params.Name): $($_.Exception.Message)."
    exit
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
    Copy-ADGroupMembership -Identity $UserToCopy.SamAccountName -User $params.SamAccountName
}

Export-UserProperties -Identity $SamAccountName -OutputPath C:\Scripts