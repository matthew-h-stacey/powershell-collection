# AAD Properties Report
$exportPath = "C:\TempPath\"
$fileName = "FourQ_User_Report.csv"

#
Connect-AzureAD

#
$activeAADUsers = Get-AzureADUser -Filter "AccountEnabled eq true"

#
$results = @()

foreach($u in $activeAADUsers){
    $userExport = [PSCustomObject]@{
        DisplayName         = $u.DisplayName
        Mail                = $u.Mail
        CompanyName         = $u.CompanyName
        Manager             = (Get-AzureADUserManager -ObjectId $u.UserPrincipalName).DisplayName
        Department          = $u.Department
        JobTitle            = $u.JobTitle
        StreetAddress       = $u.StreetAddress
        City                = $u.City
        TelephoneNumber     = $u.TelephoneNumber
    }
    $results += $userExport
}

#
$results | Export-Csv "$exportPath$fileName" -NoTypeInformation
