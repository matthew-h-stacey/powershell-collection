<#
.SYNOPSIS
This script exports user pictures from a tenant. It is run on all users, all enabled users, or a specific list of users

.EXAMPLE
Get-UserPictures -ClientName contoso -EnabledOnly
#>

param(   
    # Name of the client. Used in the export folder path
    [Parameter(Mandatory = $true)]
    [string]
    $ClientName,

    # Export pictures for all mailboxes
    [parameter(Mandatory = $true, ParameterSetName = "All")]
    [switch]
    $All,
    
    # Only export pictures for enabled accounts
    [parameter(Mandatory = $true,ParameterSetName = "EnabledOnly")]
    [switch]
    $EnabledOnly,

    # CSV with a list of UserPrincipalNames
    [parameter(Mandatory = $true,ParameterSetName = "CSV")]
    [string]
    $CSV,

    # Path to export results to
    [Parameter(Mandatory = $true)]
    [String]
    $ExportPath
)

function New-Folder {
    
    <#
    .SYNOPSIS
    Determine if a folder already exists, or create it  if not.

    .EXAMPLE
    New-Folder C:\TempPath
    #>

    param(
        [Parameter(Mandatory = $True)]
        [String]
        $Path
    )
    if (-not (Test-Path -LiteralPath $Path)) {
        try {
            New-Item -Path $Path -ItemType Directory -ErrorAction Stop | Out-Null
        } catch {
            Write-Error -Message "Unable to create directory '$Path'. Error was: $_" -ErrorAction Stop
        }
    } 

}

# Trim trailing "\" and add subfolders
$ExportPath = $ExportPath = "$($ExportPath.TrimEnd("\"))\${ClientName}\UserPictures" 

# Create new folder to export pictures to
New-Folder $ExportPath

# Build array with the user mailboxes
switch ($PSCmdlet.ParameterSetName) {
    'All' {
        $users = Get-MgUser -All | Sort-Object UserPrincipalName
        Write-Output "[INFO] Exporting user profile pictures from ALL users"
    }
    'EnabledOnly' {
        $users = Get-MgUser -Filter "accountEnabled eq true"
        Write-Output "[INFO] Exporting user profile pictures from all ENABLED users"
    }
    'CSV' {
        $users = Import-Csv -Path $CSV | Sort-Object UserPrincipalName
        Write-Output "[INFO] Exporting user profile pictures from all users in CSV"
    }
}

# Process all mailboxes in the foreach
# Export all pictures to $ExportPath
foreach ($mailbox in $users) {
    $photo = $null
    $UPN = $mailbox.UserPrincipalName
    $output = "$ExportPath\${UPN}.jpg"
    try {
        $photo = Get-MgUserPhoto -UserId $UPN -ErrorAction Stop -WarningAction Stop
    } catch {
        Write-Output "[SKIPPED] $UPN does not have a picture"
    }
    if ($photo) {
        Get-MgUserPhotoContent -UserId $UPN -OutFile $output
        Write-Output "[INFO] $UPN picture exported to: $output"
    }
}