<#
.SYNOPSIS
	Exports CSV with all dynamic security groups and the membership critera.

.REQUIREMENTS
    Module - AzureADPreview

.NOTES
    If MembershipRule returns a blank cell, ensure you have the AzureADPreview module imported

#>

Import-Module AzureADPreview

$filepath = "C:\filepath\report.csv"
(Get-AzureADMSGroup -Filter "groupTypes/any(c:c eq 'DynamicMembership')" -All:$true) | select DisplayName,MembershipRule,ID | export-csv $filepath