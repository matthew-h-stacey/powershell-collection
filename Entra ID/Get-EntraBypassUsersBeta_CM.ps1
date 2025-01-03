function Get-EntraBypassGroupMembersBeta {

    param (
        [Parameter(Mandatory = $true)]
        [CustomerContext[]]
        $Clients
    )

    function ConvertTo-HashTable {
        <#
        .SYNOPSIS
        Quick function to convert a list to hash table

        .EXAMPLE
        ConvertTo-HashTable -List $listObjects -KeyName UserPrincipalName
        #>
        param (
            [Parameter(Mandatory = $true)]
            [System.Collections.Generic.List[System.Object]]
            $List,

            [Parameter(Mandatory = $true)]
            [string]
            $KeyName
        )
    
        $hashTable = @{}
        if ( $List ) {
            foreach ($item in $List) {
                if ( $item ) {
                    if ( $item.$KeyName ) {
                        $hashTable[$item.$KeyName] = $item
                    } else {
                        Write-Output "$KeyName does not exist on $item"
                    }
                }
            }
            return $hashTable
        } else {
            Write-Output "No input provided"
        }
        
    }

    $htmlReportName = "Entra ID Bypass Group Membership Report"
    $htmlReportFooter = "Report created using SkyKick Cloud Manager"
    $skusMappingTable = Get-Microsoft365LicensesMappingTable
    $results = [System.Collections.Generic.List[System.Object]]::new()

    $Clients | ForEach-Object -Process {

        # Set the customer context to the selected customer
        Set-CustomerContext $_
        $clientName = (Get-CustomerContext).CustomerName

        # Retrieve named locations
        $namedLocations = Get-EntraNamedLocations

        # 1) Get all bypass users
        # Add all users in any/all bypass groups to an empty list 
        $allBypassMembers = [System.Collections.Generic.List[System.Object]]::new()
        $bypassgroups = Get-MgGroup -Search "displayName:bypass" -Sort "displayName" -CountVariable CountVar -ConsistencyLevel eventual 
        foreach ($bypassgroup in $bypassgroups) {
            $groupMembers = Get-MgGroupTransitiveMember  -GroupId $bypassgroup.Id -All
            foreach ($groupmember in $groupmembers) {
                # If the user has a UPN, add it to allGroupMembers to try to find sign-in information
                if ( $groupMember.AdditionalProperties.'@odata.type' -eq "#microsoft.graph.user") {
                    if ( $groupmembers.additionalproperties.userPrincipalName ) {
                        $allBypassMembers.Add([PSCustomObject]@{
                                Id                = $groupMember.Id
                                DisplayName       = $groupMember.AdditionalProperties.displayName
                                UserPrincipalName = $groupMember.AdditionalProperties.userPrincipalName
                                BypassGroup       = $bypassgroup.DisplayName
                            })
                    }
                }
            }
        }

        if ( $allBypassMembers ) {

            # 2) Get basic properties for each user
            # Get all users with selected properties. Use batching if there is more than one member
            if ( $allBypassMembers.Count -gt 1) {
                $urlTemplate = "/users/{Id}?`$select=UserPrincipalName,AccountEnabled,AssignedLicenses,DisplayName,SignInActivity,Id,Mail"
                $bypassMembers = Invoke-GraphBatchRequest -InputObjects $allBypassMembers -ApiQuery $urlTemplate -Placeholder "Id" -Verbose
            } else {
                # The hash table conversion later expects a list. Retrieve the user and store in a list
                $bypassMembers = [System.Collections.Generic.List[System.Object]]::new()
                $uri = "https://graph.microsoft.com/v1.0/users/$($allBypassMembers.Id)" + '?$select=UserPrincipalName,AccountEnabled,AssignedLicenses,DisplayName,SignInActivity,Id,Mail'
                $user = Invoke-MgGraphRequest -Method GET -Uri $uri
                $bypassMembers.Add($user)
            }

            # 3) Get last sign-in info for each user. Use batching if there is more than one member
            $bypassMembersWithSignIns = $bypassMembers | Where-Object { $_.SignInActivity -ne $null }
            if ( ($bypassMembersWithSignIns | Select-Object Id -Unique).Count -gt 1) {
                $urlTemplate = "auditLogs/signins?`$filter=userId eq '{Id}' and status/errorCode eq 0 and IsInteractive eq true&`$select=UserPrincipalName,createdDateTime,location,ipAddress,isInteractive,UserId&`$top=1"
                $bypassMemberLogs = Invoke-GraphBatchRequest -InputObjects $bypassMembersWithSignIns -ApiQuery $urlTemplate -Placeholder "Id" -Verbose
            } else {
                # The hash table conversion later expects a list. Retrieve the sign-in logs and store in a List
                $bypassMemberLogs = [System.Collections.Generic.List[System.Object]]::new()
                $uri = "https://graph.microsoft.com/v1.0/auditLogs/signins?`$filter=userId eq '$($allBypassMembers.Id)' and status/errorCode eq 0 and IsInteractive eq true&`$select=UserPrincipalName,createdDateTime,location,ipAddress,isInteractive,UserId&`$top=1"
                $signInLogs = Invoke-MgGraphRequest -Method GET -Uri $uri
                $bypassMemberLogs.Add($signInLogs)
            }
            $bypassMemberLogsFormatted = [System.Collections.Generic.List[System.Object]]::new()
            $bypassMemberLogs | ForEach-Object {
                if ( $_.value ) {
                    $_.value | ForEach-Object {
                        $bypassMemberLogsFormatted.Add([PSCustomObject]@{
                                Id                    = $_.UserId
                                UserPrincipalName     = $_.userPrincipalName                           
                                LastInteractiveSignin = $_.createdDateTime
                                Location              = $_.Location
                                IsInteractive         = $_.isInteractive
                                IpAddress             = $_.ipAddress
                            })
                    }
                }
            }

            # 4) Combine the lists to a hash table, merge them, then convert back to a single list
            if ( $bypassMembers ) {
                $h1 = ConvertTo-HashTable -List $bypassMembers -KeyName Id
            }
            if ( $bypassMemberLogsFormatted ) {
                $h2 = ConvertTo-HashTable -List $bypassMemberLogsFormatted -KeyName Id
            } else {
                $h2 = @{}
            }
            $h3 = Merge-HashTables -First $h1 -Second $h2

            foreach ( $key in $h3.Keys) {
                # Add the client name
                $h3[$key] | Add-Member -MemberType NoteProperty -Name ClientName -Value $clientName -Force
                # Add the bypass group(s)
                $bypassGroups = ($allBypassMembers | Where-Object { $_.Id -eq $key } | Select-Object -ExpandProperty BypassGroup) -join ', '
                $h3[$key] | Add-Member -MemberType NoteProperty -Name BypassGroups -Value $bypassGroups -Force

                # Add named location or IP with country code
                $publicIp = $h3[$key].IpAddress
                if ( $publicIp ) {
                    $namedLocationMatch = $namedLocations | Where-Object { $_.CidrRange -contains "$publicIP/32" }
                    if ( $namedLocationMatch ) {
                        $location = ($namedLocationMatch.DisplayName | Select-Object -Unique) -join ', '
                        $h3[$key] | Add-Member -MemberType NoteProperty -Name ReportedLocation -Value $location -Force
                    } else {
                        $countryCode = $h3[$key].Location.CountryOrRegion
                        if ( $countryCode ) {
                            $countryCode = "($countryCode)"
                        }
                        $h3[$key] | Add-Member -MemberType NoteProperty -Name ReportedLocation -Value "$publicIp $countryCode" -Force
                    }
                }
                # Format licenses
                if ( $h3[$key].assignedLicenses ) {
                    $licenses = @()
                    $skus = $h3[$key].assignedLicenses
                    foreach ($sku in $skus.skuId) {
                        $licenses += ($skusMappingTable | Where-Object { $_.GUID -eq "$sku" } | Select-Object -expand DisplayName -Unique)
                    }
                    $licenses = ($licenses | Sort-Object) -join ', '
                    $h3[$key] | Add-Member -MemberType NoteProperty -Name Licenses -Value $licenses -Force
                }
            }

            # Add the combined hash table to the results
            foreach ($item in $h3.Values) {
                $results.Add($item)
            }
        }        
    }
    $reportParams = @{
        IncludePartnerLogo = $true
        ReportTitle        = $htmlReportName
        ReportFooter       = $htmlReportFooter
        OutTo              = "NewTab"
    }
    $results | ForEach-Object {
        [PSCustomObject]@{
            Client                        = $_.clientName
            Group                         = $_.BypassGroups
            UserPrincipalName             = $_.userPrincipalName
            DisplayName                   = $_.displayName
            AccountEnabled                = $_.accountEnabled
            LastInteractiveSignin         = $_.LastInteractiveSignin
            LastInteractiveSigninLocation = $_.ReportedLocation
            LastNonInteractiveSignIn      = $_.signInActivity.lastNonInteractiveSignInDateTime
            Licenses                      = $_.Licenses
        }
    } | Sort-Object Client | Out-SkyKickTableToHtmlReport @ReportParams

}