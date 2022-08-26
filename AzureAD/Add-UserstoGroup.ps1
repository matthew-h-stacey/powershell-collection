# two methods to get groupID
$groupID = Get-AzureADGroup -Filter "DisplayName eq 'Lock Screen - SWTX Commercial'" | select -ExpandProperty objectID
$groupID = Get-AzureADGroup -All:$True | Where-Object { $_.DisplayName -like "Lock Screen - SWTX Commercial" } | select -ExpandProperty objectID


$usersToAdd = get-content C:\TempPath\users.txt

foreach ($u in $usersToAdd) {
    # two methods (depends on format of $u, DisplayName, UPN, etc.)

    $uid = Get-AzureADUser -All $true | Where-Object { $_.DisplayName -like $u } | select -ExpandProperty objectID
    # $uid = Get-AzureADUser -ObjectId $u | select -ExpandProperty objectID
    
    write-host "Adding $($u) to group"
    Add-AzureADGroupMember -ObjectId $groupID -RefObjectId $uid
}