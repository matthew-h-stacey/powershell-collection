function Clear-EntraUserProperties {
    param(
        [Parameter(Mandatory = $true)]
        [String]
        $UserPrincipalName
    )

    # Clear the AzureAD user properties listed in $additionalProperties. Primary purpose is offboarding
    
    $requiredProperties = @("UserPrincipalName", "Id")
    $additionalProperties = @("JobTitle", "CompanyName", "Department", "StreetAddress", "City", "State", "PostalCode", "OfficeLocation", "MobilePhone", "Manager")
    $userProperties = $requiredProperties + $additionalProperties
    $clearedProperties = @{}

    $user = Get-MgUser -UserId $UserPrincipalName -Select $userProperties

    foreach ( $prop in $additionalProperties) {
        if ($prop -like "Manager") {
            try {
                $manager = Get-MgUserManager -UserId $user.Id -ErrorAction Stop -WarningAction Stop
                try {
                    Remove-MgUserManagerByRef -UserId $user.Id
                    Write-Output "[EntraID Properties] Unassigned manager: $($manager.additionalProperties.displayName)"
                } catch {
                    Write-Output "Failed to remove the user's manager. Error:"
                    $_.Exception.Message
                }
            } catch {
                # User does have a manager. Suppress errors
            }
        } elseif ( $user.$prop  ) {
            try {             
                Invoke-MgGraphRequest -Method PATCH -Uri "https://graph.microsoft.com/v1.0/Users/$($user.Id)" -Body @{$prop = $null }
                $clearedProperties.Add($Prop, $user.$Prop)
            } catch {
                Write-Output "Failed to clear value of property: $prop. Error:"
                Write-Output $_.Exception.Message
            }
        }
    }
    
    if ( $clearedProperties ) {
        Write-Output "[EntraID Properties] Cleared the following properties from the user:"
        $clearedProperties
    }
	
}