<#
.SYNOPSIS
Retrieve membership of all distribution groups

.EXAMPLE
$members = Get-EXODistributionGroupMembership

.NOTES
[ ] Add filter for specific group
#>

$membership = @()
$allDistis = Get-DistributionGroup -ResultSize Unlimited | Sort-Object DisplayName

foreach ($disti in $allDistis) {
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
