<#
.SYNOPSIS
Bulk change the PrimarySmtpAddress of distribution groups to use a new domain suffix. For example, after a domain name change or during a migration project

.EXAMPLE
Update-EXODistributionGroupPrimarySmtpAddress.ps1 -NewVanityDomain contoso.com -ExportPath C:\TempPath
#>

param(   
    # This is the new vanity domain to set on all distribution groups (ex: contoso.com)    
    [Parameter(Mandatory = $true)]
    [string]
    $NewVanityDomain,

    # Optionally provide the full path to a CSV instead of applying changes to all distribution groups. The CSV should use "PrimarySmtpAddress" as the header
    [Parameter(Mandatory = $false)]
    [string]
    $CSV,

    # Path to export results to
    [Parameter(Mandatory = $true)]
    [String]
    $ExportPath
)

$outputFile = "$($ExportPath.TrimEnd("\"))\distiReport.csv"
$results = New-Object System.Collections.Generic.List[System.Object]

if ( $CSV ) {
    if ( Test-Path $CSV ) {
        $distis = Import-Csv -Path $CSV | ForEach-Object { 
            $filter = "PrimarySmtpAddress -eq '" + $_.PrimarySmtpAddress + "'"
            Get-DistributionGroup -Filter $filter
        }
    } else {
        Write-Output "[ERROR] Failed to locate CSV at provided path. Please check the path and try again"
        exit 1
    }

} else {
    $distis = Get-DistributionGroup -ResultSize Unlimited
}

foreach ($disti in $distis) {

    # First check to see if the new vanity domain name has already been applied
    $currentPrimarySmtpAddress = $disti.PrimarySmtpAddress
    $changeRequired = $currentPrimarySmtpAddress.Split("@")[1] -ne $NewVanityDomain
    if ( $changeRequired ) {
        # Remove old domain, append new domain
        $newPrimarySmtpAddress = $currentPrimarySmtpAddress.Split("@")[0] + "@" + $NewVanityDomain
        # Retrieve original values for disti and store in a custom object
        $groupOutput = [ordered]@{
            oldPrimarySmtpAddress  = $currentPrimarySmtpAddress
            oldWindowsEmailAddress = $disti.WindowsEmailAddress
            oldEmailAddresses      = ($disti.EmailAddresses) -join ";"
        }
        try {
            Set-DistributionGroup -Identity $currentPrimarySmtpAddress -PrimarySmtpAddress $newPrimarySmtpAddress
            Write-Output "[INFO] Changed PrimarySmtpAddress value from: $currentPrimarySmtpAddress -> $newPrimarySmtpAddress"
            try {
                $distiUpdated = Get-DistributionGroup -Identity $newPrimarySmtpAddress -ErrorAction Stop
            } catch {
                Write-Output "[ERROR] Unable to locate Distribution Group using new PrimarySmtpAddress $newPrimarySmtpAddress"
            }
            # Retrieve updated values for disti
            $groupOutput["newPrimarySmtpAddress"] = $distiUpdated.PrimarySmtpAddress
            $groupOutput["newWindowsEmailAddress"] = $distiUpdated.WindowsEmailAddress
            $groupOutput["newEmailAddresses"] = ($distiUpdated.EmailAddresses) -join ";"
            $results.Add([PSCustomObject]$groupOutput) 
        } catch {
            Write-Output "[ERROR] Failed to update PrimarySmtpAddress. Error: $($_.Exception.Message)"
        }
    } else {
        Write-Output "[INFO] $currentPrimarySmtpAddress - PrimarySmtpAddress is already set to the new vanity domain name"
    }
}

if ( $results ) { 
    $results | Export-Csv -Path $outputFile -NoTypeInformation
    Write-Host "[INFO] Exported results to $outputFile"
}