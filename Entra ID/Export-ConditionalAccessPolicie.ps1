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
        $Input = Get-MgIdentityConditionalAccessPolicy -All
    }
    if ($PSCmdlet.ParameterSetName -eq "One") {
        $Filter = "displayName eq '" + $Name + "'"
        $Input = Get-MgIdentityConditionalAccessPolicy -Filter $Filter
    }
    $Input | ForEach-Object {
        $PolicyName = $_.DisplayName
        # Convert the policy to JSON with a depth of 6. This will expand the full property values of each section instead of returning Microsoft.Graph.* objects
        $PolicyJSON = $Policy | ConvertTo-Json -Depth 6
        $OutputFile = "$Path\$PolicyName.json"
        try {
            $PolicyJSON | Out-File $OutputFile -Force
            Write-Output "[INFO] Exported policy to $OutputFile"
        }
        catch {
            Write-Output "[ERROR] Failed to export policy $PolicyName to JSON. Error $($_.Exception.Message)"
        }
    }
}