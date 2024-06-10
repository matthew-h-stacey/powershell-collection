<#
.SYNOPSIS
Retrieve membership of all Groups

.EXAMPLE
$members = Get-EXOUnifiedGroupMembership

.NOTES
[ ] Add filter for specific Group
#>

$membership = @()
$allGroups = Get-UnifiedGroup -ResultSize Unlimited | Sort-Object PrimarySmtpAddress
foreach ($g in $allGroups) {
    $groupOwner = (Get-UnifiedGroup -Identity $g.Name | Get-UnifiedGroupLinks -LinkType Owners).DisplayName -join ','
    $groupMembers = Get-UnifiedGroup -Identity $g.Name | Get-UnifiedGroupLinks -LinkType Members
    foreach ($m in $groupMembers) {
        $membership += [PSCustomObject]@{
            GroupName   = $g.DisplayName
            GroupType   = "M365 Group"
            GroupOwner  = $groupOwner
            MemberName  = $m.DisplayName
            MemberEmail = $m.PrimarySmtpAddress
        }
    }
}
$membership
