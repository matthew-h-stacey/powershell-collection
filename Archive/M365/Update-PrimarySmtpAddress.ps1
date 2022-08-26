# Created by MHS

# Objective: Bulk change the PrimarySmtpAddress of distribtuion groups to use a new domain
# ex: After 365 cutover, distribtuion groups need to have the PrimarySmtpAddress changed from contoso.onmicrosoft.com -> contoso.com
# This script is intended for distribution groups. For mailboxes, see Update-UPNandPrimarySmtpAddress.ps1


$output = "C:\TempPath" # place csv here, retrieve output report from here later
$domain = "easterlyfunds.com" # set to the vanity/intended domain name
$distis = Import-Csv C:\TempPath\distis.csv # use a CSV file with header "UserPrincipalName" - should contain ALL users that need to be changed to the new domain


Write-Host "Connecting to ExchangeOnline, check for a pop-up authentication window"
Connect-ExchangeOnline

$results = @()

foreach ($d in $distis) {
    $newPrimarySmtpAddress = $d.PrimarySmtpAddress.Split("@")[0] + "@" + $domain
    $disti = Get-DistributionGroup -Identity $d.PrimarySmtpAddress
    #
    $groupExport = New-Object -TypeName PSObject
    # Retrieve original values for Azure AD user / EXO Mailbox
    Add-Member -InputObject $groupExport -MemberType NoteProperty -Name oldPrimarySmtpAddress -Value $disti.PrimarySmtpAddress
    Add-Member -InputObject $groupExport -MemberType NoteProperty -Name oldWindowsEmailAddress -Value $disti.WindowsEmailAddress
    Add-Member -InputObject $groupExport -MemberType NoteProperty -Name oldEmailAddresses -Value (($disti.EmailAddresses) -join ";")
    #

    Write-Host "[EXO] Changing PrimarySmtpAddress value from:" $disti.PrimarySMTPAddress "->" $newPrimarySmtpAddress -ForegroundColor Yellow
    #Set-DistributionGroup -Identity $disti.PrimarySmtpAddress -PrimarySmtpAddress $newPrimarySmtpAddress
    Write-Host "Waiting 3s ..."
    Start-Sleep -Seconds 3

    try {
        $disti = Get-DistributionGroup -Identity $newPrimarySmtpAddress -ErrorAction Stop
    }
    catch {
        Write-Warning "Error locating Distribution Group using new PrimarySmtpAddress $newPrimarySmtpAddress"
    }

    # Retrieve updated values for Azure AD user / EXO Mailbox
    Add-Member -InputObject $groupExport -MemberType NoteProperty -Name newPrimarySmtpAddress -Value $disti.PrimarySmtpAddress
    Add-Member -InputObject $groupExport -MemberType NoteProperty -Name newWindowsEmailAddress -Value $disti.WindowsEmailAddress
    Add-Member -InputObject $groupExport -MemberType NoteProperty -Name newEmailAddresses -Value (($disti.EmailAddresses) -join ";")
    
    $results += $groupExport
    
}

Write-Host "Exported results to $output\distiReport.csv"
$results | Export-Csv -Path $output\distiReport.csv -NoTypeInformation