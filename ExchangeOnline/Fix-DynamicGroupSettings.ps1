# Get group
$dynamicGroup = Get-DynamicDistributionGroup YourGroup

# Pre-check
$dynamicGroupMembers = Get-Recipient -RecipientPreviewFilter $dynamicGroup.RecipientFilter
$dynamicGroupMembers | Sort-Object Name

# Re-apply filter
Set-DynamicDistributionGroup -Identity $dynamicGroup.Identity -RecipientFilter {(RecipientTypeDetails -eq 'UserMailbox')}

#Post-check
$dynamicGroupMembers = Get-Recipient -RecipientPreviewFilter $dynamicGroup.RecipientFilter
$dynamicGroupMembers | Sort-Object Name