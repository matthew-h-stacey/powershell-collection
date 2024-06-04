<#
.SYNOPSIS
Bulk change the PrimarySmtpAddress of distribution groups to use a new domain suffix. For example, after a domain name change, during a migration project

.EXAMPLE
Update-EXODistributionGroupPrimarySmtpAddress.ps1 -NewVanityDomain contoso.com -ExportPath C:\TempPath
#>

param(   
    # This is the new vanity domain to set on all mailboxes (ex: contoso.com)    
    [Parameter(Mandatory = $true)]
    [string]
    $NewVanityDomain,

    # Path to export results to
    [Parameter(Mandatory = $true)]
    [String]
    $ExportPath
)

$ExportPath = $($ExportPath.TrimEnd("\")) # trim trailing "\""
$distis = Get-DistributionGroup -ResultSize Unlimited

$results = New-Object System.Collections.Generic.List[System.Object]
foreach ($disti in $distis) {

    # First check to see if the new vanity domain name has already been applied
    $changeRequired = $disti.PrimarySmtpAddress.Split("@")[1] -ne $NewVanityDomain
    if ( $changeRequired ) {
        # Remove old domain, append new domain
        $newPrimarySmtpAddress = $disti.PrimarySmtpAddress.Split("@")[0] + "@" + $NewVanityDomain
        # Retrieve original values for disti and store in a custom object
        $groupOutput = [ordered]@{
            oldPrimarySmtpAddress  = $disti.PrimarySmtpAddress
            oldWindowsEmailAddress = $disti.WindowsEmailAddress
            oldEmailAddresses      = ($disti.EmailAddresses) -join ";"
        }
        Write-Output "[INFO] Changing PrimarySmtpAddress value from: $($disti.PrimarySMTPAddress) -> $newPrimarySmtpAddress"
        try {
            Set-DistributionGroup -Identity $disti.PrimarySmtpAddress -PrimarySmtpAddress $newPrimarySmtpAddress
            try {
                $disti = Get-DistributionGroup -Identity $newPrimarySmtpAddress -ErrorAction Stop
            } catch {
                Write-Output "[ERROR] Unable to locate Distribution Group using new PrimarySmtpAddress $newPrimarySmtpAddress"
            }
            # Retrieve updated values for disti
            $groupOutput["newPrimarySmtpAddress"] = $disti.PrimarySmtpAddress
            $groupOutput["newWindowsEmailAddress"] = $disti.WindowsEmailAddress
            $groupOutput["newEmailAddresses"] = ($disti.EmailAddresses) -join ";"
            $results.Add([PSCustomObject]$groupOutput) 
        } catch {
            Write-Output "[ERROR] Failed to update PrimarySmtpAddress. Error: $($_.Exception.Message)"
        }
    }
}

if ( $results ) { 
    $results | Export-Csv -Path $ExportPath\distiReport.csv -NoTypeInformation
    Write-Host "[INFO] Exported results to $ExportPath\distiReport.csv"
}