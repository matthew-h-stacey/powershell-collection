function Remove-EntraUserAssignedLicenses {

    param (
        [Parameter(Mandatory=$true)]
        [String]
        $UserPrincipalName
    )

    function Add-TaskResult {
        param(
            [string]$Task,
            [string]$Status,
            [string]$Message,
            [string]$ErrorMessage = $null,
            [string]$Details = $null
        )
        $results.Add([PSCustomObject]@{
            FunctionName = $function
            Task         = $Task
            Status       = $Status
            Message      = $Message
            Details      = $Details
            ErrorMessage = $ErrorMessage
        })
    }

    # Initialize output variables
    $function = $MyInvocation.MyCommand.Name
    $task = "Remove assigned licenses"
    $status = "Failure"
    $results = [System.Collections.Generic.List[System.Object]]::new()

    try {
        $user = Get-MgUser -UserId $UserPrincipalName -Select UserPrincipalName,DisplayName,AssignedLicenses -ErrorAction Stop
        $licensesToRemove = $user.AssignedLicenses | Select-Object -ExpandProperty SkuId
        if ( $licensesToRemove ) {
            # Determine the friendly name for the SKU(s) being removed
            try {
                $skuMappingTable = Get-Microsoft365LicensesMappingTable
                $licensesToRemoveFriendly = @()
                foreach ($sku in $licensesToRemove) {
                    $licensesToRemoveFriendly += ($skuMappingTable | Where-Object { $_.GUID -eq "$sku" } | Select-Object -expand DisplayName -Unique)
                }
                $removedLicenses = ($licensesToRemoveFriendly | Sort-Object) -join ', '
                # Attempt to remove the assigned licenses
                try {
                    $user = Set-MgUserLicense -UserId $user.UserPrincipalName -RemoveLicenses $licensesToRemove -AddLicenses @{} 
                    $status = "Success"
                    $message = "Removed licenses from ${userPrincipalName}: $removedLicenses"
                    $errorMessage = $null
                } catch {
                    $status = "Failure"
                    $message = "Failed to remove licenses from $UserPrincipalName" 
                    $errorMessage = $_.Exception.Message
                }
            } catch {
                $status = "Failure"
                $message = "Failed to locate Microsoft 365 SKU mapping table"
            }
        } else {
            $status = "Skipped"
            $message = "No licenses assigned to user: $UserPrincipalName"            
        }
    } catch {
        $status = "Skipped"
        $message = "User not found: $UserPrincipalName"
    }
    
    # Output
    Add-TaskResult -Task $task -Status $status -Message $message -ErrorMessage $errorMessage -Details $details
    return $results

}