# note: change givenName and surname to use $u

$users = Import-Csv .\new_users.csv

foreach ( $u in $users ) {

    $domain = "contoso.com"

    $givenName = $u.givenName 
    $surname = $u.surname
    $name = "$givenName $surname"
    $samAccountName = (-join $givenname[0] + $surname).toLower()
    $UserPrincipalName = "$samAccountName@$domain"


    $userparams = @{
        GivenName         = $givenName
        Surname           = $surname
        Name              = $name
        DisplayName       = $name
        samAccountName    = $samAccountName
        UserPrincipalName = $UserPrincipalName
        EmailAddress      = $UserPrincipalName
    }

    New-ADUser @userparams

    $replyAddress = "SMTP:" + $UPN
    $alias = "smtp:$($givenName.ToLower())"

    Set-ADUser -Identity $samAccountName -Add @{'proxyAddresses' = $newReplyAddress } 

}
