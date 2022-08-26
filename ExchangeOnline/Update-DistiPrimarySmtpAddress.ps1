# Objective: Bulk change the PrimarySmtpAddress of distribution groups to use a new domain suffix
# ex: After 365 -> 365 migration cutover, distribution groups need to have the PrimarySmtpAddress changed from contoso.onmicrosoft.com -> contoso.com
# This script is intended for distribution groups. For mailboxes, see Update-UPNandPrimarySmtpAddress.ps1

Param
(   
    [Parameter(Mandatory = $true)] [string] $domain # this is the new vanity domain to set on all mailboxes (ex: contoso.com)
)

$workDir = "C:\TempPath" # place csv here, retrieve output report from here later
$distis = Import-Csv C:\TempPath\distis.csv # use a CSV file with header "PrimarySmtpAddress." Should contain ALL distis (with the current or 'old' domain) that need to be changed to the new domain


Write-Host "Connecting to ExchangeOnline, check for a pop-up authentication window"
Connect-ExchangeOnline -ShowBanner:$False

$results = @()

foreach ($d in $distis) {
    $newPrimarySmtpAddress = $d.PrimarySmtpAddress.Split("@")[0] + "@" + $domain    # remove old domain, append new domain
    $disti = Get-DistributionGroup -Identity $d.PrimarySmtpAddress                  # retrieve the current disti
    
    # Retrieve original values for disti and store in a custom object
    $groupExport = New-Object -TypeName PSObject       
    Add-Member -InputObject $groupExport -MemberType NoteProperty -Name oldPrimarySmtpAddress -Value $disti.PrimarySmtpAddress
    Add-Member -InputObject $groupExport -MemberType NoteProperty -Name oldWindowsEmailAddress -Value $disti.WindowsEmailAddress
    Add-Member -InputObject $groupExport -MemberType NoteProperty -Name oldEmailAddresses -Value (($disti.EmailAddresses) -join ";")
    #

    Write-Host "[EXO] Changing PrimarySmtpAddress value from:" $disti.PrimarySMTPAddress "->" $newPrimarySmtpAddress -ForegroundColor Yellow
    Set-DistributionGroup -Identity $disti.PrimarySmtpAddress -PrimarySmtpAddress $newPrimarySmtpAddress
    Write-Host "[INFO] Waiting 3s ..."
    Start-Sleep -Seconds 3

    try {
        $disti = Get-DistributionGroup -Identity $newPrimarySmtpAddress -ErrorAction Stop
    }
    catch {
        Write-Warning "Error locating Distribution Group using new PrimarySmtpAddress $newPrimarySmtpAddress"
    }

    # Retrieve updated values for disti
    Add-Member -InputObject $groupExport -MemberType NoteProperty -Name newPrimarySmtpAddress -Value $disti.PrimarySmtpAddress
    Add-Member -InputObject $groupExport -MemberType NoteProperty -Name newWindowsEmailAddress -Value $disti.WindowsEmailAddress
    Add-Member -InputObject $groupExport -MemberType NoteProperty -Name newEmailAddresses -Value (($disti.EmailAddresses) -join ";")
    
    $results += $groupExport
    
}

$results | Export-Csv -Path $workDir\distiReport.csv -NoTypeInformation
Write-Host "Exported results to $workDir\distiReport.csv"

Disconnect-ExchangeOnline -Confirm:$False