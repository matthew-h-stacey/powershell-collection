# Objective: Bulk add users to an Entra ID group

param
(
    [Parameter(Mandatory = $true)]
    [String]
    $GroupName,

    [Parameter(ParameterSetName = "DisplayName")]
    [Switch]
    $DisplayName,

    [Parameter(ParameterSetName = "UPN")]
    [Switch]
    $UPN
)

# Local file for input
$users = Get-Content C:\TempPath\users.txt

# Locate group by DisplayName to get group ID
$group = Get-MgGroup -Filter "DisplayName eq '$GroupName'" -WarningAction Stop -ErrorAction Stop
if ( -not $group ) {
    Write-Error "Group '$GroupName' not found in Entra. Exiting script."
    exit 1
}

# Add user to group using group ID
foreach ($u in $users) {
    # Locate user by DisplayName or UPN to get user ID
    $user = $null
    if ( $DisplayName ) {
        $user = Get-MgUser -Filter "DisplayName eq '$u'" -WarningAction Stop -ErrorAction Stop
    }
    if ( $UPN ) {
        $user = Get-MgUser -Filter "UserPrincipalName eq '$u'" -WarningAction Stop -ErrorAction Stop
    }
    if ( $user ) {
        $uid = $user.Id
    } else {
        Write-Error "User with DisplayName '$u' not found in Entra. Skipping user."
        continue
    }
    # Check to see if the user is already a member of the group
    $isMember = Get-MgGroupMember -GroupId $group.Id -Filter "id eq '$uid'" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
    if ( $isMember ) {
        Write-Output "User '$u' is already a member of group '$GroupName'. Skipping user."
        continue
    }

    # Add user to group
    $params = @{
        "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$uid"
    }
    try {
        New-MgGroupMemberByRef -GroupId $group.Id -BodyParameter $params -ErrorAction Stop
        Write-Output "Successfully added user '$u' to group '$GroupName'"
    } catch {
        Write-Error "Failed to add user '$u' to group '$GroupName'. Error: $_"
    }
}