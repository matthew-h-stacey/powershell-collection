# Objective:
# Using a list of users' DisplayName and UserPrincipalName
# 1) Locate the user in AD
# 2) Grab the objectGUID and convert it to ImmutableID
# 3) Set the ImmutableID on their MsolUser, matched by UserPrincipalName

# Run this on a PC with access to on-prem AD and the MsolService module

$workDir = "C:\TempPath"
$users = Import-Csv $workDir\users.csv # List of users with headers DisplayName and UserPrincipalName

Connect-MsolService

foreach ($u in $users) {
    $dn = $u.DisplayName
    $ADUser = Get-ADuser -filter { DisplayName -like $dn }
    $objectGUID = $ADUser.objectGUID
    $immutableID = [system.convert]::ToBase64String(([GUID]$objectGUID).ToByteArray())
    Set-MsolUser -UserPrincipalName $u.UserPrincipalName -ImmutableId $immutableID
}
