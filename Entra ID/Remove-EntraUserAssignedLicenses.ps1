function Remove-MgUserAssignedLicenses {

    param (
        [Parameter(Mandatory=$true)]
        [String]
        $userPrincipalName
    )

    try {
        $user = Get-MgUser -UserId $UserPrincipalName -Select UserPrincipalName,DisplayName,AssignedLicenses
    }
    catch {
        return "[Remove licenses] Skipped, user not found: $userPrincipalName"
    }
    $licensesToRemove = $user.AssignedLicenses | Select-Object -ExpandProperty SkuId
    if ( !($licensesToRemove) ) {
        return "[Remove licenses] Skipped, no licenses assigned to user: $userPrincipalName"
    }

    # Determine the friendly name for the SKU(s) being removed
    $skuMappingTable = Get-Microsoft365LicensesMappingTable
    $licensesToRemoveFriendly = @()
    foreach ($sku in $licensesToRemove) {
        $licensesToRemoveFriendly += ($skuMappingTable | Where-Object { $_.GUID -eq "$sku" } | Select-Object -expand DisplayName -Unique)
    }
    $removedLicenses = ($licensesToRemoveFriendly | Sort-Object) -join ', '

    try {
        $user = Set-MgUserLicense -UserId $user.UserPrincipalName -RemoveLicenses $licensesToRemove -AddLicenses @{} 
        Write-Output "[Remove licenses] Removed licenses from ${userPrincipalName}: $removedLicenses"
    } catch {
        Write-Output "[Remove licenses] Failed to remove licenses from $userPrincipalName. Error: $($_.Exception.Message)"
    }

}