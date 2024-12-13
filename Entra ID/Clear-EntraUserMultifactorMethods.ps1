function Clear-EntraUserMultifactorMethods {

    param(
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
    $task = "Clear MFA methods"
    $status = "Failure"
    $results = [System.Collections.Generic.List[System.Object]]::new()

    Get-MgUserAuthenticationEmailMethod -UserID $UserPrincipalName | ForEach-Object {
        try {
            Remove-MgUserAuthenticationEmailMethod -UserId $UserPrincipalName -EmailAuthenticationMethodId $_.Id
            $status = "Success"
            $message = "Removed user MFA method: email"
            $errorMessage = $null
            $Details = $_.EmailAddress
            Add-TaskResult -Task $task -Status $status -Message $message -ErrorMessage $errorMessage -Details $details
        }
        catch {
            $message = "Failed to remove one or more user MFA authentication methods (email)"
            $errorMessage = $_.Exception.Message
            Add-TaskResult -Task $task -Status $status -Message $message -ErrorMessage $errorMessage
        }
    }
    Get-MgUserAuthenticationPhoneMethod -UserID $UserPrincipalName | ForEach-Object {
        try {
            Remove-MgUserAuthenticationPhoneMethod -UserID $UserPrincipalName -PhoneAuthenticationMethodId $_.Id
            $status = "Success"
            $message = "Removed user MFA method: phone number"
            $errorMessage = $null
            $Details = $_.PhoneNumber
            Add-TaskResult -Task $task -Status $status -Message $message -ErrorMessage $errorMessage -Details $details
        } catch {
            $message = "Failed to remove one or more user MFA authentication methods (phone)"
            $errorMessage = $_.Exception.Message
            Add-TaskResult -Task $task -Status $status -Message $message -ErrorMessage $errorMessage
        }
    }
    Get-MgUserAuthenticationMicrosoftAuthenticatorMethod -UserID $UserPrincipalName |  ForEach-Object {
        try {
            Remove-MgUserAuthenticationMicrosoftAuthenticatorMethod -UserID $UserPrincipalName -MicrosoftAuthenticatorAuthenticationMethodId $_.Id
            $status = "Success"
            $message = "Removed user MFA method: Microsoft MFA"
            $errorMessage = $null
            $Details = $_.DisplayName
            Add-TaskResult -Task $task -Status $status -Message $message -ErrorMessage $errorMessage -Details $details
        } catch {
            $message = "Failed to remove one or more user MFA authentication methods (Microsoft MFA)"
            $errorMessage = $_.Exception.Message
            Add-TaskResult -Task $task -Status $status -Message $message -ErrorMessage $errorMessage
        }
    }

    # Output 
    return $results

}