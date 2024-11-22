function Reset-EntraUserPassword {

    # Example:
    # Reset-AADUserPassword -UserPrincipalName GradyA@5r86fn.onmicrosoft.com -Random:$true -Length 32 -ForceChangePasswordNextLogin:$false

    param(
    
        #
        [SkyKickParameter(
            DisplayName = "UserPrincipalName",
            HintText = "Select the user whose password will be reset."
        )]
        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')]
        [string] $UserPrincipalName,
    
        #
        [SkyKickParameter(
            DisplayName = "Random",
            HintText = "If enabled, the password will be reset to a randomly generated 32-character password."
        )]
        [Parameter(Mandatory = $False)]
        [Boolean]$Random = $true,
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
        [Int]$Length,

        #
        [SkyKickParameter(
            DisplayName = "ForceChangePasswordNextLogin",
            HintText = "Require the password to be chnaged on next login."
        )]
        [Parameter(Mandatory = $true)]
        [Boolean] $ForceChangePasswordNextLogin

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
    
    $password = @{
        Password                      = (Get-RandomPassword -Length $Length)
        ForceChangePasswordNextSignIn = $ForceChangePasswordNextLogin
    }
    try {
        Update-MgUser -UserId $UserPrincipalName -PasswordProfile $password
        Write-Output "[Password reset] $UserPrincipalName password successfully reset to a $($Length)-character randomly generated password."
    } catch {
        Write-Output "[Password reset][Error] Failed to reset the password for user: $UserPrincipalName. Error:"
        Write-Output $_.Exception.Message
    }

}