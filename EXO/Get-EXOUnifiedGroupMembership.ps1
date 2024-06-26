<#
.SYNOPSIS
Retrieve membership of Microsoft 365 Groups

.EXAMPLE
$members = Get-EXOUnifiedGroupMembership -All

#>

param (
    [Parameter(Mandatory = $true, ParameterSetName = "All")]
    [switch]
    $All,

    [Parameter(Mandatory = $true, ParameterSetName = "Single")]
    [string]
    $PrimarySmtpAddress
)

switch ($PSCmdlet.ParameterSetName) {
    'All' {
        $filter = "groupTypes/any(c:c eq 'Unified')"
        $groups = Get-MgGroup -Filter $filter -ExpandProperty Owners | Sort-Object DisplayName
    }
    'Single' {
        try {
            $filter = "groupTypes/any(c:c eq 'Unified') and mail eq '$PrimarySmtpAddress'" 
            $groups = Get-MgGroup -Filter $filter -ExpandProperty Owners | Sort-Object DisplayName
        } catch {
            Write-Output "[ERROR] Unable to locate Microsoft 365 group: $PrimarySmtpAddress. Please check the provided value and try again."
            exit 1
        }
    }
}

$membership = @()
foreach ($group in $groups) {
    $groupOwner = $group.Owners.AdditionalProperties.displayName
    Get-MgGroupMember -GroupId $group.Id | ForEach-Object {
        $membership += [PSCustomObject]@{
            GroupName   = $group.DisplayName
            GroupType   = "M365 Group"
            GroupOwner  = $groupOwner -join ', '
            MemberName  = $_.AdditionalProperties.displayName
            MemberEmail = $_.AdditionalProperties.userPrincipalName
        }
    }
}
$membership