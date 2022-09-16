Param
(
    [Parameter(Mandatory=$true)][String]$GroupName, # displayName of the group to add users to
    [Parameter(ParameterSetName = "DisplayName")][Switch]$DisplayName, # use this switch if the txt file has a list of DisplayNames
    [Parameter(ParameterSetName = "UPN")][Switch]$UPN # use this switch if the txt file has a list of UPNs
)

# Check if already connected to AzureAD, connect if not connected
try { 
    Get-AzureADTenantDetail -ErrorAction Stop | Out-Null
} 
catch {
    Write-Host "[MODULE] Connecting to AzureAD, check for a pop-up authentication window"
    Connect-AzureAD | Out-Null
}

$usersToAdd = get-content C:\TempPath\users.txt

# Retrieve objectID of the group using DisplayName
$filter = "DisplayName eq '" + $GroupName + "'"
$groupID = Get-AzureADGroup -Filter $filter | Select-Object -ExpandProperty objectID

if ( $DisplayName) { 
    $allAzureADUsers = Get-AzureADUser -All $true | Select-Object DisplayName, UserPrincipalName, objectID
}

# Add user to group using groupID 
foreach ($u in $usersToAdd) {

    # Two methods to retrieve the AzureAD user
    if ( $DisplayName ) { 
        $uid = ($allAzureADUsers | Where-Object { $_.DisplayName -like $u }).objectID
        Write-Host "[AAD] Adding user $($u) to $($GroupName)"
        try {
            Add-AzureADGroupMember -ObjectId $groupID -RefObjectId $uid
        }
        catch {
            "[AAD] NOTICE: $($u) is already a member of $($GroupName)"
        }
        

    }
    if ( $UPN ) {
        $uid = (Get-AzureADUser -ObjectId $u).objectID
        Write-Host "[AAD] Adding user $($u) to $($GroupName)"
        try { 
            Add-AzureADGroupMember -ObjectId $groupID -RefObjectId $uid
        }
        catch {
            "[AAD] NOTICE: $($u) is already a member of $($GroupName)"
        }
    }
}