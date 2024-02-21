function Add-AzureADUserLicense {
    param (
        [SkyKickParameter(
            DisplayName = "UserPrincipalName",    
            Section = "Basic Details",
            DisplayOrder = 3,
            HintText = "Enter the desired UserPrincipalName, or username for the user (ex: jsmith@contoso.com)."
        )]
        [ValidatePattern(
            "([a-zA-Z0-9._-]+@[a-zA-Z0-9._-]+\.[a-zA-Z0-9_-]+)",
            ErrorMessage = "User Principal Name contains invalid characters or has invalid format."
        )]
        [Parameter (Mandatory = $true)]
        [String]$UserPrincipalName,

        [ArgumentCompleter({
                param ($CommandName, $ParameterName, $WordToComplete, $CommandAst, $FakeBoundParameters)
                # Getting all license SKUs available in tenant and mapping table for display names.
                $SKUsInTenant = Get-MgSubscribedSku -All
                $SKUsMappingTable = Get-Microsoft365LicensesMappingTable # SKU to friendly name table

                $SKUsToComplete = $SKUsInTenant
                | Where-Object {
                    (([int]$_.PrepaidUnits.Enabled - [int]$_.ConsumedUnits) -gt 0) -and
                    ($_.SkuId -notin $SKUsAssignedToUser)
                }

                # Constructing new SKU objects with DisplayName. This is needed for proper sorting
                $SKUsToCompleteWithName = @()

                foreach ($SKU in $SKUsToComplete) {
                    $SKUDisplayName = $SKUsMappingTable | Where-Object { $_.GUID -eq $SKU.SkuId } | Select-Object -ExpandProperty DisplayName
                    $SKUsToCompleteWithName += [PSCustomObject][ordered] @{
                        SkuId         = $SKU.SkuId
                        DisplayName   = $SKUDisplayName
                        AllUnits      = $SKU.PrepaidUnits.Enabled
                        ConsumedUnits = $SKU.ConsumedUnits
                    }
                }

                $SKUsToCompleteWithName = $SKUsToCompleteWithName | Sort-Object -Property DisplayName
            
                # Creating completion results with calculated available licenses count
                foreach ($SKU in $SKUsToCompleteWithName) {
                    $AvailableLicenses = [int]$SKU.AllUnits - [int]$SKU.ConsumedUnits
                    if ($AvailableLicenses -eq 1) {
                        $AvailableLicensesStr = "$AvailableLicenses available license"
                    }
                    else {
                        $AvailableLicensesStr = "$AvailableLicenses available licenses"
                    }
                    New-SkyKickCompletionResult -Value $SKU.SkuId -DisplayName "$($SKU.DisplayName) ($AvailableLicensesStr)"
                }
            })]
        [SkyKickParameter(
            DisplayName = "Add Licenses",
            HintText = "Select Licenses you want to assign to the user or group. Already assigned Licenses and Licenses with not enough units available will not be listed here.",
            Section = "Assign Licenses",
            DisplayOrder = 1
        )]
        [Parameter (Mandatory = $false)]
        [String[]]$AddLicenses
    )

    ###

    $MgUser = Get-MgUser -UserId $UserPrincipalName

    # Build an array of SKUs from the GUI input
    $AddLicensesConstructed = @() 
    foreach ($SKU in $AddLicenses) {
        $AddLicensesConstructed += @{
        SkuId = $SKU
        }
    }

    $ConfigParams = @{
        UserID         = $MgUser.Id
        AddLicenses    = $AddLicensesConstructed
        RemoveLicenses = @()
        ErrorAction    = "Stop"
    }

    try {
        Set-MgUserLicense @ConfigParams | Out-Null
        Write-Host "License management action was performed successfully." -ForegroundColor Green
    }
    catch {
        $ExceptionMessage = $_.Exception.Message
        Write-Host "License management action failed." 
        if ($ExceptionMessage -like "License assignment failed because service plan * depends on the service plan(s)*") {
            Write-Host "One of the products contains a service plan that must be enabled for another service plan, in another product, to function. Make sure that the user or group have necessary services before adding or removing a dependent service." -ForegroundColor Red
        }
        Write-Host "Original error message: $ExceptionMessage`n"
    }
    
}
