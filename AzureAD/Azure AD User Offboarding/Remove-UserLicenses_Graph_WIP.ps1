function Remove-Licenses {
    param (
        [Parameter(Mandatory=$true)][string]$TenantID,
        [Parameter(Mandatory = $true)][string]$ClientID,
        [Parameter(Mandatory = $true)][string]$UserPrincipalName
    )

    # grab user cert
    $certName = [System.Environment]::UserName + "-" + [system.environment]::MachineName
    $certThumbprint = Get-ChildItem Cert:\CurrentUser\My\ | Where-Object { $_.Subject -like "*$certName*" } | Select-Object -ExpandProperty Thumbprint

    # Connect to MgGraph, if not already connected
    if ( $null -eq (Get-MgContext)) {
        Connect-MgGraph -TenantId $tenantID -ClientID $clientID -CertificateThumbprint $certThumbprint | Out-Null
    }

    Write-Output "[GRAPH] Processing licenses for user $($UserPrincipalName)..."
    $filter = "startsWith(UserPrincipalName,'" + $UserPrincipalName + "')"
    $user = Get-MgUser -Filter $filter -ErrorAction Stop 
    if ( $null -eq $user) {
        Write-Output "ERROR: Unable to find user"
        break # Stop if the user cannot be found
    }

    $SKUs = (Get-MgUserLicenseDetail -UserId $user.Id).SkuPartNumber
    $priorLicenses = @() # store all current licenses in a variable
    foreach ($SKU in $SKUs) { 
        $priorLicenses += $SKU # populate $priorLicenses
        Write-Output "[GRAPH] Removing license $($SKU) from user $($user.UserPrincipalName)"
        $skuId = (Get-MgSubscribedSku -All | Where SkuPartNumber -eq $SKU).SkuId
        Set-MgUserLicense -UserId $user.Id -AddLicenses @() -RemoveLicenses @($skuId) | Out-Null
    }
}