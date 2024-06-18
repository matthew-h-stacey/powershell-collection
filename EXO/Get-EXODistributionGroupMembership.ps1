<#
.SYNOPSIS
Retrieve membership of distribution groups

.EXAMPLE
$members = Get-EXODistributionGroupMembership
#>

param (
    [Parameter(Mandatory = $true, ParameterSetName = "All")]
    [switch]
    $All,

    [Parameter(Mandatory = $true, ParameterSetName = "Single")]
    [switch]
    $PrimarySmtpAddress
)

$membership = @()

switch ($PSCmdlet.ParameterSetName) {
    'All' {
        $distis = Get-DistributionGroup -ResultSize Unlimited | Sort-Object DisplayName
    }
    'Single' {
        try {
            $distis = Get-DistributionGroup -Identity $PrimarySmtpAddress -ErrorAction Stop
        } catch {
            Write-Output "[ERROR] Unable to locate distribution group: $PrimarySmtpAddress. Please check the provided value and try again."
            exit 1
        }
    }
}

foreach ($disti in $distis) {
    if ( $disti.ManagedBy) {
        $ownerId = $disti.ManagedBy
        $groupOwner = (Get-Recipient -Identity "$ownerId").DisplayName
    } else {
        $groupOwner = "N/A"
    }
    $distimember = Get-DistributionGroupMember -Identity $disti.PrimarySmtpAddress
    foreach ($m in $distimember) {
        $membership += [PSCustomObject]@{
            GroupName   = $disti.DisplayName
            GroupType   = "Distribution List"
            GroupOwner  = $groupOwner
            MemberName  = $m.DisplayName
            MemberEmail = $m.PrimarySmtpAddress
        }
    }
}
$membership
