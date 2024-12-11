function Disable-EntraUserAccount {

    param(
        [Parameter(Mandatory = $True)]
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
    $task = "Disable Entra user account"
    $status = "Failure"
    $results = [System.Collections.Generic.List[System.Object]]::new()

    try {
        $params = @{  
            AccountEnabled = "false"
        }  
        Update-MgUser -UserId $UserPrincipalName -BodyParameter $params            
        $status = "Success"
        $message = "Disabled account: $UserPrincipalName"
        $errorMessage = $null
    } catch {
        $message = "Error occurred attempting to disable account"
        $errorMessage = $_.Exception.Message
    }

    # Output
    Add-TaskResult -Task $task -Status $status -Message $message -ErrorMessage $errorMessage
    return $results

}