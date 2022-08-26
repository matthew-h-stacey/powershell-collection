# Establish variables
$directory = "C:\TempPath"
$users = Import-Csv $directory\users.csv

# Install AzureAD module and connect
Install-Module AzureAD -Scope CurrentUser
Import-Module AzureAD
Connect-AzureAD

# Back up current UPNs and Titles
$allAzureADUsers = Get-AzureADUser -All $true
$cfpsAzureADUsers = $allAzureADUsers | where { $_.UserPrincipalName -like "*@cfpsych.org" -and $_.DirSyncEnabled -eq $false}
$cfpsAzureADUsers | Sort-Object  UserPrincipalName | Select-Object UserPrincipalName, Department, Mobile, City, TelephoneNumber, JobTitle | Export-Csv $directory\users_backup.csv -NoTypeInformation

# Set Title on each user
foreach ($u in $users) {
    # Set-AzureADUser -ObjectId $u.UserPrincipalName -Department $u.Department -Mobile $u.Mobile -City $u.City  -TelephoneNumber $u.TelephoneNumber -JobTitle $u.JobTitle
    if ($u.department) { Set-AzureADUser -ObjectId $u.UserPrincipalName -Department $u.department } else { Set-AzureADUser -ObjectId $u.UserPrincipalName -Department ' ' }
    if ($u.mobile) { Set-AzureADUser -ObjectId $u.UserPrincipalName -mobile $u.mobile } else { Set-AzureADUser -ObjectId $u.UserPrincipalName -Mobile ' '}
    if ($u.city) { Set-AzureADUser -ObjectId $u.UserPrincipalName -city $u.city } else { Set-AzureADUser -ObjectId $u.UserPrincipalName -City ' ' }
    if ($u.telephonenumber) { Set-AzureADUser -ObjectId $u.UserPrincipalName -TelephoneNumber $u.TelephoneNumber } else { Set-AzureADUser -ObjectId $u.UserPrincipalName -TelephoneNumber ' ' }
    if ($u.jobtitle) { Set-AzureADUser -ObjectId $u.UserPrincipalName -JobTitle $u.JobTitle } else { Set-AzureADUser -ObjectId $u.UserPrincipalName -JobTitle ' ' }
        }

# Export updated list of UPN and Title
$allAzureADUsers = Get-AzureADUser -All $true
$cfpsAzureADUsersNew = $allAzureADUsers | where {$_.UserPrincipalName -like "*@cfpsych.org"}
$cfpsAzureADUsersNew | Sort-Object  UserPrincipalName | Select-Object UserPrincipalName, Department, Mobile, City, TelephoneNumber, JobTitle | Export-Csv $directory\users_new.csv -NoTypeInformation
