<#
.SYNOPSIS
Clear the Entra ID user properties listed in $propsToClear. Primary purpose is offboarding

#>

function Clear-EntraUserProperties {
    param(
        [Parameter(Mandatory = $true)]
        [String]
        $UserPrincipalName
    )

    # Helper function
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
    $task = "Clear Entra user properties"
    $status = "Failure"
    $results = [System.Collections.Generic.List[System.Object]]::new()

    $userIdentifiers = @("UserPrincipalName", "Id")
    $propsToClear = @("JobTitle", "CompanyName", "Department", "StreetAddress", "City", "State", "PostalCode", "OfficeLocation", "MobilePhone", "Manager", "BusinessPhones")
    $userProps = $userIdentifiers + $propsToClear
    $clearedProperties = @{}

    try {
        $user = Get-MgUser -UserId $UserPrincipalName -Select $userProps -ErrorAction Stop
        foreach ( $prop in $propsToClear) {
            if ($prop -like "Manager") {
                # Switched from cmdlet to the HTTP method using -SkipHttpErrorCheck due to a limitation in CloudManager to fully suppress errors/warnings in a try-catch
                $manager = Invoke-MgGraphRequest -Method GET -Uri https://graph.microsoft.com/v1.0/users/$UserPrincipalName/manager -SkipHttpErrorCheck
                if ( $manager -and $manager.error ) {
                    # User does not have a manager. Suppress errors
                } else {
                    try {
                        Remove-MgUserManagerByRef -UserId $user.Id
                        $status = "Success"
                        $message = "Unassigned manager: $($manager.displayName)"
                        $errorMessage = $null
                        Add-TaskResult -Task $task -Status $status -Message $message
                    } catch {
                        $message = "Failed to remove $UserPrincipalName's manager: $($manager.displayName)"
                        $errorMessage = $_.Exception.Message
                        Add-TaskResult -Task $task -Status $status -Message $message -ErrorMessage $errorMessage
                    }
                }
            } elseif ( $user.$prop  ) {
                try {             
                    Invoke-MgGraphRequest -Method PATCH -Uri "https://graph.microsoft.com/v1.0/Users/$($user.Id)" -Body @{$prop = $null }
                    $clearedProperties.Add($Prop, $user.$Prop)
                } catch {
                    $message = "Failed to clear value of property: $prop"
                    $errorMessage = $_.Exception.Message
                    Add-TaskResult -Task $task -Status $status -Message $message -ErrorMessage $errorMessage
                }
            }
        }
        if ( $clearedProperties ) {
            $message = "Successfully cleared Entra user properties"
            $formattedDetails = ($clearedProperties.GetEnumerator() | ForEach-Object {
                    "$($_.Key): $($_.Value)"
                }) -join "`n"
            $errorMessage = $null
            Add-TaskResult -Task $task -Status $status -Message $message -ErrorMessage $errorMessage -Details $formattedDetails
        }
    } catch {
        $message = "Failed to locate Entra user: $UserPrincipalName. Please confirm the UserPrincipalName and try again"
        $errorMessage = $_.Exception.Message
        Add-TaskResult -Task $task -Status $status -Message $message -ErrorMessage $errorMessage
    }
    # Output 
    return $results
	
}