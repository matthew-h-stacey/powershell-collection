if (([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) -eq $False) {
    Write-Warning "Script requires Administrator access. Re-run as Administrator"
    Read-Host -Prompt "Press Enter to exit"
    break
}

# Intro
Write-host "Follow the prompts to change the last logged on user for a Windows 10 PC"

# 0) retrieve shortdomain
$domain = $env:UserDomain

# 1) prompt for user displayName
$dn = Read-Host "Enter displayName of user (ex: "John Smith")"
Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI -Name LastLoggedOnDisplayName -Value $dn -Force

# 2) prompt for user samAccountName
$uname = Read-Host "Enter user samAccountName (ex: "jsmith")"
$newUname = $domain + "\" + $uname
Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI -Name LastLoggedOnSAMUser -Value $newUname -Force
Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI -Name LastLoggedOnUser -Value $newUname -Force

# 3) get SID
$objUser = New-Object System.Security.Principal.NTAccount($domain, $uname)
$strSID = $objUser.Translate([System.Security.Principal.SecurityIdentifier])
$newSID = $strSID.Value
Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI -Name LastLoggedOnUserSID -Value $newSID -Force