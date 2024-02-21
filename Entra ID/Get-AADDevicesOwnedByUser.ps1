<#
.SYNOPSIS
	Return a list of all Azure AD devices owned by a user.

.DESCRIPTION
	This script uses the output of Get-AzureADDeviceRegisteredOwner to query for all devices owned by a specific user, and exports both the name of the device and last approximate logon of that device.

.PARAMETER UserPrincipalName
	The UserPrincipalName of the user to do the device ownership lookup for.

.EXAMPLE
	Get-AADDevicesOwnedByUser.ps1 -UserPrincipalName jsmith@contoso.com

.NOTES
	Author: Matt Stacey
	Date:   March 28, 2023
	Tags: 	
#>

Param(
    [Parameter(Mandatory = $True)][string]$UserPrincipalName
)

# Store all device objects in a variable for querying
$allDevices = Get-AzureADDevice -All $true

$results = @()
Write-Host "Checking for all devices owned by $($UserPrincipalName) ..."
foreach ( $device in $allDevices ) { 
    if (((Get-AzureADDeviceRegisteredOwner -ObjectId $device.ObjectId)).UserPrincipalName -eq $UserPrincipalName) {  # if the owner of device matches the UPN, add device name to results array
        $objExport = [PSCustomObject]@{
            Device = $device.DisplayName
            LastApproxLogon = $device.ApproximateLastLogonTimeStamp
        }
        $results += $objExport
    }
}

Write-Host "$($UserPrincipalName) owns the following $($results.Length) devices:" -BackgroundColor DarkGreen
$results | Sort-Object DisplayName
