# Note: Pulls more than strictly distribution groups. Will pull mail-enabled security groups, 365 Groups, etc. - any mail-enabled group recognized by Azure

param(
    # UPN of the user to pull distribution group membership for
    [Parameter(Mandatory=$true)]
    [String]
    $UserPrincipalName
)

# Retrieve all group memberships that have an email address associated with them
$groups = Get-AzureADUserMembership -ObjectId $UserPrincipalName | ? { $null -notlike $_.Mail } | sort DisplayName 

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