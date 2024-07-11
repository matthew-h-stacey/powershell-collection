########################
# Example 1 - Using explicit values
########################
 
Get-AzureADUser -Filter "userPrincipalName eq 'jondoe@contoso.com'"
Get-AzureADUser -Filter "startswith(JobTitle,'Sales')"

########################
# Example 2 - Using SearchString (if supported)
########################

Get-AzureADUser -SearchString "New"

########################
# Example 3 - Using a variable
########################

# First build a Filter variable, then use then to run the filter
$displayName = "Superstars"
$filter = "startsWith(DisplayName,'" + $displayName + "')"
Get-AzureADMSGroup -Filter $filter

# 3a) Simple example
$mail = $user.Mail
$filter = "Mail eq '" + $mail + "'"
$AADUser = Get-AzureADUser -Filter $filter

# 3b) More involved example
$AADGroups = (Get-AzureADUserMembership -ObjectId $AADUser.objectID -All:$True) | Where-Object { $_.MailEnabled -eq $False } # All Azure group membership
foreach ( $g in $AADGroups) {
    # build up the $excludedGroups array with any dynamic groups
    $displayName = $g.DisplayName
    $filter = "startsWith(DisplayName,'" + $displayName + "')"
    if (((Get-AzureADMSGroup -Filter $filter).GroupTypes) -eq "DynamicMembership") {
        # If this matches, group is dynamic and should be skipped from the group removal process below
        $excludedGroups += $g.DisplayName
    }
}

########################
# Graph example
########################
$params = @{
    Top    = 1
    Filter = "IsInteractive eq true and UserPrincipalName eq '$UserPrincipalName'"
    Select = "CreatedDateTime,Location,IPAddress,IsInteractive"
}
$queryString = ($params.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join "&"
$uri = "https://graph.microsoft.com/beta/auditLogs/signIns?$queryString"
$lastSignIn = Invoke-MgGraphRequest -Method GET -Uri $uri


########################
# Filtering subproperties with OData format
########################

# standard powershell property equivalent:
$object.property1.subproperty -eq $value

# OData equivalent:
$filter = "status/errorCode eq 0"

########################
# Filtering at the end of a URI
########################
$Uri = "https://graph.microsoft.com/v1.0/auditLogs/signins?$filter=userPrincipalName eq 'user@example.com'"
$Uri = "https://graph.microsoft.com/v1.0/auditLogs/signins?$filter=userPrincipalName eq 'user@example.com'&$top=1"
$Uri = "auditLogs/signins?`$filter=userPrincipalName eq '{0}' and status/errorCode ne 0 and IsInteractive eq {1}`&`$top=1" -f $PSItem.UserPrincipalName, $IsInteractive

########################
# Selecting certain properties in a URI request
# Note the position of $select and that it is before top
########################
$urlTemplate = "auditLogs/signins?`$filter=userPrincipalName eq '{UserPrincipalName}' and status/errorCode ne 0 and IsInteractive eq true&`$select=createdDateTime,location,ipAddress,isInteractive&`$top=1"
