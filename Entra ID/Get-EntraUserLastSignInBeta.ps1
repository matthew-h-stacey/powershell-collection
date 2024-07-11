function Get-EntraUserLastSignInBeta {

    <#
    .SYNOPSIS
    Get a users last successful  sign-in timestamp and named location or IP address

    .PARAMETER UserPrincipalName
    The user to retrieve the last sign-in for

    .PARAMETER IsInteractive
    Set to true or false to pull the last interactive or non-interactive sign-in
    NOTE: Does not currently work
    Neither the 1.0 or beta API endpoints for the below Uri (and respective PS cmdlet) support non-interactive sign-ins 
    https://learn.microsoft.com/en-us/graph/api/signin-get?view=graph-rest-beta&tabs=http

    .PARAMETER NamedLocations
    Optionally provide the array when executing the function instead of running it within this function
    This is beneficial when running the function against a lot of users within the same tenant

    .EXAMPLE
    Get-EntraUserLastSignIn UserPrincipalName jsmith@contoso.com -IsInteractive $true
    #>

    param (
        [Parameter(Mandatory = $true, ParameterSetName = "SingleUser")]
        [string]
        $UserPrincipalName,

        [Parameter(Mandatory = $true, ParameterSetName = "Group")]
        [string]
        $GroupName,

        [Parameter(Mandatory = $true)]
        [boolean]
        $IsInteractive,

        [Parameter(Mandatory = $false)]
        [object[]]
        $NamedLocations,

        [Parameter(Mandatory = $false)]
        [switch]
        $Debugging
    )

    if ( $Debugging ) {
        $DebugPreference = "Continue"
        Write-Debug "Debug messages enabled"
    }

    $namedLocationsArray = $NamedLocations
    # If NamedLocations were not provided, retrieve them now
    if ( !($namedLocationsArray) ) {
        Write-Debug "NamedLocations were not provided. Retrieving them now"
        $namedLocationsArray = @()
        Get-MgIdentityConditionalAccessNamedLocation | ForEach-Object {
            if ( $_.AdditionalProperties.ipRanges.cidrAddress ) {
                $namedLocationsArray += [PSCustomObject]@{
                    DisplayName = $_.DisplayName
                    CidrRange   = $_.AdditionalProperties.ipRanges.cidrAddress
                }
            }
        }
    } else {
        Write-Debug "NamedLocations were already provided. Continuing"
    }
    Write-Debug "Found the following named locations"
    foreach ( $location in $namedLocationsArray ) {
        Write-Debug "[NAMEDLOCATION] $($location.DisplayName): $($location.CidrRange -join ', ')"
    }

    switch ($PSCmdlet.ParameterSetName) {
        'SingleUser' {
            # Construct filtering parameters
            $params = @{
                Top      = 1
                Property = @("CreatedDateTime", "Location", "IPAddress", "IsInteractive")
            }
            $filterBase = "UserPrincipalName eq '$UserPrincipalName' and status/errorCode ne 0"
            switch ( $IsInteractive ) { 
                True {
                    $loginType = "Interactive"
                    $params["Filter"] = $filterBase + " and IsInteractive eq true"
                }
                False {
                    $loginType = "Non-interactive"
                    $params["Filter"] = $filterBase + " and IsInteractive eq false"

                }
            }
            # Retrieve last sign-in and the named location. If there is no named location, return: $publicIP ($countryCode)
            $lastSignIn = Get-MgAuditLogSignIn @params
            if ( $lastSignIn.IPAddress ) {
                $publicIP = $lastSignIn.IPAddress
                Write-Debug "[IP] Public IP: $publicIP/32. Checking to see if it matches a named location ..."
                $namedLocationMatch = $namedLocationsArray | Where-Object { $_.CidrRange -contains "$publicIP/32" }
            }
            if ( $namedLocationMatch ) {
                $location = $namedLocationMatch.DisplayName -join ', '
                Write-Debug "[MATCH] Matched location to $location"
            } else {
                $countryCode = $lastSignIn.Location.CountryOrRegion
                Write-Debug "[NOMATCH] Unable to match IP to a location. Checking for country code next"
                if ( $countryCode ) {
                    $location = "$publicIP ($countryCode)"
                    Write-Debug "Located country code: $countryCode"
                } else {
                    $location = "$publicIP"
                    Write-Debug "Unable to locate country code"
                }
            }
            return [PSCustomObject]@{
                UserPrincipalName = $UserPrincipalName
                Timestamp         = $lastSignIn.CreatedDateTime
                LoginType         = $loginType
                Location          = $location
            }
        }
        'Group' {
            $allGroupMembers = [System.Collections.Generic.List[System.Object]]::new()
            $groups = Get-MgGroup -Search "displayName:$GroupName" -Sort "displayName" -CountVariable CountVar -ConsistencyLevel eventual
            foreach ($group in $groups) {
                $groupMembers = Get-MgGroupTransitiveMember  -GroupId $group.Id -All
                foreach ( $member in $groupMembers ) {
                    $allGroupMembers.Add([pscustomobject]@{
                        GroupDisplayName = $group.DisplayName
                        GroupId = $group.Id    
                        MemberId = $member.Id
                        UserPrincipalName = $member.AdditionalProperties.userPrincipalName
                        DisplayName = $member.AdditionalProperties.displayName
                    })
                }  
            }
            # start batch
            $batchSize = 20
            $signInLogs = [System.Collections.Generic.List[System.Object]]::new()
            for ($i = 0; $i -lt $allGroupMembers.Count; $i += $batchSize) {
    
                # Display chunk index
                Write-Output "Chunk $i"

                # Set the end index of this chunk
                $end = $i + $batchSize - 1

                # If this is the last chunk in the batch, set the end to be the very last object
                if ($end -ge $allGroupMembers.Count) {
                    $end = $allGroupMembers.Count
                }

                # Work through the input array for the objects in the selected chunk only
                # For each of the selected items, create a PSCustomObject with an Id for the request, the Method, and Url used to retrieve the data
                $index = $i
                $requests = $allGroupMembers[$i..($end)] | ForEach-Object {
                    [PSCustomObject]@{
                        'Id'     = ++$index
                        'Method' = 'GET'
                        'Url'     = "auditLogs/signins?$filter=userPrincipalName eq '{0}' and status/errorCode ne 0 and IsInteractive eq {1}`&`$top=1" -f $PSItem.UserPrincipalName, $IsInteractive
                    }
                }
                # Create a batch request using the previously created $results
                $requestParams = @{
                    'Method'      = 'Post'
                    'Uri'         = 'https://graph.microsoft.com/v1.0/$batch'
                    'ContentType' = 'application/json'
                    'Body'        = @{
                        'requests' = @($requests)
                    } | ConvertTo-Json
                }
                $response = Invoke-MgGraphRequest @requestParams

                # Invoke-MgGraphRequest deserializes request to a hashtable
                # Add all items to the list created at the start
                $response.responses | ForEach-Object { $signInLogs.Add([pscustomobject]$PSItem.body) }
            }
        }
    }    
}