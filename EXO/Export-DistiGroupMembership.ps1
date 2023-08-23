<#
Objective: Export a list of all distribution group and 365 groups as well as their membership
#>

# Retrieve organization name for filename exports
$tenantDisplayName = (Get-OrganizationConfig).DisplayName
$tenantDisplayName = $tenantDisplayName -replace " ", ""

# Export directory
$workDir = "C:\TempPath"

# List exports
$distiList = "$workDir\$($tenantDisplayName)_Distis_List.csv" # List of all Distis
$dynamicDistiList = "$workDir\$($tenantDisplayName)_Dynamic_Distis_List.csv" # List of all Dynamic Distis
$365GroupList = "$workDir\$($tenantDisplayName)_365_Groups_List.csv" # List of all 365 Groups

# Membership exports
$distiMembership = "$workDir\$($tenantDisplayName)_Distis_Membership.csv" # Membership of all Distis
$dynamicDistiMembership = "$workDir\$($tenantDisplayName)_Dynamic_Distis_Membership.csv" # Membership of all Dynamic Distis
$365GroupMembership = "$workDir\$($tenantDisplayName)_365_Group_Membership.csv" # Membership of all M365 Groups

# 1) Standard Distribution Group export

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

# 2) Dynamic Distribution List export

$results = @()
$allDistis | sort DisplayName | select DisplayName, PrimarySmtpAddress | Export-Csv $distiList -NoTypeInformation
$dynamicDLs = Get-DynamicDistributionGroup | sort DisplayName
$dynamicDLs | select DisplayName, PrimarySmtpAddress | Export-Csv $dynamicDistiList -NoTypeInformation
foreach ($ddl in $dynamicDLs) {
    $dynamicDL = Get-DynamicDistributionGroup -Identity $ddl.DistinguishedName
    $members = Get-Recipient -ResultSize Unlimited -RecipientPreviewFilter $dynamicDL.RecipientFilter -OrganizationalUnit $dynamicDL.RecipientContainer

    foreach ($member in $members) { 
        $dynamicDistiExport = [PSCustomObject]@{
        DistributionGroup   = $ddl.DisplayName
        MemberName              = $member.Name
        MemberEmail              = $member.PrimarySmtpAddress
        }
        $results += $dynamicDistiExport
    }
}
$results | Export-Csv $dynamicDistiMembership -NoTypeInformation

# 3) M365 Group export
$allGroups = Get-UnifiedGroup -ResultSize Unlimited | sort PrimarySmtpAddress
$allGroups | select DisplayName, PrimarySmtpAddress | Export-Csv $365GroupList -NoTypeInformation

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
$results | Export-Csv $365GroupMembership -NoTypeInformation