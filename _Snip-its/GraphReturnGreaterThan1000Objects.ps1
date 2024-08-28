# Return one array with all objects, supporting count past the default 999

########################
# Example 1
########################

$objectType = "users" # ex: "groups" "users" "devices"
$uri = 'https://graph.microsoft.com/v1.0/' + $ObjectType + '?$top=999'

$msGraphResponse = @()
$nextLink = $null
do {
    $uri = if ($nextLink) {
        $nextLink
    } else {
        $URI
    }
    $response = Invoke-MgGraphRequest -Uri $uri -Method GET
    $output = $response.Value
    $msGraphResponse += $output
    $nextLink = $response.'@odata.nextLink'
} until (-not $nextLink )

########################
# Example 2
########################

$Method = "GET"
$Uri = 'https://graph.microsoft.com/beta/users?$select=DisplayName,UserPrincipalName,Mail,UserType,AccountEnabled,onPremisesSyncEnabled,signInActivity,AssignedLicenses,LastPasswordChangeDateTime,CompanyName,EmployeeId,Department,JobTitle,StreetAddress,City,State,Country,BusinessPhones,MobilePhone&$top=999'
$MSGraphOutput = @()
$nextLink = $null
do {
    $Uri = if ($nextLink) { $nextLink } else { $Uri }
    $response = Invoke-MgGraphRequest -Uri $Uri -Method $Method
    $output = $response.Value
    $MSGraphOutput += $output
    $nextLink = $response.'@odata.nextLink'
} until (-not $nextLink)