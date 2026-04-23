# Return one array with all objects, supporting count past the default 999

########################
# Example 1
########################

$objectType = "users"  # "groups", "devices", etc.
$uri = "https://graph.microsoft.com/v1.0/"

$graphResponse = [System.Collections.Generic.List[object]]::new()
$nextLink = $null
do {
    $requestUri = if ($nextLink) {
        $nextLink
    } else {
        $uri
    }
    $response = Invoke-MgGraphRequest -Uri $requestUri -Method GET
    if ($response.Value) {
        $graphResponse.AddRange($response.Value)
    }
    $nextLink = $response.'@odata.nextLink'
} until (-not $nextLink)

# Optional: convert to array if needed
#$msGraphResponse = $msGraphResponse.ToArray()

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
