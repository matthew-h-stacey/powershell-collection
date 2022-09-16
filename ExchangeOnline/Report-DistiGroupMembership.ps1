<#
Objective: Get a report of all distribution group membership
#>

# 1) Regular DistributionGroup export
$workDir = "C:\TempPath"
$distiList = "$workDir\Report_Distis_List.csv" # List of all Distis
$distiMembership = "$workDir\Report_Distis_Membership.csv" # Membership of all Distis
$365GroupList = "$workDir\Report_365Group_List.csv" # List of all M365 Groups


$allDistis = Get-DistributionGroup -ResultSize Unlimited | sort DisplayName
$allDistis | sort DisplayName | select DisplayName, PrimarySmtpAddress | Export-Csv $distiList -NoTypeInformation

$results = @()
foreach ($disti in $allDistis) {
    $distimember = Get-DistributionGroupMember -Identity $disti.PrimarySmtpAddress
    foreach ($d in $distimember) {
        $distiExport = [PSCustomObject]@{
        DistributionGroup   = $disti.DisplayName
        MemberName              = $d.Name
        MemberEmail              = $d.PrimarySmtpAddress
        }
        $results += $distiExport
    }
}
$results | Export-Csv $distiMembership -NoTypeInformation

# 2) M365 Group export
$allGroups = Get-UnifiedGroup -ResultSize Unlimited | sort PrimarySmtpAddress
$results = @()
foreach($g in $allGroups){
    $groupOwner = (Get-UnifiedGroup -Identity $g.Name | Get-UnifiedGroupLinks -LinkType Owner | select -expand PrimarySmtpAddress) -join ','
    $groupMembers = Get-UnifiedGroup -Identity $g.Name | Get-UnifiedGroupLinks -LinkType Member
    foreach($m in $groupMembers){
            #GroupEmail = $g.PrimarySmtpAddress
        $groupExport = [PSCustomObject]@{
            O365Group = $g
            MemberName  = $m.Name
            MemberEmail     = $m.PrimarySmtpAddress
            O365GroupOwner = $groupOwner
        }
        $results += $groupExport  
    }
}
$results | Export-Csv $365GroupList -NoTypeInformation