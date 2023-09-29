# Remove all members of a group except the specified user
# Example usage: Clear-LocalGroupMembership -Group Administrators -Except MyLocalAdminAccount

param(

    [Parameter(Mandatory = $true)]
    [String]
    $GroupName,

    [Parameter(Mandatory = $true)]
    [String]
    $Except

)

function Write-Log {
    Param ([string]$logstring)
    Add-Content $logFile -Value "$(Get-Date -Format "MM/dd/yyyy HH:mm") $logstring"
}

function New-Folder {
    Param([Parameter(Mandatory = $True)][String] $folderPath)
    if (-not (Test-Path -LiteralPath $folderPath)) {
        try {
            New-Item -Path $folderPath -ItemType Directory -ErrorAction Stop | Out-Null
            Write-Host "Created folder: $folderPath"
        }
        catch {
            Write-Error -Message "Unable to create directory '$folderPath'. Error was: $_" -ErrorAction Stop
        }
    }
    else {
        # FolderPath already exists, continue
    }

}

# Logging
$OutputDirectory = "C:\Windows\System32\LogFiles\EndpointManager"
New-Folder $OutputDirectory
$LogFile = "$OutputDirectory\Clear-LocalGroupMembership.log" 

# Build $ExcludedUsers list which contains the built-in admin account and the provided $Except user
$ExcludedUsers = New-Object System.Collections.Generic.List[System.Object]
$BuiltInAdmin = Get-LocalUser | Where-Object { $_.Description -like "Built-in account for administering the computer/domain" }
$ExcludedUsers.Add($BuiltInAdmin.Name)
$ExcludedUsers.Add("$Except")

# Iterate through each member of the group. If the user is not in the $ExcludedUsers array, remove them from the group
# All output is logged to $LogFile
$Members = Get-LocalGroup -Name $GroupName | Get-LocalGroupMember
foreach ($Member in $Members) {

    $MemberName = $Member.Name.split("\")[1] 
    if ( $ExcludedUsers -contains $MemberName  ) {
        Write-Log "[INFO] ${GroupName}: Skipped $MemberName"
    }
    if ( $ExcludedUsers -notcontains $MemberName ) {
        try {
            Remove-LocalGroupMember -Group $GroupName -Member $Member.Name -ErrorAction Stop
            Write-Log "[INFO] ${GroupName}: Removed $($Member.Name)" 
        }
        catch {
            Write-Log "[ERROR] ${GroupName}: Failed to remove $($Member.Name) from group. Error: $($_.Exception.Message)" 
        }
    }
}