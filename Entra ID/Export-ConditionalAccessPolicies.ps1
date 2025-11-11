function Export-ConditionalAccessPolicies {
    param(
        # Parameter help description
        [Parameter(Mandatory = $true)]
        [String]
        $Path,

        # Switch to back up all policies
        [parameter(ParameterSetName = "All")]
        [Switch]
        $All,

        # Switch to back up only one policy by name
        [parameter(ParameterSetName = "One")]
        [String]
        $Name
    )

    if ($PSCmdlet.ParameterSetName -eq "All") {
        $caPolicies = Get-MgIdentityConditionalAccessPolicy -All
    }
    if ($PSCmdlet.ParameterSetName -eq "One") {
        $filter = "displayName eq '" + $Name + "'"
        $caPolicies = Get-MgIdentityConditionalAccessPolicy -Filter $filter
    }
    foreach ( $policy in $caPolicies ) {
        $policyName = $policy.DisplayName -replace '[\\\/:\*\?"<>\|]', '_'
        $outputFile = Join-Path $Path "$($policyName).json"
        $policyJSON = $policy | ConvertTo-Json -Depth 6
        try {
            $policyJSON | Out-File $outputFile -Force
            Write-Output "[INFO] Exported policy to $outputFile"
        } catch {
            Write-Output "[ERROR] Failed to export policy $policyName to JSON. Error $($_.Exception.Message)"
        }
    }

}