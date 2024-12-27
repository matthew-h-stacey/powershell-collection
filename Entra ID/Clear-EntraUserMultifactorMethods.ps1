function Clear-EntraUserMultifactorMethods {

    <#
    .SYNOPSIS
    Clear all registered MFA methods from an Entra user

    .DESCRIPTION
    Uses the Microsoft Graph API to detect and remove all MFA methods (ex: MS Authenticator, SMS, etc.) from an Entra user.
    This is particularly relevant when combined in a larger user offboarding script

    .PARAMETER UserPrincipalName
    The user to clear all registered MFA methods from 

    .NOTES
    There are two limitations of the API that this script attempts to navigate. The first is that the API will error out 
    attempting to remove the user's default MFA method if there are others present, and state one of the other methods needs
    to be made default first. The second is that there is no method to query the default MFA method. As a result, this script
    loops through all MFA methods, notates which method fails to be removed because it is default, then attempts it again
    at the end.
    #>

    param(
        [Parameter(Mandatory=$true)]
        [string]
        $UserPrincipalName
    )

    function Remove-EntraMfaAuthMethod {

        <#
        .PARAMETER UserId
        The Id (ex: UserPrincipalName) of a user to delete MFA methods from

        .PARAMETER Method
        An object returned from Get-MgUserAuthenticationMethod with an Id and other relevant properties

        .NOTES
        Heavily inspired by https://github.com/orgs/msgraph/discussions/55
        #>

        param ( 
            [Parameter(Mandatory = $true)]
            [string]
            $UserId,

            [Parameter(Mandatory = $true)]
            [object]
            $Method
        )

        switch ($Method.AdditionalProperties['@odata.type']) {
            '#microsoft.graph.fido2AuthenticationMethod' { 
                # Remove fido2AuthenticationMethod
                $methodString = "fido2"
                try {
                    Remove-MgUserAuthenticationFido2Method -UserId $UserId -Fido2AuthenticationMethodId $Method.Id | Out-Null
                    $status = "Success"
                    $message = "Removed user MFA method: $methodString"
                    $errorMessage = $null
                } catch {
                    if ( $errorDetails.Message -like "*matches the user's current default authentication method, and cannot be deleted until the default authentication method is changed*" ) {
                        $script:defaultMfaMethod = $Method
                        $status = "Warning"
                        $message = "Attempted to remove the user's default MFA method ($methodString) while others still exist. This will be re-attempted after other methods are removed and can be safely ignored if the second removal is successful."
                    } else {
                        $message = "Failed to remove one or more user MFA authentication methods ($methodString)"
                        $errorMessage = $_.Exception.Message
                    }
                }
                Add-TaskResult -Task $task -Status $status -Message $message -ErrorMessage $errorMessage -Details $details
            }
            '#microsoft.graph.emailAuthenticationMethod' {
                # Remove emailAuthenticationMethod
                $methodString = "email"
                try {
                    Remove-MgUserAuthenticationEmailMethod -UserId $UserId -EmailAuthenticationMethodId $Method.Id | Out-Null
                    $status = "Success"
                    $message = "Removed user MFA method: $methodString"
                    $errorMessage = $null
                    $Details = $Method.AdditionalProperties.emailAddress
                } catch {
                    if ( $errorDetails.Message -like "*matches the user's current default authentication method, and cannot be deleted until the default authentication method is changed*" ) {
                        $script:defaultMfaMethod = $Method
                        $status = "Warning"
                        $message = "Attempted to remove the user's default MFA ($methodString) method while others still exist. This will be re-attempted after other methods are removed and can be safely ignored if the second removal is successful."
                    } else {
                        $message = "Failed to remove one or more user MFA authentication methods ($methodString)"
                        $errorMessage = $_.Exception.Message
                    }
                }
                Add-TaskResult -Task $task -Status $status -Message $message -ErrorMessage $errorMessage -Details $details
            }
            '#microsoft.graph.microsoftAuthenticatorAuthenticationMethod' { 
                # Remove microsoftAuthenticatorAuthenticationMethod
                $methodString = "Microsoft Authenticator"
                try {
                    Remove-MgUserAuthenticationMicrosoftAuthenticatorMethod -UserId $UserId -MicrosoftAuthenticatorAuthenticationMethodId $Method.Id | Out-Null
                    $status = "Success"
                    $message = "Removed user MFA method: $methodString"
                    $errorMessage = $null
                    $Details = $Method.AdditionalProperties.displayName
                } catch {
                    if ( $errorDetails.Message -like "*matches the user's current default authentication method, and cannot be deleted until the default authentication method is changed*" ) {
                        $script:defaultMfaMethod = $Method
                        $status = "Warning"
                        $message = "Attempted to remove the user's default MFA method ($methodString) while others still exist. This will be re-attempted after other methods are removed and can be safely ignored if the second removal is successful."
                    } else {
                        $message = "Failed to remove one or more user MFA authentication methods ($methodString)"
                        $errorMessage = $_.Exception.Message
                    }
                }
                Add-TaskResult -Task $task -Status $status -Message $message -ErrorMessage $errorMessage -Details $details
            }
            '#microsoft.graph.phoneAuthenticationMethod' { 
                # Remove phoneAuthenticationMethod
                $methodString = "SMS"
                try {
                    Remove-MgUserAuthenticationPhoneMethod -UserId $UserId -PhoneAuthenticationMethodId $Method.Id | Out-Null
                    $status = "Success"
                    $message = "Removed user MFA method: $methodString"
                    $errorMessage = $null
                    $Details = $Method.AdditionalProperties.phoneNumber
                } catch {
                    if ( $errorDetails.Message -like "*matches the user's current default authentication method, and cannot be deleted until the default authentication method is changed*" ) {
                        $script:defaultMfaMethod = $Method
                        $status = "Warning"
                        $message = "Attempted to remove the user's default MFA method ($methodString) while others still exist. This will be re-attempted after other methods are removed and can be safely ignored if the second removal is successful."
                    } else {
                        $message = "Failed to remove one or more user MFA authentication methods ($methodString)"
                        $errorMessage = $_.Exception.Message
                    }
                }
                Add-TaskResult -Task $task -Status $status -Message $message -ErrorMessage $errorMessage -Details $details
            }
            '#microsoft.graph.softwareOathAuthenticationMethod' { 
                # Remove softwareOathAuthenticationMethod
                $methodString = "software OAUTH"
                try {
                    Remove-MgUserAuthenticationSoftwareOathMethod -UserId $UserId -SoftwareOathAuthenticationMethodId $Method.Id | Out-Null
                    $status = "Success"
                    $message = "Removed user MFA method: $methodString"
                    $errorMessage = $null
                    
                } catch {
                    if ( $errorDetails.Message -like "*matches the user's current default authentication method, and cannot be deleted until the default authentication method is changed*" ) {
                        $script:defaultMfaMethod = $Method
                        $status = "Warning"
                        $message = "Attempted to remove the user's default MFA method ($methodString) while others still exist. This will be re-attempted after other methods are removed and can be safely ignored if the second removal is successful."
                    } else {
                        $message = "Failed to remove one or more user MFA authentication methods ($methodString)"
                        $errorMessage = $_.Exception.Message
                    }
                }
                Add-TaskResult -Task $task -Status $status -Message $message -ErrorMessage $errorMessage -Details $details
            }
            '#microsoft.graph.temporaryAccessPassAuthenticationMethod' {
                # Remove temporaryAccessPassAuthenticationMethod'
                $methodString = "TAPS"
                try {
                    Remove-MgUserAuthenticationTemporaryAccessPassMethod -UserId $UserId -TemporaryAccessPassAuthenticationMethodId $Method.Id | Out-Null
                    $status = "Success"
                    $message = "Removed user MFA method: $methodString"
                    $errorMessage = $null
                    
                } catch {
                    if ( $errorDetails.Message -like "*matches the user's current default authentication method, and cannot be deleted until the default authentication method is changed*" ) {
                        $script:defaultMfaMethod = $Method
                        $status = "Warning"
                        $message = "Attempted to remove the user's default MFA method ($methodString) while others still exist. This will be re-attempted after other methods are removed and can be safely ignored if the second removal is successful."
                    } else {
                        $message = "Failed to remove one or more user MFA authentication methods ($methodString)"
                        $errorMessage = $_.Exception.Message
                    }
                }
                Add-TaskResult -Task $task -Status $status -Message $message -ErrorMessage $errorMessage -Details $details
            }
            '#microsoft.graph.windowsHelloForBusinessAuthenticationMethod' { 
                # Remove windowsHelloForBusinessAuthenticationMethod'
                $methodString = "WHfB"
                try {
                    Remove-MgUserAuthenticationWindowsHelloForBusinessMethod -UserId $UserId -WindowsHelloForBusinessAuthenticationMethodId $Method.Id | Out-Null
                    $status = "Success"
                    $message = "Removed user MFA method: $methodString"
                    $errorMessage = $null
                    
                } catch {
                    if ( $errorDetails.Message -like "*matches the user's current default authentication method, and cannot be deleted until the default authentication method is changed*" ) {
                        $script:defaultMfaMethod = $Method
                        $status = "Warning"
                        $message = "Attempted to remove the user's default MFA method ($methodString) while others still exist. This will be re-attempted after other methods are removed and can be safely ignored if the second removal is successful."
                    } else {
                        $message = "Failed to remove one or more user MFA authentication methods ($methodString)"
                        $errorMessage = $_.Exception.Message
                    }
                }
                Add-TaskResult -Task $task -Status $status -Message $message -ErrorMessage $errorMessage -Details $details
            }
            '#microsoft.graph.passwordAuthenticationMethod' { 
                # Password cannot be removed currently
            }        
            Default {
                Write-Host 'This script does not handle removing this auth method type: ' + $Method.AdditionalProperties['@odata.type']
            }
        }
    }

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
    $ErrorActionPreference = "Stop"
    $function = $MyInvocation.MyCommand.Name
    $task = "Clear MFA methods"
    $status = "Failure"
    $results = [System.Collections.Generic.List[System.Object]]::new()

    # Retrieve all configured MFA methods for the user
    $mfaMethods = Get-MgUserAuthenticationMethod -UserId $UserPrincipalName

    # Initialize the default method to null
    $defaultMfaMethod = $null

    # Start processing all MFA methods. If the default method is processed last it should remove all methods, otherwise the default will be removed
    # on the second pass below
    foreach ($mfaMethod in $mfaMethods) {
        Remove-EntraMfaAuthMethod -UserId $UserPrincipalName -Method $mfaMethod
    }
    # If a default MFA method was found, re-run the function on this method alone. It assumes there are no other MFA methods left
    if ($null -ne $defaultMfaMethod) {
        Remove-EntraMfaAuthMethod -UserId $UserPrincipalName -Method $defaultMfaMethod
    }

    # Output 
    return $results

}