$results = @()

$AllADUsers = Get-ADUser -Filter { Enabled -eq $True } -Properties Mail, LastLogonDate, Department, Title, StreetAddress, City, TelephoneNumber

foreach ( $User in $AllADUsers ) {

    $userExport = [PSCustomObject]@{
        UserPrincipalName = $User.UserPrincipalName
        DisplayName       = $User.Name
        Mail              = $User.Mail
        LastLogonDate     = $User.LastLogonDate
        Department        = $User.Department
        JobTitle          = $User.Title
        StreetAddress     = $User.StreetAddress
        City              = $User.City
        TelephoneNumber   = $User.TelephoneNumber
    }
    $results += $userExport

}