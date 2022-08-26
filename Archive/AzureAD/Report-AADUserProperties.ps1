# Created by MHS

# Objective: Bulk change the UPN and PrimarySmtpAddress of mailboxes (user AND shared) to use a new domain
# ex: After 365 cutover, mailboxes need to have those properties changed from contoso.onmicrosoft.com -> contoso.com
# This script is intended for mailboxes. For distribution groups, see Update-PrimarySmtpAddress.ps1

Param
(   
    [Parameter(Mandatory = $true)] [string] $domain # this is the new vanity domain to set on all mailboxes (ex: contoso.com)
)

$workDir = "C:\TempPath"
$mailboxes = Import-Csv $workDir\mailboxes.csv # use a CSV file with header "UserPrincipalName" - should contain ALL mailboxes that need to be changed to the new domain

Write-Host "Connecting to AzureAD, check for a pop-up authentication window"
Connect-AzureAD
Write-Host "Connecting to ExchangeOnline, check for a pop-up authentication window"
Connect-ExchangeOnline
$results = @()

foreach ($m in $mailboxes) {
    $newUPN = $m.UserPrincipalName.Split("@")[0] + "@" + $domain
    $aadUser = Get-AzureADUser -ObjectId $m.UserPrincipalName
    $mailbox = Get-Mailbox -Identity $m.UserPrincipalName
    #
    $userExport = New-Object -TypeName PSObject
    # Retrieve original values for Azure AD user / EXO Mailbox
    Add-Member -InputObject $userExport -MemberType NoteProperty -Name oldUPN -Value $mailbox.UserPrincipalName
    Add-Member -InputObject $userExport -MemberType NoteProperty -Name oldWindowsLiveID -Value $mailbox.WindowsLiveID
    Add-Member -InputObject $userExport -MemberType NoteProperty -Name oldMicrosoftOnlineServicesID -Value $mailbox.MicrosoftOnlineServicesID
    Add-Member -InputObject $userExport -MemberType NoteProperty -Name oldPrimarySmtpAddress -Value $mailbox.PrimarySmtpAddress
    Add-Member -InputObject $userExport -MemberType NoteProperty -Name oldWindowsEmailAddress -Value $mailbox.WindowsEmailaddress
    Add-Member -InputObject $userExport -MemberType NoteProperty -Name oldProxyAddresses -Value (($aadUser.ProxyAddresses) -join ";")
    Add-Member -InputObject $userExport -MemberType NoteProperty -Name oldSipProxyAddress -Value $aadUser.SipProxyAddress
    #

    Write-Host "[AAD] Changing UPN value from" $m.UserPrincipalName "->" $newUPN -ForegroundColor Yellow
    #Set-AzureADUser -ObjectId $m.UserPrincipalName -UserPrincipalName $newUPN
    Write-Host "Waiting 3s ..."
    Start-Sleep -Seconds 3

    Write-Host "[EXO] Changing PrimarySmtpAddress value from:" $mailbox.PrimarySMTPAddress "->" $newUPN -ForegroundColor Yellow
    #Set-Mailbox -Identity $mailbox.UserPrincipalName -MicrosoftOnlineServicesID $newUPN
    Write-Host "Waiting 3s ..."
    Start-Sleep -Seconds 3

    try {
        $aadUser = Get-AzureADUser -ObjectId $newUPN -ErrorAction Stop
    }
    catch {
        #$message = $_
        Write-Warning "Error locating AzureADUser using new UPN $newUPN"
    }

    try {
        $mailbox = Get-Mailbox -Identity $newUPN -ErrorAction Stop
    }
    catch {
        Write-Warning "Error locating Mailbox using new UPN $newUPN"
    }

    # Retrieve updated values for Azure AD user / EXO Mailbox
    Add-Member -InputObject $userExport -MemberType NoteProperty -Name newUPN -Value $mailbox.UserPrincipalName
    Add-Member -InputObject $userExport -MemberType NoteProperty -Name newWindowsLiveID -Value $mailbox.WindowsLiveID
    Add-Member -InputObject $userExport -MemberType NoteProperty -Name newMicrosoftOnlineServicesID -Value $mailbox.MicrosoftOnlineServicesID
    Add-Member -InputObject $userExport -MemberType NoteProperty -Name newPrimarySmtpAddress -Value $mailbox.PrimarySmtpAddress
    Add-Member -InputObject $userExport -MemberType NoteProperty -Name newWindowsEmailAddress -Value $mailbox.WindowsEmailaddress
    Add-Member -InputObject $userExport -MemberType NoteProperty -Name newProxyAddresses -Value (($aadUser.ProxyAddresses) -join ";")
    Add-Member -InputObject $userExport -MemberType NoteProperty -Name newSipProxyAddress -Value $aadUser.SipProxyAddress
    
    $results += $userExport
    
}

Write-Host "Exported results to $workDir\mailboxReport.csv"
$results | Export-Csv -Path $workDir\mailboxReport.csv -NoTypeInformation