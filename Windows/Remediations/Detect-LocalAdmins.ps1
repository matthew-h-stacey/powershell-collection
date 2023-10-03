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

# Name of the Cloud LAPS user that should remain a local admin
$DesiredAdminName = "BCS365_TEST"

# Create list of users that should be local admins (built-in admin + $DesiredAdminName)
$DesiredLocalAdmins = New-Object System.Collections.Generic.List[System.Object]
$BuiltInAdmin = Get-LocalUser | Where-Object {$_.Description -like "Built-in account for administering the computer/domain"}
$DesiredLocalAdmins.Add($BuiltInAdmin.Name)
$DesiredLocalAdmins.Add($DesiredAdminName)

# Retrieve the current local administrators
$LocalAdmins = ([ADSI]"WinNT://./Administrators").psbase.Invoke('Members') | % {
 ([ADSI]$_).InvokeGet('AdsPath')
}
$LocalAdmins = $LocalAdmins -replace 'WinNT://', '' -replace '/', '\' | ?{$_ -notlike "S-1*"}

# Determine if there are additional local admins
$ExtraMembersPresent = $LocalAdmins | Where-Object { 
    $MemberWithoutDomain = $_.Split('\')[1]
    $DesiredLocalAdmins -notcontains $MemberWithoutDomain
}

try {
    # If extra local admins are present, throw an exception
    if ($ExtraMembersPresent.Count -gt 0) {
        Write-Log "[INFO] Found extra local administrators. Executing the remediation script"
        exit 1
    }
    if ($ExtraMembersPresent.Count -eq 0) {
        # If no extra local admins are present, exit code 0
        Write-Log "[INFO] No extra local admins found. Skipping the remediation script, no action needed"
        exit 0
    }
}
catch {
    # Catch any exception and handle it
    Write-Error "Error: $_"
    exit 1
}