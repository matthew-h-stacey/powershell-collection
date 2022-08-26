# Example: 1 user

$domain = "contoso.com"
$user = "jsmith@contoso.com"

connect-msolservice

Get-MsolUser -UserPrincipalName $user | Select LastPasswordChangeTimestamp
$PasswordPolicy = Get-MsolPasswordPolicy -DomainName $domain
$UserPrincipal = Get-MsolUser -UserPrincipalName $user
$PasswordExpirationDate = $UserPrincipal.LastPasswordChangeTimestamp.AddDays($PasswordPolicy.ValidityPeriod)


# Example: All users, using Delegated MsolService

$id = .\Connect-DelegatedMsolService.ps1

$domain = "contoso.com"
$users = Get-MsolUser -TenantId $id -All:$true | Select UserPrincipalName,LastPasswordChangeTimestamp

$PasswordPolicy = Get-MsolPasswordPolicy -DomainName $domain -TenantId $id

$results = @()
foreach($u in $users){    
    $msolUser = Get-MsolUser -UserPrincipalName $u.UserPrincipalName -TenantId $id
    $PasswordExpirationDate = $msolUser.LastPasswordChangeTimestamp.AddDays($PasswordPolicy.ValidityPeriod)
    $userExport = [PSCustomObject]@{
        UserPrincipalName           = $u.UserPrincipalName
        PasswordExpirationDate     = $PasswordExpirationDate
    }
    $results += $userExport
}
