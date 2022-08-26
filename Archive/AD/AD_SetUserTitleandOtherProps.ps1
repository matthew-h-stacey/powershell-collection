# Establish variables
$directory = "C:\TempPath"
$users = Import-Csv $directory\users.csv

# Import Active Directory Module
Import-Module ActiveDirectory

# Back up current UPNs and Titles
$allADUsers = Get-ADUser -Filter * -Properties *
$allADUsers | Sort-Object  UserPrincipalName | Select-Object UserPrincipalName, Department, MobilePhone, Office, OfficePhone, Title  | Export-Csv $directory\users_backup.csv -NoTypeInformation

# Set Title on each user
foreach ($u in $users) {

    $UPN = $u.UserPrincipalName
    $adUser = Get-ADUser -Filter { UserPrincipalName -like $UPN }

    if ($u.department) { $adUser | Set-ADUser -Department $u.department } else { $adUser | Set-ADUser -Department ' ' }
    if ($u.mobile) { $adUser | Set-ADUser -mobile $u.mobile } else { $adUser | Set-ADUser -mobile ' ' }
    if ($u.city) { $adUser | Set-ADUser -city $u.city } else { $adUser | Set-ADUser -city  ' ' }
    if ($u.OfficePhone) { $adUser | Set-ADUser -OfficePhone $u.OfficePhone } else { $adUser | Set-ADUser -OfficePhone  ' ' }
    if ($u.office) { $adUser | Set-ADUser -Office $u.Office } else { $adUser | Set-ADUser -Office ' ' }
    if ($u.title) { $adUser | Set-ADUser -Title $u.Title } else { $adUser | Set-ADUser -Title ' ' }
}

# Export updated list of UPN and Title
$allADUsersNew = Get-ADUser -Filter * -Properties *
$allADUsersNew | Sort-Object  UserPrincipalName | Select-Object UserPrincipalName, Department, MobilePhone, Office, TelephoneNumber, Title | Export-Csv $directory\users_new.csv -NoTypeInformation