function Get-AzureADLicense {
    param(
    )
    
    # Example usage:
    <#
    $ClientName = (Get-CustomerContext).CustomerName

    Write-Output "[INFO] ${ClientName}: Checking the license of the Azure AD tenant"
    try {
        $AzureADLicense = Get-AzureADLicense
    }
    catch {
        Write-Output "[ERROR] Encountered error while checking the license of the Azure AD tenant. Error:"
        throw $_.Exception.Message
    }

    if ( $AzureADLicense.Premium -eq $true ) {
        Write-Output "[INFO] $ClientName has Azure AD Premium. Continuing ..."
        if ( $AzureADLicense.License.Contains("P1")) {
            Write-Output "[INFO] $ClientName has Azure AD Premium P1"
            # do Premium P1 stuff here ...
        }
        if ( $AzureADLicense.License.Contains("P2")) {
            Write-Output "[INFO] $ClientName has Azure AD Premium P2"
            # do Premium P2 stuff here ...
        }
    } else {
        Write-Output "[SKIPPED] $ClientName does not have Azure AD Premium."
        # skip, or do something for non-Azure AD Premium clients here?
    }
    #>

    # Table of all Microsoft SKUs and their associated SKU name and display name
    $SkuIDtoNameTable = Get-Microsoft365ServicePlans -OnlyMappingTable

    # Organization pulled via Graph
    $MgOrganization = Get-MgOrganization -ErrorAction Stop

    $ActiveSkus = $MgOrganization.AssignedPlans | Where-Object { $_.CapabilityStatus -in @("Enabled", "Warning") } | Select-Object -ExpandProperty ServicePlanId
    $ActivePlans = $SkuIDtoNameTable | Where-Object { $_.Id -in $ActiveSkus } | Select-Object -ExpandProperty DisplayName | Sort-Object

    if ( ($ActivePlans -contains "Microsoft Entra ID P1") -and ($ActivePlans -contains "Microsoft Entra ID P2") ) {
        $AzureADPremiumActive = $true
        $AzureADLicense = "Microsoft Entra ID P2"
    }
    elseif ( ($ActivePlans -contains "Microsoft Entra ID P1") -and ($ActivePlans -notcontains "Microsoft Entra ID P2") ) {
        $AzureADPremiumActive = $true
        $AzureADLicense = "Microsoft Entra ID P1"
    } 
    elseif ( ($ActivePlans -notcontains "Microsoft Entra ID P1") -and ($ActivePlans -notcontains "Microsoft Entra ID P2") ) {
        $AzureADPremiumActive = $false
        $AzureADLicense = "N/A"
    }

    $results = [PSCustomObject]@{
        Premium   =   $AzureADPremiumActive
        License  =   $AzureADLicense
    }

    return $results

}