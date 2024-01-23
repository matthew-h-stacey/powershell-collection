function Get-DistributionGroupMembership {

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

}

function Get-DynamicDistributionGroupMembership {

    $membership = @()
    $allDynamicDistis = Get-DynamicDistributionGroup -ResultSize Unlimited
    foreach ( $dyndisti in $allDynamicDistis ) {
        if ( $dyndisti.ManagedBy) {
            $ownerId = $disti.ManagedBy
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

}

function Get-UnifiedGroupMembership {

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
                MemberName  = $m.Name
                MemberEmail = $m.PrimarySmtpAddress
            }
        }
    }
    $membership

}
$reportTitle = "Email Group Membership Report"
$results = @()
$results += Get-DistributionGroupMembership
$results += Get-DynamicDistributionGroupMembership
$results += Get-UnifiedGroupMembership
Out-SKSolutionReport -Content $results -OutToHTML "New tab" -ReportTitle $reportTitle -IncludePartnerLogo:$true