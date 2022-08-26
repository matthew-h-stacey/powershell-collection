# Change as needed
$UserPrincipalName = "AlexW@5r86fn.onmicrosoft.com"
$MgUserManagerUPN = "MiriamG@5r86fn.onmicrosoft.com"

# Retrieve object(s)
$filter = "startsWith(UserPrincipalName,'" + $UserPrincipalName + "')"
$MgUser = Get-MgUser -Filter $filter -ErrorAction Stop 
if ( $null -eq $MgUser) {
    Write-Output "ERROR: Unable to find user"
    exit # Stop if the user cannot be found
}
$filter = "startsWith(UserPrincipalName,'" + $MgUserManagerUPN + "')"
$MgUserManager = Get-MgUser -Filter $filter -ErrorAction Stop 
if ( $null -eq $MgUser) {
    Write-Output "ERROR: Unable to find user"
    exit # Stop if the user cannot be found
}

# Set manager back
$NewManager = @{
    "@odata.id" = "https://graph.microsoft.com/v1.0/users/$($MgUserManager.Id)"
}
Set-MgUserManagerByRef -UserId $MgUser.Id -BodyParameter $NewManager

# Add MgUser to MgGroups by group DisplayName
$GroupNames = @("Coffee Crew", "Fabrikam Team", "Mac Users", "Party Planning Committee", "Sales and Marketing", "Superstars")
foreach ( $g in $groupNames ) {
    $filter = "startsWith(DisplayName,'" + $g + "')"
    $MgGroup = Get-MgGroup -Filter $filter
    try {
        New-MgGroupMember -GroupId $MgGroup.Id -DirectoryObjectId $MgUser.Id -ErrorAction Stop
        Write-Output "Added $($UserPrincipalName) to $($g)"
    }
    catch [System.Exception] {
        Write-Output "User already in $($g), skipping ..."
    }
}

# Add ownership to MgGroup by DisplayName
$GroupNames = @("Fabrikam Team","Superstars")
foreach ( $g in $groupNames ) {
    $filter = "startsWith(DisplayName,'" + $g + "')"
    $MgGroup = Get-MgGroup -Filter $filter
    $newGroupOwner = @{
        "@odata.id" = "https://graph.microsoft.com/v1.0/users/$($MgUser.Id)"
    }

    New-MgGroupOwnerByRef -GroupId $MgGroup.Id -BodyParameter $newGroupOwner
}

# Remove Manager Membership/Ownership of MgGroup "Superstars"
$GroupNames = @("Superstars")
foreach ( $g in $groupNames ) {
    $filter = "startsWith(DisplayName,'" + $g + "')"
    $MgGroup = Get-MgGroup -Filter $filter
    Remove-MgGroupOwnerByRef -GroupId $MgGroup.Id -DirectoryObjectId $MgUserManager.Id # Remove Manager ownership
    Remove-MgGroupMemberByRef -GroupId $MgGroup.Id -DirectoryObjectId $MgUserManager.Id # Remove Manager membership

}



# Unhide mailbox
set-mailbox -Identity $UserPrincipalName -HiddenFromAddressListsEnabled:$False

# Add to distis
add-distributiongroupmember -identity "Inbound Leads" -member $UserPrincipalName
add-distributiongroupmember -identity "Third Floor" -member $UserPrincipalName