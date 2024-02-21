<#
.SYNOPSIS
Perform steps necessary to offboard an Entra ID user account

.NOTES
To do:
[ ] Troubleshoot script failure on aapple@bcservice.tech

Functions:
1) Mandatory
[X] Reset the password
[X] Convert the account to a shared mailbox
[X] Remove any assigned licenses
[X] Re-assign any Unified Groups owned by the user to their manager (or a Global Admin)
[X] Remove the user from any Unified Groups
[X] Remove the user from any distribution groups
[X] Hide the user from the GAL
[X] Clear data from mobile devices
[X] Remove user from Azure AD groups
[X] Clear out values of Azure AD user properties that may include them in dynamic groups
[X] Clear MFA methods

2) Optional
[X] Forward email
[X] Mailbox delegation
[X] OneDrive delegation

Data variables:
$UserPrincipalName
$ForwardingAddress
$MailboxTrustee
$OneDriveTrustee

Booleans:
$ForwardEmail
$GrantMailboxAccess
$GrantOneDriveAccess

#>

function Revoke-AADUserAccess {

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
                $Params = @{
                    Top      = 30
                    Property = @("UserPrincipalName", "Id")
                }
                if ($WordToComplete) {
                    $Params += @{
                        Filter = "startsWith(UserPrincipalName, '$WordToComplete')"
                    }
                }

                Get-MgUser @Params
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
            DisplayName = "Forward emails?",
            Section = "Options",
            DisplayOrder = 1
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
            DisplayOrder = 2
        )]
        [string] $ForwardingAddress,

        ###############

        [Parameter(Mandatory = $false)]
        [SkyKickParameter(
            DisplayName = "Grant another user access to the ex-employee's inbox/calendar/contacts?",
            Section = "Options",
            DisplayOrder = 3
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
                $Params = @{
                    Top      = 30
                    Property = @("UserPrincipalName", "Id")
                }
                if ($WordToComplete) {
                    $Params += @{
                        Filter = "startsWith(UserPrincipalName, '$WordToComplete')"
                    }
                }

                Get-MgUser @Params
                | Sort-Object -Property UserPrincipalName
                | ForEach-Object {
                    New-SkyKickCompletionResult -Value $_.UserPrincipalName -DisplayName $_.UserPrincipalName
                }
            })]   
        [SkyKickParameter(
            DisplayName = "Trustee: Mailbox",
            Section = "Options",
            DisplayOrder = 4,
            HintText = "Enter the user who should be granted access to the ex-employee's mailbox (inbox, calendar, contacts)."
        )]
        [String]$MailboxTrustee,

        ###############

        [Parameter(Mandatory = $false)]
        [SkyKickParameter(
            DisplayName = "Grant another user access to the ex-employee's OneDrive?",
            Section = "Options",
            DisplayOrder = 9
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
                $Params = @{
                    Top      = 30
                    Property = @("UserPrincipalName", "Id")
                }
                if ($WordToComplete) {
                    $Params += @{
                        Filter = "startsWith(UserPrincipalName, '$WordToComplete')"
                    }
                }

                Get-MgUser @Params
                | Sort-Object -Property UserPrincipalName
                | ForEach-Object {
                    New-SkyKickCompletionResult -Value $_.UserPrincipalName -DisplayName $_.UserPrincipalName
                }
            })]   
        [SkyKickParameter(
            DisplayName = "Trustee: OneDrive",
            HintText = "Enter the user who should be granted access to the ex-employee's OneDrive.",
            Section = "Options",
            DisplayOrder = 10
        )]
        [String]$OneDriveTrustee

        ###############

    )

    

    if ( $UserConfirmation -like "Yes" ) {

        ### Mandatory items ###
        
        # Reset user password
        Reset-AADUserPassword -UserPrincipalName $UserPrincipalName -Random:$True -Length 32 -ForceChangePasswordNextLogin:$True

        # Convert to shared mailbox
        Convert-EXOMailboxToShared -UserPrincipalName $UserPrincipalName

        #Remove user licenses
        Remove-M365UserLicenses -UserPrincipalName $UserPrincipalName

        # Remove ownership from any Unified Groups, reassign to manager or a global admin
        Remove-UnifiedGroupOwnership -UserPrincipalName $UserPrincipalName

        # Remove user from Unified Groups
        Remove-UnifiedGroupMembership -UserPrincipalName $UserPrincipalName
        
        # Remove user from distribution groups
        Remove-EXODistributionGroupMembership -UserPrincipalName $UserPrincipalName
    
        # Hide the mailbox from the GAL
        Set-EXOMailboxGALVisibility -UserPrincipalName $UserPrincipalName -Hidden:$True

        # Clear data from mobile devices
        Clear-EXOMailboxMobileData -UserPrincipalName $UserPrincipalName

        # Remove user from Azure AD groups
        Remove-AADUserGroupMembership -UserPrincipalName $UserPrincipalName

        # Clear out values of Azure AD user properties that may include them in dynamic groups
        Clear-AADUserProperties -UserPrincipalName $UserPrincipalName

        # Clear out MFA methods
        Clear-AADUserMFAMethods -UserPrincipalName $UserPrincipalName

        ### Optional items ###

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
    else {
        quit
    }
	
}