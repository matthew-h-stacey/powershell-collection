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

    # Optional parameters with if-statements
    if ($User.CopyUser) { $params.CopyUser = $User.CopyUser }
    if ($User.Email) { $params.Email = $User.Email }
    if ($User.Alias) { $params.Alias = $User.Alias }
    if ($User.Office) { $params.Office = $User.Office }
    if ($User.StreetAddress) { $params.StreetAddress = $User.StreetAddress }
    if ($User.City) { $params.City = $User.City }
    if ($User.State) { $params.State = $User.State }
    if ($User.PostalCode) { $params.PostalCode = $User.PostalCode }
    if ($User.Country) { $params.Country = $User.Country }
    if ($User.Mobile) { $params.Mobile = $User.Mobile }
    if ($User.Fax) { $params.Fax = $User.Fax }
    if ($User.Title) { $params.Title = $User.Title }
    if ($User.Department) { $params.Department = $User.Department }
    if ($User.Manager) { $params.Manager = $User.Manager }
    if ($User.Company) { $params.Company = $User.Company }

    # Remove any trailing spaces from strings in params
    $trimmedParams = @{}
    foreach ($key in $params.Keys) {
        if ( $params[$key] -is [String]) {
            $trimmedParams[$key] = $params[$key] -replace '\s+$'
        }
        else {
            $trimmedParams[$key] = $params[$key]
        }
    }

    .\Create-ADUser.ps1 @trimmedParams
}
