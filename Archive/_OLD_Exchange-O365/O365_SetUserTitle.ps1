# Establish variables
$directory = "C:\TempPath"
$users = Import-Csv $directory\users.csv

# Install AzureAD module and connect
Install-Module AzureAD -Scope CurrentUser
Import-Module AzureAD
Connect-AzureAD

# Back up current UPNs and Titles
$allAzureADUsers = Get-AzureADUser -All $true
$allAzureADUsers | Sort-Object  UserPrincipalName | Select-Object UserPrincipalName, JobTitle | Export-Csv $directory\users_backup.csv -NoTypeInformation

#
foreach($u in $users){
    if($u.Title -ne ''){
        Write-Host "Setting $($u.UserPrincipalName) title to '$($u.Title)'"
        Set-AzureADUser -ObjectId $u.UserPrincipalName -JobTitle $u.Title
    }
}

$allAzureADUsersNew = Get-AzureADUser -All $true
$allAzureADUsersNew | Sort-Object  UserPrincipalName | Select-Object UserPrincipalName, JobTitle | Export-Csv $directory\CFPS_users_new.csv -NoTypeInformation