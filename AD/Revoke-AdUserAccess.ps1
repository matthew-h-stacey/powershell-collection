function Find-AdUser {
    # Searches for an AdUser with a UPN, DisplayName, or samAccount name. This allows the input to be more flexible than just using Get-AdUser

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
            $User = Get-AdUser -Filter { UserPrincipalName -eq $Identity } -Properties $Properties
        }
        else {
            $User = Get-AdUser -Filter { UserPrincipalName -eq $Identity }
        }
    }
    else {
        # Try to get the user by samAccountName or DisplayName
        if ( $Properties ) {
            $User = Get-AdUser -Filter { samAccountName -eq $Identity -or DisplayName -eq $Identity } -Properties $Properties
        }
        else {
            $User = Get-AdUser -Filter { samAccountName -eq $Identity -or DisplayName -eq $Identity }
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

function Get-RandomPassword {
    
    param (
        [Parameter(Mandatory)]
        [int] $Length
    )
        
    $CharSet = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()'.ToCharArray()
    $Password = -join (Get-Random -InputObject $CharSet -Count $Length)
        
    return $password
    
}

function Clear-AdGroupMembership {
    # Remove an AdUser account from all AdGroups that they are currently members of

    param (
        # The source user to copy membership from
        [Parameter(Mandatory = $true)]
        [String]
        $Identity
    )

    $CurrentMembership = Find-AdUser -Identity $Identity -Properties MemberOf | Select-Object -ExpandProperty MemberOf 

    $Groups = @()
    
    if ( $CurrentMembership -gt 0) {

        $CurrentMembership | ForEach-Object {
            try {
                Remove-ADGroupMember -Identity $_ -Members $Identity -Confirm:$false
                $GroupName = ((($_ -split ",", 2)[0]) -split "=")[1]
                $Groups += $GroupName
            }
            catch {
                Write-Output "[ERROR] Failed to remove user from $GroupName. Error: $($_.Exception.Message)"
            }
        }
        $Groups = ($Groups | Sort-Object) -join ", "
        Write-Output "[INFO] Removed user from groups: $Groups"
    }
    else {
        Write-Output "[INFO] User is not a part of any groups, no memberships to remove"   
    }

}

$UserInput = Read-Host "Enter the name of a user to terminate"
$User = Find-AdUser -Identity $UserInput

if ( !$User ) {
    Write-Output "[ERROR] Unable to locate user with input: $UserInput. Exiting script"
    exit 1
}
else {
    Write-Output "[INFO] Located user: $($User.UserPrincipalName). Continuing"
}

# Disable the user account
try {
    if ( $User.Enabled -eq $true ) {
        Set-ADUser -Identity $User.DistinguishedName -Enabled:$false
        Write-Output "[INFO] Disabled user account"
    }
    else {
        Write-Output "[INFO] User account was already disabled"
    }
}
catch {
    Write-Output "[ERROR] Unable to disable the user account. Error: $($_.Exception.Message)"
    exit 1
}

# Reset the account's password to a 32-character randomly generated password (in case the account is re-enabled)
try {
    Set-ADAccountPassword -Identity $User.DistinguishedName -Reset -NewPassword (ConvertTo-SecureString (Get-RandomPassword -Length 32) -AsPlainText -Force)
    Write-Output "[INFO] Reset the account password to a 32-character randomly generated password"
}
catch {
    Write-Output "[ERROR] Unable to reset the account password. Error: $($_.Exception.Message)"
    exit 1    
}

# Locate the non-synced OU the user should be moved to
$NonSyncedUsersOU = Get-ADOrganizationalUnit -Filter * | Where-Object { $_.DistinguishedName -like "OU=Users,OU=AAD Excluded,DC=*" }
$TargetPath = $NonSyncedUsersOU.DistinguishedName


if (!($User.DistinguishedName -match $TargetPath)) {
    if ( $NonSyncedUsersOU.DistinguishedName.Count -eq 1 ) {
        try {
            
            Move-ADObject -Identity $User.DistinguishedName -TargetPath $TargetPath 
            Write-Output "[INFO] Moved user to OU: $TargetPath"
        }
        catch {
            Write-Output "[ERROR] Unable to move user to $TargetPath. Error: $($_.Exception.Message)"
            exit 1    
        }
    }
}
else {
    Write-Output "[INFO] User is already in the AAD Excluded users OU"
}

Clear-AdGroupMembership -Identity $User.SamAccountName