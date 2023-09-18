function Clear-AzureADUserProperties {
    param(
        [Parameter(Mandatory=$true)]
        [String]
        $UserPrincipalName
    )

    # Clear the AzureAD user properties listed in $AdditionalProperties. Primary purpose is offboarding
    
    $RequiredProperties = @("UserPrincipalName","Id")
    $AdditionalProperties = @("JobTitle","CompanyName","Department","StreetAddress","City","State","PostalCode","OfficeLocation","MobilePhone","Manager")
    $UserProperties = $RequiredProperties + $AdditionalProperties
    $ClearedProperties = @{}

    $User = Get-MgUser -UserId $UserPrincipalName -Select $UserProperties

    foreach ( $prop in $AdditionalProperties) {
        if ($prop -like "Manager") {
            try {
                $Manager = Get-MgUserManager -UserId $User.Id -ErrorAction Stop -WarningAction Stop
                try {
                    Remove-MgUserManagerByRef -UserId $User.Id
                    Write-Output "[AADProperties] Unassigned manager: $($Manager.AdditionalProperties.displayName)"
                }
                catch {
                    Write-Output "Failed to remove the user's manager. Error:"
                    $_.Exception.Message
                }
            }
            catch {
                # User does have a manager. Suppress errors
            }
            
        }
        elseif ( $User.$prop  ) {
            try {
                $ClearedProperties.Add($Prop, $User.$Prop)                
                Invoke-MgGraphRequest -Method PATCH -Uri "https://graph.microsoft.com/v1.0/Users/$($User.Id)" -Body @{$prop = $null}
            }
            catch {
                Write-Output "Failed to clear value of property: $prop. Error:"
                Write-Output $_.Exception.Message
            }
        }
    }
    
    if ( $ClearedProperties ) {
        Write-Output "[AADProperties] Cleared the following properties from the user:"
        $ClearedProperties
    }
	
}