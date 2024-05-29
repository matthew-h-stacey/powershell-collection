# Using explicit values
Get-AzureADUser -Filter "userPrincipalName eq 'jondoe@contoso.com'"
Get-AzureADUser -Filter "startswith(JobTitle,'Sales')"

# Using SearchString (if supported)
Get-AzureADUser -SearchString "New"

# Using a variable
# First build a Filter variable, then use then to run the filter

$displayName = "Superstars"
$filter = "startsWith(DisplayName,'" + $displayName + "')"
Get-AzureADMSGroup -Filter $filter

# Simple example
$mail = $user.Mail
$filter = "Mail eq '" + $mail + "'"
$AADUser = Get-AzureADUser -Filter $filter

# More involved example
$AADGroups = (Get-AzureADUserMembership -ObjectId $AADUser.objectID -All:$True) | Where-Object { $_.MailEnabled -eq $False } # All Azure group membership
foreach ( $g in $AADGroups) { # build up the $excludedGroups array with any dynamic groups
    $displayName = $g.DisplayName
    $filter = "startsWith(DisplayName,'" + $displayName + "')"
    if (((Get-AzureADMSGroup -Filter $filter).GroupTypes) -eq "DynamicMembership") { # If this matches, group is dynamic and should be skipped from the group removal process below
        $excludedGroups += $g.DisplayName
    }
}


