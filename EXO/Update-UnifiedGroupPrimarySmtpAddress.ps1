# Objective: Bulk change the PrimarySmtpAddress of UnifiedGgroup to use a new domain suffix
# ex: After 365 -> 365 migration cutover, UnifiedGgroup need to have the PrimarySmtpAddress changed from contoso.onmicrosoft.com -> contoso.com
# This script is intended for UnifiedGgroup only

Param
(   
    [Parameter(Mandatory = $true)] [string] $domain # this is the new vanity domain to set on all mailboxes (ex: contoso.com)
)

$workDir = "C:\TempPath" # place csv here, retrieve output report from here later
$groups = Import-Csv C:\TempPath\unifiedgroups.csv # use a CSV file with header "PrimarySmtpAddress." Should contain ALL groups (with the current or 'old' domain) that need to be changed to the new domain

# Check if already connected to ExchangeOnline, connect if not connected
$isConnected = Get-PSSession | Where-Object { $_.Name -like "ExchangeOnlineInternalSession*" -and $_.Availability -like "Available" }

if ($null -eq $isConnected) {
    Write-Host "Connecting to ExchangeOnline, check for a pop-up authentication window"
    Connect-ExchangeOnline -ShowBanner:$False
}

$results = @()

foreach ($g in $groups) {
    $currentAddress = $g.PrimarySmtpAddress
    $newPrimarySmtpAddress = $g.PrimarySmtpAddress.Split("@")[0] + "@" + $domain        # remove old domain, append new domain

    $group = get-unifiedgroup -filter "PrimarySmtpAddress -eq '$currentAddress'"   # retrieve the current group
    
    # Retrieve original values for group and store in a custom object
    $groupExport = New-Object -TypeName PSObject       
    Add-Member -InputObject $groupExport -MemberType NoteProperty -Name oldPrimarySmtpAddress -Value $group.PrimarySmtpAddress
    Add-Member -InputObject $groupExport -MemberType NoteProperty -Name oldEmailAddresses -Value (($group.EmailAddresses) -join ";")
    #

    # Change the PrimarySmtpAddress
    Write-Host "[EXO] Changing PrimarySmtpAddress value from:" $group.PrimarySmtpAddress "->" $newPrimarySmtpAddress -ForegroundColor Yellow
    Set-UnifiedGroup -Identity $currentAddress -PrimarySmtpAddress $newPrimarySmtpAddress
    Write-Host "[INFO] Waiting 3s ..."
    Start-Sleep -Seconds 3

    try {
        $group = Get-UnifiedGroup -Identity $newPrimarySmtpAddress -ErrorAction Stop
        Write-host "[EXO] Successfully renamed group: $($group.DisplayName)" -ForegroundColor Green
    }
    catch {
        Write-Warning "Error locating UnifiedGroup using new PrimarySmtpAddress $newPrimarySmtpAddress"
    }

    # Retrieve updated values for group
    Add-Member -InputObject $groupExport -MemberType NoteProperty -Name newPrimarySmtpAddress -Value $group.PrimarySmtpAddress
    Add-Member -InputObject $groupExport -MemberType NoteProperty -Name newEmailAddresses -Value (($group.EmailAddresses) -join ";")
    
    $results += $groupExport
    
}

$results | Export-Csv -Path $workDir\unifiedgroupReport.csv -NoTypeInformation
Write-Host "Exported results to $workDir\unifiedgroupReport.csv"

Disconnect-ExchangeOnline -Confirm:$False