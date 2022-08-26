# Establish variables
$directory = "C:\TempPath"
$users = Import-Csv $directory\users_PCA.csv

# Import Active Directory Module
Import-Module ActiveDirectory

# Back up current UPNs and Titles
$allADUsers = Get-ADUser -Filter * -Properties *
$allADUsers | Sort-Object  UserPrincipalName | Select-Object UserPrincipalName, Title | Export-Csv $directory\users_backup.csv -NoTypeInformation

# Set Title on each user
foreach ($u in $users) {
    if ($u.Title -ne '') {
        $UPN = $u.UserPrincipalName
        Write-Host "Setting $UPN title to '$($u.Title)'"
        Get-ADUser -Filter { UserPrincipalName -like $UPN } | Set-ADUser -Title $u.Title
    }
}

# Export updated list of UPN and Title
$allADUsersNew = Get-ADUser -Filter * -Properties *
$allADUsersNew | Sort-Object  UserPrincipalName | Select-Object UserPrincipalName, Title | Export-Csv $directory\users_new.csv -NoTypeInformation