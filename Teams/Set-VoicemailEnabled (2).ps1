param(
    # Set true/false to enable/disable voicemail for all users
    [Parameter(Mandatory=$true)]
    [Boolean]
    $VoicemailEnabled
)

$LicensedUsers = Get-CsOnlineUser -Filter { EnterpriseVoiceEnabled -eq $true }
$LicensedUsers = $LicensedUsers | Sort-Object UserPrincipalName


foreach ($User in $LicensedUsers) {
    $UserId = $User.UserPrincipalName

    try {
        switch ( $VoicemailEnabled ) {
            True { 
                Write-Host "Attempting to enable voicemail for $($UserId.Trim()) ..." 
            }
            False { 
                Write-Host "Attempting to disable voicemail for $($UserId.Trim()) ..." 
            }
        }    
        Set-CsOnlineVoicemailUserSettings -Identity $User.UserPrincipalName -VoicemailEnabled $VoicemailEnabled -ErrorAction Stop -WarningAction Stop | Out-Null    
    }
    catch {
        Write-Host "Error updating voicemail for $($UserId.Trim()). Full error:"
        Write-Host $_.Exception.Message
    }
    $CurrentSetting = Get-CsOnlineVoicemailUserSettings -Identity $User.UserPrincipalName | Select-Object -ExpandProperty VoicemailEnabled
    Write-Host "$($UserId.Trim()) voicemail: $CurrentSetting"

}