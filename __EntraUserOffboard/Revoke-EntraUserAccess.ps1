<#
[Mandatory]
Reset the password
Revoke user sessions
Remove any assigned licenses
Re-assign any Unified Groups owned by the user to their manager (or a Global Admin)
Remove the user from any Unified Groups
Remove the user from any distribution groups
Hide the user from the GAL
Clear data from mobile devices
Remove user from Azure AD groups
Clear out values of Azure AD user properties that may include them in dynamic groups
Clear MFA methods
Disable the account

[Optional]
Convert the account to a shared mailbox
Forward email
Mailbox delegation
OneDrive delegation
#>

function Revoke-EntraUserAccess {

    [SkyKickCommand(DisplayName = "Set Parameter Sections", Sections = { "Confirmation", "User", "Options" })]
    param(

        [SkyKickParameter(
            DisplayName = "Is the account cloud-only? If the user is still being synced with Active Directory they MUST be converted to a cloud-only account before proceeding.",    
            Section = "Confirmation",
            DisplayOrder = 1
        )]
        [Parameter(Mandatory = $True)]
        [ValidateSet("Yes")]
        [string]$UserConfirmation,

        ###############

        [ArgumentCompleter({
                param ($CommandName, $ParameterName, $WordToComplete, $CommandAst, $FakeBoundParameters)

                # Getting all active users for the argument completer
                $params = @{
                    Top      = 30
                    Property = @("UserPrincipalName", "Id")
                }
                if ($WordToComplete) {
                    $params += @{
                        Filter = "startsWith(UserPrincipalName, '$WordToComplete')"
                    }
                }

                Get-MgUser @params
                | Sort-Object -Property UserPrincipalName
                | ForEach-Object {
                    New-SkyKickCompletionResult -Value $_.UserPrincipalName -DisplayName $_.UserPrincipalName
                }
            })]   
        [SkyKickParameter(
            DisplayName = "User",
            Section = "User",
            HintText = "Select the user to offboard."
        )]
        [Parameter(Mandatory = $True)]
        [String]$UserPrincipalName,

        ###############

        [Parameter(Mandatory = $false)]
        [Boolean]
        [SkyKickParameter(
            DisplayName = "Convert to shared mailbox?",
            Section = "Options",
            DisplayOrder = 1
        )]
        $SharedMailbox = $false,

        [Parameter(Mandatory = $false)]
        [Boolean]
        [SkyKickParameter(
            DisplayName = "Forward emails?",
            Section = "Options",
            DisplayOrder = 2
        )]
        $ForwardEmail = $false,

        [SkyKickConditionalVisibility({
                param($ForwardEmail)
                return (
                ($ForwardEmail -eq $true)
                )
            },
            IsMandatoryWhenVisible = $True
        )]
        [ArgumentCompleter({
                [PSTypeName("Email Address")]
                param ($CommandName, $ParameterName, $WordToComplete, $CommandAst, $FakeBoundParameters)
                Get-Recipient | ForEach-Object {
                    New-Object System.Management.Automation.CompletionResult -ArgumentList $_.PrimarySmtpAddress, $_.PrimarySmtpAddress, "ParameterValue", $_.PrimarySmtpAddress
                }
            })] 
        [SkyKickParameter(
            DisplayName = "Forwarding address",
            Section = "Options",
            HintText = "Enter an address to forward emails to.",
            DisplayOrder = 3
        )]
        [string] $ForwardingAddress,

        ###############

        [Parameter(Mandatory = $false)]
        [SkyKickParameter(
            DisplayName = "Grant another user access to the ex-employee's inbox/calendar/contacts?",
            Section = "Options",
            DisplayOrder = 4
        )]
        [Boolean]
        $GrantMailboxAccess = $false,

        [SkyKickConditionalVisibility({
                param($GrantMailboxAccess)
                return (
                ($GrantMailboxAccess -eq $true)
                )
            },
            IsMandatoryWhenVisible = $True
        )]
        [ArgumentCompleter({
                param ($CommandName, $ParameterName, $WordToComplete, $CommandAst, $FakeBoundParameters)

                # Getting all active users for the argument completer
                $params = @{
                    Top      = 30
                    Property = @("UserPrincipalName", "Id")
                }
                if ($WordToComplete) {
                    $params += @{
                        Filter = "startsWith(UserPrincipalName, '$WordToComplete')"
                    }
                }

                Get-MgUser @params
                | Sort-Object -Property UserPrincipalName
                | ForEach-Object {
                    New-SkyKickCompletionResult -Value $_.UserPrincipalName -DisplayName $_.UserPrincipalName
                }
            })]   
        [SkyKickParameter(
            DisplayName = "Trustee: Mailbox",
            Section = "Options",
            DisplayOrder = 5,
            HintText = "Enter the user who should be granted access to the ex-employee's mailbox (inbox, calendar, contacts)."
        )]
        [String]$MailboxTrustee,

        ###############

        [Parameter(Mandatory = $false)]
        [SkyKickParameter(
            DisplayName = "Grant another user access to the ex-employee's OneDrive?",
            Section = "Options",
            DisplayOrder = 6
        )]
        [Boolean]
        $GrantOneDriveAccess = $false,

        [SkyKickConditionalVisibility({
                param($GrantOneDriveAccess)
                return (
                ($GrantOneDriveAccess -eq $true)
                )
            },
            IsMandatoryWhenVisible = $true
        )]
        [ArgumentCompleter({
                param ($CommandName, $ParameterName, $WordToComplete, $CommandAst, $FakeBoundParameters)

                # Getting all active users for the argument completer
                $params = @{
                    Top      = 30
                    Property = @("UserPrincipalName", "Id")
                }
                if ($WordToComplete) {
                    $params += @{
                        Filter = "startsWith(UserPrincipalName, '$WordToComplete')"
                    }
                }

                Get-MgUser @params
                | Sort-Object -Property UserPrincipalName
                | ForEach-Object {
                    New-SkyKickCompletionResult -Value $_.UserPrincipalName -DisplayName $_.UserPrincipalName
                }
            })]   
        [SkyKickParameter(
            DisplayName = "Trustee: OneDrive",
            HintText = "Enter the user who should be granted access to the ex-employee's OneDrive.",
            Section = "Options",
            DisplayOrder = 7
        )]
        [String]$OneDriveTrustee

        ###############

    )

    if ( $UserConfirmation -like "Yes" ) {
        $hasMailbox = Test-EXOMailbox -UserPrincipalName $UserPrincipalName
        ### Optional items ###
        if ( $hasMailbox ) {
            # Convert to shared mailbox
            if ( $SharedMailbox ) {
                Convert-EXOMailboxToShared -UserPrincipalName $UserPrincipalName
            }
            if ( $ForwardEmail ) {
                Set-EXOMailboxForwarding -Identity $UserPrincipalName -Recipient $ForwardingAddress -RecipientLocation Internal -DeliveryType Forwarding  
            }
            if ( $GrantMailboxAccess ) {
                Add-EXOMailboxFullAccess -UserPrincipalName $UserPrincipalName -Trustee $MailboxTrustee -AutoMapping:$True
            }
            if ( $GrantOneDriveAccess ) {
                Add-SPOSiteAdditionalOwner -UserPrincipalName $UserPrincipalName -OneDriveTrustee $OneDriveTrustee
            }
        }
        ### Mandatory items ###
        # Reset user password
        Reset-EntraUserPassword -UserPrincipalName $UserPrincipalName -Random:$True -Length 32 -ForceChangePasswordNextLogin:$True
        # Revoke sessions
        try {
            Revoke-MgUserSignInSession -UserId $UserPrincipalName | Out-Null
            Write-Output "[Revoke sessions] Revoked user sessions"
        } catch {
            Write-Output "[Revoke sessions] Error occurred attempting to revoke sessions: $($_.Exception.Message)"
        }
        # Clear MFA methods
        Clear-EntraUserMultifactorMethods -UserPrincipalName $UserPrincipalName
        # Remove user licenses
        Remove-EntraUserAssignedLicenses -UserPrincipalName $UserPrincipalName
        # Remove user from Unified Groups
        Remove-UnifiedGroupMembership -UserPrincipalName $UserPrincipalName
        if ( $hasMailbox ) {
            # Remove ownership from any Unified Groups, reassign to manager or a global admin
            Remove-UnifiedGroupOwnership -UserPrincipalName $UserPrincipalName
            # Remove user from distribution groups
            Remove-EXODistributionGroupMembership -UserPrincipalName $UserPrincipalName
            # Hide the mailbox from the GAL
            Set-EXOMailboxGALVisibility -UserPrincipalName $UserPrincipalName -Hidden:$True
            # Clear data from mobile devices
            Clear-EXOMailboxMobileData -UserPrincipalName $UserPrincipalName
        }
        # Remove user from Entra ID security groups
        Remove-EntraUserGroupMembership -UserPrincipalName $UserPrincipalName
        # Clear out values of Azure AD user properties that may include them in dynamic groups
        Clear-EntraUserProperties -UserPrincipalName $UserPrincipalName
        # Disable account
        try {
            $params = @{  
                AccountEnabled = "false"
            }  
            Update-MgUser -UserId $UserPrincipalName -BodyParameter $params            
            Write-Output "[Disable account] Disabled user account"
        } catch {
            Write-Output "[Disable account] Error occurred attempting to disable account: $($_.Exception.Message)"
        }
        
    } else {
        quit
    }
	
}