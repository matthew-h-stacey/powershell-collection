function Clear-AzureADUserMultifactorMethods {

    param(
        [Parameter(Mandatory=$true)]
        [String]$UserPrincipalName	
    )

    Get-MgUserAuthenticationEmailMethod -UserID $UserPrincipalName | ForEach-Object { Remove-MgUserAuthenticationEmailMethod -UserID $UserPrincipalName -EmailAuthenticationMethodId $_.Id }
    Get-MgUserAuthenticationPhoneMethod -UserID $UserPrincipalName | ForEach-Object { Remove-MgUserAuthenticationPhoneMethod -UserID $UserPrincipalName -PhoneAuthenticationMethodId $_.Id }
    Get-MgUserAuthenticationMicrosoftAuthenticatorMethod -UserID $UserPrincipalName |  ForEach-Object { Remove-MgUserAuthenticationMicrosoftAuthenticatorMethod -UserID $UserPrincipalName -MicrosoftAuthenticatorAuthenticationMethodId $_.Id }

}