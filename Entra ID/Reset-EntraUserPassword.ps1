<#
.SYNOPSIS
Reset an Entra user's password

.EXAMPLE
Reset-EntraUserPassword -UserPrincipalName GradyA@5r86fn.onmicrosoft.com -Random:$true -Length 32 -ForceChangePasswordNextLogin:$false

.NOTES
[ ] Re-add the option to type a password

#>

function Reset-EntraUserPassword {

    param(    
        #
        [SkyKickParameter(
            DisplayName = "UserPrincipalName",
            HintText = "Select the user whose password will be reset."
        )]
        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')]
        [string]
        $UserPrincipalName,
    
        #
        [SkyKickParameter(
            DisplayName = "Random",
            HintText = "If enabled, the password will be reset to a randomly generated 32-character password."
        )]
        [Parameter(Mandatory = $False)]
        [boolean]
        $Random = $true,
        #
        [SkyKickConditionalVisibility({

                param($Random)
                return (($Random -eq $true))
            },
            IsMandatoryWhenVisible = $true
        )]
        [SkyKickParameter(
            DisplayName = "Password length",
            HintText = "Enter the desired length of the password to generate."
        )]
        [int]
        $Length,

        #
        [SkyKickParameter(
            DisplayName = "ForceChangePasswordNextLogin",
            HintText = "Require the password to be changed on next login."
        )]
        [Parameter(Mandatory = $true)]
        [boolean]
        $ForceChangePasswordNextLogin,

        [Parameter(Mandatory = $true)]
        [boolean]
        $RevokeSessions

    )
    
    function Get-RandomPassword {
    
        param (
            [Parameter(Mandatory)]
            [int] $Length
        )
        
        $CharSet = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()'.ToCharArray()
        $Password = -join (Get-Random -InputObject $CharSet -Count $Length)
        
        return $password
    
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
    $function = $MyInvocation.MyCommand.Name
    $task = "Reset user password"
    $status = "Failure"
    $results = [System.Collections.Generic.List[System.Object]]::new()
    
    $password = @{
        Password                      = (Get-RandomPassword -Length $Length)
        ForceChangePasswordNextSignIn = $ForceChangePasswordNextLogin
    }
    try {
        Update-MgUser -UserId $UserPrincipalName -PasswordProfile $password
        $status = "Success"
        $message = "$UserPrincipalName password successfully reset to a $($Length)-character randomly generated password."
    } catch {
        $message = "Failed to reset the password for user: $UserPrincipalName"
        $errorMessage = $_.Exception.Message
    }
    Add-TaskResult -Task $task -Status $status -Message $message -ErrorMessage $errorMessage -Details $details
    if ( $RevokeSessions ) {
        try {
            Revoke-MgUserSignInSession -UserId $UserPrincipalName | Out-Null
            $task = "Revoke sessions"
            $status = "Success"
            $message = "Revoked user sessions for $UserPrincipalName"
        } catch {
            $status = "Failure"
            $message = "Error occurred attempting to revoke sessions for $UserPrincipalName"
            $errorMessage = $_.Exception.Message
        }
        Add-TaskResult -Task $task -Status $status -Message $message -ErrorMessage $errorMessage -Details $details
    }

    # Output
    return $results
}