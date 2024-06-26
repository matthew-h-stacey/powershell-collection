function Get-EntraBypassGroupMembers {
    <#
.SYNOPSIS
Generate a report of members in bypass groups

.DESCRIPTION
This script is used to parse through Entra ID groups with the word "bypass" in the name to collect information on all members. It recursively pulls all members of each of the groups and reports the following properties:

- Client: The selected client. Multiple clients can be included in one report
- Group: The Entra ID group
- AccountEnabled: Whether or not the member account is enabled
- Name: The DisplayName of the member
- UserPrincipalName: The UserPrincipalName of the member
- Licenses: The licenses assigned to the member
- LastInteractiveSignIn: Timestamp of the last interactive sign-in
- LastInteractiveSignInLocation: The named location (if matched) or public IP of the last sign-in
- LastNonInteractiveSignIn: Timestamp of the last non-interactive sign-in

What's new:
- Addition of sign-in IP address
- The public IP in the last interactive sign-in can be matched to existing named locations
- Note: Graph API does not yet support pulling the non-interactive sign-in details so those will be included later when supported
#>

    param(
        [Parameter(Mandatory = $true)]
        [CustomerContext[]]
        $Clients
    )

    $htmlReportName = "Entra ID Bypass Group Membership Report"
    $htmlReportFooter = "Report created using SkyKick Cloud Manager"
    $skusMappingTable = Get-Microsoft365LicensesMappingTable
    $results = @()

    # Start processing selected clients
    $Clients | ForEach-Object -Process {
        # Set the customer context to the selected customer
        Set-CustomerContext $_
        $customer = Get-CustomerContext
        # Retrieve named locations
        $namedLocations = Get-EntraNamedLocations
        # Get all bypass groups
        $bypassgroups = Get-MgGroup -Search "displayName:bypass" -Sort "displayName" -CountVariable CountVar -ConsistencyLevel eventual 
        foreach ($bypassgroup in $bypassgroups) {
            # Start processing groups
            Write-Output "[INFO] Starting to process group: $($bypassgroup.DisplayName)"
            $groupMembers = Get-MgGroupTransitiveMember  -GroupId $bypassgroup.Id -All
            # Start processing each memmber
            foreach ($groupmember in $groupmembers) {
                if ( $groupMember.AdditionalProperties.'@odata.type' -eq "#microsoft.graph.user") {
                    $properties = @(
                        "AccountEnabled",
                        "AssignedLicenses",
                        "DisplayName",
                        "SignInActivity",
                        "UserPrincipalName"
                    )
                    # Retrieve user object
                    try {
                        $user = Get-MgUser -UserId $groupmember.Id -Property $properties
                        $UPN = $user.UserPrincipalName
                        Write-Output "[INFO] Located user: $UPN"
                    } catch {
                        Write-Output " [ERROR] Unable to find $UPN. Error: $($_.Exception.Message)"
                        exit 1
                    }
                    # Retrieve licenses
                    $licenses = @()
                    if ( $user.AssignedLicenses.SKUID ) {
                        foreach ($sku in $user.AssignedLicenses.SKUID) {
                            $licenses += ($skusMappingTable | Where-Object { $_.GUID -eq "$sku" } | Select-Object -expand DisplayName -Unique)
                        }
                        $licenses = ($licenses | Sort-Object) -join ', '
                    } else {
                        $licenses = "None"
                    }
                    # Retrieve last interactive signins details, including location match
                    $lastInteractiveSignIn = Get-EntraUserLastSignIn -UserPrincipalName $UPN -IsInteractive $true -NamedLocations $namedLocations
                    # Output object to array
                    $results += [PSCustomObject]@{
                        Client                        = $customer.CustomerName    
                        Group                         = $bypassgroup.DisplayName
                        AccountEnabled                = $user.AccountEnabled
                        Name                          = $User.DisplayName
                        UserPrincipalName             = $UPN
                        Licenses                      = $licenses
                        LastInteractiveSignin         = $lastInteractiveSignin.Timestamp
                        LastInteractiveSignInLocation = $lastInteractiveSignin.Location
                        LastNonInteractiveSignIn      = $user.SignInActivity.LastNonInteractiveSignInDateTime
                    }
                    Write-Output "[INFO] Added user to output"
                }
            }   
        }
    }
    $reportParams = @{
        IncludePartnerLogo = $true
        ReportTitle        = $htmlReportName
        ReportFooter       = $htmlReportFooter
        OutTo              = "NewTab"

    }
    $results | Out-SkyKickTableToHtmlReport @ReportParams
}