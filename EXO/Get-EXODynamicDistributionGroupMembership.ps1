<#
.SYNOPSIS
Retrieve membership of all dynamic distribution groups

.EXAMPLE
$members = Get-EXODynamicDistributionGroupMembership

.NOTES
[ ] Add filter for specific group
#>

$membership = @()
$allDynamicDistis = Get-DynamicDistributionGroup -ResultSize Unlimited
foreach ( $dyndisti in $allDynamicDistis ) {
    if ( $dyndisti.ManagedBy) {
        $ownerId = $dyndisti.ManagedBy
        $groupOwner = (Get-Recipient -Identity "$ownerId").DisplayName
    } else {
        $groupOwner = "N/A"
    }
    $dyndistimembers = Get-Recipient -RecipientPreviewFilter ($dyndisti.RecipientFilter)
    foreach ( $m in $dyndistimembers ) {
        $membership += [PSCustomObject]@{
            GroupName   = $dyndisti.DisplayName
            GroupType   = "Dynamic Distribution List"
            GroupOwner  = $groupOwner
            MemberName  = $m.DisplayName
            MemberEmail = $m.PrimarySmtpAddress
        }
    }
}
$membership
