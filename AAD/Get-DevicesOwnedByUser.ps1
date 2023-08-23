Param(
    [Parameter(Mandatory = $True)][string]$UserPrincipalName
)

# Store all device objects in a variable for querying
$allDevices = Get-AzureADDevice -All $true


$results = @()
Write-Host "Checking for all devices owned by $($UserPrincipalName) ..."
foreach ( $d in $allDevices ) { 
    if (((Get-AzureADDeviceRegisteredOwner -ObjectId $d.ObjectId)).UserPrincipalName -eq $UserPrincipalName) {  # if the owner of device matches the UPN, add device name to results array
        $objExport = [PSCustomObject]@{
            Device = $d.DisplayName
            LastApproxLogon = $d.ApproximateLastLogonTimeStamp
        }
        $results += $objExport
    }
}

Write-Host "$($UserPrincipalName) owns the following $($results.Length) devices:" -BackgroundColor DarkGreen
$results | Sort-Object DisplayName
