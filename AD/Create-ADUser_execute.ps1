$CSV = Import-Csv -Path C:\Scripts\Create-ADUser_template.csv

foreach ($User in $CSV) {
    # Initialize an empty hashtable for parameters
    $params = @{}

    # Mandatory parameters
    $params.FirstName = $User.FirstName
    $params.LastName = $User.LastName
    $params.DisplayName = $User.DisplayName
    $params.SamAccountName = $User.SamAccountName
    $params.UserPrincipalName = $User.UserPrincipalName
    $params.ChangePasswordAtLogon = [System.Convert]::ToBoolean($User.ChangePasswordAtLogon)
    $params.Enabled = [System.Convert]::ToBoolean($User.Enabled)

    # Loop through $optionalParams and add the properties to $params if present in $User
    $optionalParams = @('CopyUser', 'Email', 'Alias', 'Title', 'Department', 'Manager', 'Company', 'EmployeeID', 'StreetAddress', 'Office', 'City', 'State', 'postalCode', 'Country', 'Mobile', 'Fax', 'HomePhone', 'IpPhone', 'Pager', 'Description')
    foreach ($paramName in $optionalParams) {
        if ($User.$paramName) {
            $params.$paramName = $User.$paramName
        }
    }

    # Remove any trailing spaces from the input
    $trimmedParams = @{}
    foreach ($key in $params.Keys) {
        if ( $params[$key] -is [String]) {
            $trimmedParams[$key] = $params[$key] -replace '\s+$'
        }
        else {
            $trimmedParams[$key] = $params[$key]
        }
    }

    C:\Scripts\Create-ADUser.ps1 @trimmedParams
    Read-Host -Prompt "Press Enter to exit"
}
