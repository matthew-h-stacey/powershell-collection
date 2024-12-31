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
Auto-reply email
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
        [string]
        $UserConfirmation,

        ###############

        [ArgumentCompleter({
                param ($CommandName, $ParameterName, $WordToComplete, $CommandAst, $FakeBoundParameters)

                # Getting all active users for the argument completer
                $params = @{
                    Top      = 30
                    Property = @("UserPrincipalName", "Id", "DisplayName")
                }
                if ($WordToComplete) {
                    $params["Filter"] = "startsWith(UserPrincipalName, '$WordToComplete')"
                }

                Get-MgUser @params
                | Sort-Object -Property UserPrincipalName
                | ForEach-Object {
                    $displayName = "$($_.UserPrincipalName) ($($_.DisplayName))" # displays users in the format: jsmith@contoso.com (John Smith)
                    New-SkyKickCompletionResult -Value $_.UserPrincipalName -DisplayName $displayName
                }
            })]   
        [SkyKickParameter(
            DisplayName = "User",
            Section = "User",
            HintText = "Select the user to offboard."
        )]
        [Parameter(Mandatory = $True)]
        [String]
        $UserPrincipalName,

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
        [string]
        $ForwardingAddress,

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
        [String]
        $MailboxTrustee,

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
        [String]
        $OneDriveTrustee,

        ###############

        [Parameter(Mandatory = $false)]
        [SkyKickParameter(
            DisplayName = "Set out of office message?",
            Section = "Options",
            DisplayOrder = 8
        )]
        [Boolean]
        $SetOOO = $false,

        [SkyKickConditionalVisibility({
                param($SetOOO)
                return (
                ($SetOOO -eq $true)
                )
            },
            IsMandatoryWhenVisible = $true
        )] 
        [SkyKickParameter(
            DisplayName = "Out of office message",
            HintText = "Enter the desired out of office message to set on the user's mailbox.",
            Section = "Options",
            DisplayOrder = 9
        )]
        [String]
        $OOOMessage

        ###############

    )

    function Add-Results {
        <#
        .SYNOPSIS
        Quick helper function to add results from the related functions. Supports flattening from functions that return multiple values

        .PARAMETER FinalResults
        The list that results should be flattened into

        .PARAMETER TaskResults
        Results from an individual function to flatten into FinalResults

        #>

        param (
            [System.Collections.Generic.List[System.Object]]$FinalResults, # Aggregated results
            [array]$TaskResults # Output from a function to be added
        )
        foreach ($result in $TaskResults) {
            $FinalResults.Add($result)
        }
    }

    $results = [System.Collections.Generic.List[System.Object]]::new()
    $htmlReportName = "Entra ID user offboard report: $UserPrincipalName"
    $htmlReportFooter = "Report created using SkyKick Cloud Manager"
    $reportParams = @{
        IncludePartnerLogo = $true
        ReportTitle        = $htmlReportName
        ReportFooter       = $htmlReportFooter
        OutTo              = "NewTab"
    }

    if ( $UserConfirmation -like "Yes" ) {
        $hasMailbox = Test-EXOMailbox -UserPrincipalName $UserPrincipalName
        ### Optional items ###
        if ( $hasMailbox ) {
            # Convert to shared mailbox
            if ( $SharedMailbox ) {
                Add-Results -FinalResults $results -TaskResults (Convert-EXOMailboxToShared -UserPrincipalName $UserPrincipalName)
            }
            if ( $ForwardEmail ) {
                Add-Results -FinalResults $results -TaskResults (Set-EXOMailboxForwarding -Identity $UserPrincipalName -Recipient $ForwardingAddress -RecipientLocation Internal -DeliveryType Forwarding)
            }
            if ( $GrantMailboxAccess ) {
                Add-Results -FinalResults $results -TaskResults  (Add-EXOMailboxFullAccess -UserPrincipalName $UserPrincipalName -Trustee $MailboxTrustee -AutoMapping:$True)
            }
            if ( $GrantOneDriveAccess ) {
                Add-Results -FinalResults $results -TaskResults  (Add-SPOSiteAdditionalOwner -UserPrincipalName $UserPrincipalName -OneDriveTrustee $OneDriveTrustee)
            }
            if ( $OOOMessage ) {
                Add-Results -FinalResults $results -TaskResults  (Set-EXOMailboxAutoReply -Identity $UserPrincipalName -InternalReply $OOOMessage -ExternalReply $OOOMessage )
            }
        }
        ### Mandatory items ###
        # Reset user password and revoke sessions
        Add-Results -FinalResults $results -TaskResults  (Reset-EntraUserPassword -UserPrincipalName $UserPrincipalName -Random:$True -Length 32 -ForceChangePasswordNextLogin:$True -RevokeSessions:$true)
        # Clear MFA methods
        Add-Results -FinalResults $results -TaskResults  (Clear-EntraUserMultifactorMethods -UserPrincipalName $UserPrincipalName)
        # Remove user licenses
        Add-Results -FinalResults $results -TaskResults  (Remove-EntraUserAssignedLicenses -UserPrincipalName $UserPrincipalName)
        # Remove user from Unified Groups
        Add-Results -FinalResults $results -TaskResults  (Remove-UnifiedGroupMembership -UserPrincipalName $UserPrincipalName)
        if ( $hasMailbox ) {
            # Remove ownership from any Unified Groups, reassign to manager or a global admin
            Add-Results -FinalResults $results -TaskResults  (Remove-UnifiedGroupOwnership -UserPrincipalName $UserPrincipalName)
            # Remove user from distribution groups
            Add-Results -FinalResults $results -TaskResults  (Remove-EXODistributionGroupMembership -UserPrincipalName $UserPrincipalName)
            # Hide the mailbox from the GAL
            Add-Results -FinalResults $results -TaskResults  (Set-EXOMailboxGALVisibility -UserPrincipalName $UserPrincipalName -Hidden:$True)
            # Clear data from mobile devices
            Add-Results -FinalResults $results -TaskResults  (Clear-EXOMailboxMobileData -UserPrincipalName $UserPrincipalName)
        }
        # Remove user from Entra ID security groups
        Add-Results -FinalResults $results -TaskResults  (Remove-EntraUserGroupMembership -UserPrincipalName $UserPrincipalName)
        # Clear out values of Azure AD user properties that may include them in dynamic groups
        Add-Results -FinalResults $results -TaskResults  (Clear-EntraUserProperties -UserPrincipalName $UserPrincipalName)
        # Disable account
        Add-Results -FinalResults $results -TaskResults  (Disable-EntraUserAccount -UserPrincipalName $UserPrincipalName)
        
        # Output
        if ( $results ) {
            $results | Select-Object Status, Task, Message, Details, ErrorMessage, FunctionName | Out-SkyKickTableToHtmlReport @reportParams
        }
    } else {
        quit
    }
	
}