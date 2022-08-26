# NOTE: To keep this code simple, make sure the headers of the CSV match the user object attribute in Active Directory

# Establish variables
$directory = "C:\TempPath"
$users = Import-Csv $directory\users.csv
$userIdentifier = "DisplayName" # This variable should equate to the Header in the CSV file that is used as the user Identifier (ex: DisplayName, UserPrincipalName) - i.e, NOT a property to be changed

# User properties to retrieve and back up, then to change based on the input of the CSV file
$userProps = $users | Get-Member | Where-Object { $_.MemberType -eq "NoteProperty" } | Select-Object -ExpandProperty Name

# Empty array to store results
$results = @()

# Back up current user properties
foreach ( $u in $users) {

    # Get user by DisplayName
    if ( $userIdentifier -eq "DisplayName") {
        $userDisplayName = $u.DisplayName
        $adUser = Get-ADUser -Filter { DisplayName -like $userDisplayName } -Properties $userProps
    }

    # OR, get user by UPN
    if ( $userIdentifier -eq "UserPrincipalName") {
        $UPN = $u.UserPrincipalName
        $adUser = Get-ADUser -Filter { UserPrincipalName -eq $UPN } -Properties $userProps
    }

    if (!$adUser) {
        Write-Host "ERROR: Unable to find user $($userDisplayName)"
    }
    else {
        Write-Host "Found user $($adUser.DisplayName)"
        $userProperties = New-Object -TypeName PSObject
        foreach ( $p in $userProps) {
            Add-Member -InputObject $userProperties -MemberType NoteProperty -Name $p -Value $adUser.$p
            Write-Host "$($adUser.DisplayName) - Adding property $($p): $($adUser.$p)"
        }
        $results += $userProperties   
    }

}

$results | Export-Csv $directory\users_backup_$((Get-Date -Format "MM-dd-yyyy_HHmm")).csv

# Update property value(s) on each user
foreach ($u in $users) {

    # Get user by DisplayName
    if ( $userIdentifier -eq "DisplayName") {
        $userDisplayName = $u.DisplayName
        $adUser = Get-ADUser -Filter { DisplayName -like $userDisplayName }
    }

    # OR, get user by UPN
    if ( $userIdentifier -eq "UserPrincipalName") {
        $UPN = $u.UserPrincipalName
        $adUser = Get-ADUser -Filter { UserPrincipalName -eq $UPN }
    }

    # Set or clear property based on the presence of a property in the Excel sheet and its value
    # If the property is not present, nothing happens. If the property is present and a new vlaue is there, update it. If no value, clear it
    if ($u.department) { $adUser | Set-ADUser -Department $u.department } else { $adUser | Set-ADUser -Department ' ' }
    if ($u.mobile) { $adUser | Set-ADUser -mobile $u.mobile } else { $adUser | Set-ADUser -mobile ' ' }
    if ($u.city) { $adUser | Set-ADUser -city $u.city } else { $adUser | Set-ADUser -city  ' ' }
    if ($u.OfficePhone) { $adUser | Set-ADUser -OfficePhone $u.OfficePhone } else { $adUser | Set-ADUser -OfficePhone  ' ' }
    if ($u.office) { $adUser | Set-ADUser -Office $u.Office } else { $adUser | Set-ADUser -Office ' ' }
    if ($u.title) { $adUser | Set-ADUser -Title $u.Title } else { $adUser | Set-ADUser -Title ' ' }
}

# Optional: Export a list of all users and relevant properties
$allADUsersNew = Get-ADUser -Filter * -Properties *
$allADUsersNew | Sort-Object  UserPrincipalName | Select-Object UserPrincipalName, Department, MobilePhone, Office, TelephoneNumber, Title | Export-Csv $directory\all_users_updated.csv -NoTypeInformation