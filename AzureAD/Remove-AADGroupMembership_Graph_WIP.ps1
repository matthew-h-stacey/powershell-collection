param(
    [Parameter(Mandatory=$true)][string]$TenantID,
    [Parameter(Mandatory = $true)][string]$ClientID,
    [Parameter(Mandatory=$true)][String]$UserPrincipalName
)

 # grab user cert
$certName = [System.Environment]::UserName + "-" + [system.environment]::MachineName
$certThumbprint = Get-ChildItem Cert:\CurrentUser\My\ | Where-Object { $_.Subject -like "*$certName*" } | Select-Object -ExpandProperty Thumbprint

# Connect to MgGraph, if not already connected
if ( $null -eq (Get-MgContext)) {
    Connect-MgGraph -TenantId $tenantID -ClientID $clientID -CertificateThumbprint $certThumbprint | Out-Null
}

$AADGroupMembershipReport = @() # Array used for the total output of group removal

$filter = "startsWith(UserPrincipalName,'" + $UserPrincipalName + "')"
$MgUser = Get-MgUser -Filter $filter -ErrorAction Stop 
if ( $null -eq $MgUser) {
    Write-Output "ERROR: Unable to find user"
    break # Stop if the user cannot be found
}

# First get all groups the user is a member of
$MgUserGroups = Get-MgUserMemberOf -UserId $MgUser.Id | Sort-Object Id
foreach ($g in $MgUserGroups){
    $groupDisplayName = ($g | Select-Object -ExpandProperty AdditionalProperties).Item('displayName')
    if (( Get-MgGroup -GroupId $g.Id).GroupTypes -like "DynamicMembership" ){ # Find any Dynamic groups
        # if Dynamic, do nothing
    }
    else { 
        $AADGroupMembershipReport += $groupDisplayName # Add the group DisplayName to the array for output
        # https://docs.microsoft.com/en-us/graph/api/group-delete-members?view=graph-rest-beta&tabs=http
        # https://rakhesh.com/azure/graph-powershell-remove-member-from-group/
        Write-Host "Removing $($MgUser.UserPrincipalName) from AzureAD group: $($groupDisplayName)"
        $ref = '$ref'
        Invoke-MgGraphRequest -Method Delete -Uri "https://graph.microsoft.com/v1.0/groups/$($g.Id)/members/$($MgUser.Id)/$ref"
    }
}    

$AADGroupMembershipReport = $AADGroupMembershipReport | Sort-Object # sort alphbetically