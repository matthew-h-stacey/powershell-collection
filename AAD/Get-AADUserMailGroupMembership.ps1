<#
.SYNOPSIS
	Return a list of mail-enabled groups that a user is a member of.

.DESCRIPTION
	This script uses the output of Get-AzureADUserMembership to output a list of all mail-enabled groups (distribution groups, 365 Groups, mail-enabled security groups) that a user is a member of.

.PARAMETER UserPrincipalName
	The UserPrincipalName of the user to do the mail group membership lookup for.

.EXAMPLE
	Get-AADUserMailGroupMembership.ps1 -UserPrincipalName jsmith@contoso.com

.NOTES
	Author: Matt Stacey
	Date:   March 28, 2023
	Tags: 	
#>

param(
    # UPN of the user to pull distribution group membership for
    [Parameter(Mandatory=$true)]
    [String]
    $UserPrincipalName
)

# Retrieve all group memberships that have an email address associated with them
$groups = Get-AzureADUserMembership -ObjectId $UserPrincipalName | Where-Object { $null -notlike $_.Mail } | Sort-Object DisplayName 

# Iterate through the array and report the results
$results =  @()
foreach ( $g in $groups){
    if ( $null -eq $g.OnPremisesSecurityIdentifier ) { $source = "Office365" }
    if ( $null -ne $g.OnPremisesSecurityIdentifier ) { $source = "On-premAD" }
    $groupExport = [PSCustomObject]@{
        DisplayName = $g.DisplayName
        Mail = $g.Mail
        Source = $source
    }
    $results += $groupExport
}
$results