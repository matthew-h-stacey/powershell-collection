# Define your list of users to update state in bulk
$users = "bsimon@contoso.com", "jsmith@contoso.com", "ljacobson@contoso.com"

foreach ($user in $users) {
    $st = New-Object -TypeName Microsoft.Online.Administration.StrongAuthenticationRequirement
    $st.RelyingParty = "*"
    $st.State = "Enabled"
    $sta = @($st)
    Set-MsolUser -UserPrincipalName $user -StrongAuthenticationRequirements $sta
}


##
##
##

$allMsolUsers = Get-MsolUser -All | Sort-Object UserPrincipalName

$results = @()
foreach($user in $allMsolUsers){
    $userObject = [PSCustomObject]@{
        UPN = $user.UserPrincipalName
        DN = $user.DisplayName
        mfaStatus = $user.StrongAuthenticationRequirements.State
        isLicensed = $user.IsLicensed
        PasswordNeverExpires = $user.PasswordNeverExpires
    }
    $results += $userObject
}
$results | Export-Csv C:\TempPath\allLicensedMsolUsers_MFAStatus.csv -NoTypeInformation


$mfaExcludeUsers = get-content C:\TempPath\mfaExcludeUsers.txt
foreach ($t in $mfaExcludeUsers){
    Set-MsolUser -UserPrincipalName $t -Department "IT Service Account"
}