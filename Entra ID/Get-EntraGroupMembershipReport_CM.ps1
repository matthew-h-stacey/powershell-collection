function Get-EntraGroupMembershipReport {

    param (
        [Parameter(Mandatory = $true)]
        [CustomerContext[]]
        $Clients
    )

    function Add-GroupResults {
    param (
        [Parameter(Mandatory = $true)]
        [object]
        $OutputList
    )

    $OutputList.Add(
        [PSCustomObject]@{
            client = $clientName
            displayName = $group.displayName
            description = $group.description
            groupType = $groupType
            mail = $group.mail
            membershipRule = $group.membershipRule
            onPremisesSyncEnabled = $group.onPremisesSyncEnabled
            securityEnabled = $group.securityEnabled
            mailEnabled = $group.mailEnabled
            proxyAddresses = $proxyAddresses
            createdDateTime = $group.createdDateTime
            id = $group.id
            memberUserPrincipalName = $member
        }
    )}

    # Empty list to store results in
    $results = [System.Collections.Generic.List[System.Object]]::new()

    # Variables for Cloud Manager HTML report
    $htmlReportName = "Entra Group Membership Report"
    $htmlReportFooter = "Report created using SkyKick Cloud Manager"
    $reportParams = @{
        IncludePartnerLogo = $true
        ReportTitle        = $htmlReportName
        ReportFooter       = $htmlReportFooter
        OutTo              = "NewTab"
    }

    # Start processing all selected clients
    $Clients | ForEach-Object -Process {

        # Set the customer context to the selected customer
        Set-CustomerContext $_
        $clientName = (Get-CustomerContext).CustomerName

        # Get all groups with support for 1000+ results returned
        $uri = 'https://graph.microsoft.com/v1.0/groups?$top=999'
        $allEntraGroups = @()
        $nextLink = $null
        do {
            $uri = if ($nextLink) {
                $nextLink
            } else {
                $URI
            }
            $response = Invoke-MgGraphRequest -Uri $uri -Method GET
            $output = $response.Value
            $allEntraGroups += $output
            $nextLink = $response.'@odata.nextLink'
        } until (-not $nextLink )

        # Batch: Retrieve group membership of all groups
        $props = @(
            "displayName"
            "description"
            "groupTypes"
            "mail"
            "membershipRule"
            "onPremisesSyncEnabled"
            "securityEnabled"
            "mailEnabled"
            "proxyAddresses"
            "createdDateTime"
            "id"
            "resourceProvisioningOptions"
        )
        $propsJoined = $props -join ', '
        $apiQuery = '/groups/{Id}?$expand=members&$select=' + $propsJoined
        $allEntraGroupsWithMembership = Invoke-GraphBatchRequest -InputObjects $allEntraGroups -ApiQuery $apiQuery -Placeholder Id -verbose

        # Iterate through all groups and add the members
        foreach ( $group in $allEntraGroupsWithMembership ) {

            # Determine group type
            if ($group.resourceProvisioningOptions -eq "Team") {
                $groupType = "Team"
            } elseif ($group.groupTypes -contains "Unified") {
                $groupType = "Microsoft 365 Group"
            } elseif ($group.securityEnabled -and $group.mailEnabled) {
                $groupType = "Mail-Enabled Security Group"
            } elseif ($group.securityEnabled) {
                $groupType = "Security Group"
            } elseif ($group.mailEnabled) {
                $groupType = "Distribution Group"
            } else {
                $groupType = "Other"
            }

            # Determine proxyAddresses value    
            if ( $mailEnabled ) {
                $proxyAddresses = $group.proxyAddresses -join ', '
            } else {
                $proxyAddresses = "N/A"
            }

            # Iterate through each member and add the results
            if ( $group.Members ) {
                foreach ( $user in $group.Members ) {
                    $member = $user.userPrincipalName
                    Add-GroupResults -OutputList $results
                }
            } else {
                $member = "No members in group"
                Add-GroupResults -OutputList $results
            }
        }
    }

    $results | Sort-Object client | Out-SkyKickTableToHtmlReport @reportParams

}