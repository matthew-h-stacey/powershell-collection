# Logging
$OutputDirectory = "C:\Windows\System32\LogFiles\EndpointManager"
New-Folder -Path $OutputDirectory
$LogFile = "$OutputDirectory\LocalAdminMembership.log"
Write-Log "[INFO] Starting Detect-LocalAdminMembership. Retain username: $UserName"

function New-Folder {
    Param([Parameter(Mandatory = $True)][String] $Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        try {
            New-Item -Path $Path -ItemType Directory -ErrorAction Stop | Out-Null
            Write-Host "Created folder: $Path"
        }
        catch {
            Write-Error -Message "Unable to create directory '$Path'. Error was: $_" -ErrorAction Stop
        }
    }
    else {
        "$Path already exists, continuing ..."
    }

}

function Write-Log {
    param (
        [String]
        $LogString
    )
    Add-Content -Path $LogFile -Value "$(Get-Date -Format 'MM/dd/yyyy HH:mm:ss') $LogString"
}

function Detect-LocalAdminMembership {

    param (
        # Enter the name of the user who should retain their admin access to the PC. Typically this should be a Windows LAPS account
        [Parameter(Mandatory=$true)]
        [String]
        $RetainAdmin
    )

    # Create a list of users that should be local admins (built-in admin + $RetainAdmin)
    $DesiredLocalAdmins = New-Object System.Collections.Generic.List[System.Object]
    $BuiltInAdmin = Get-LocalUser | Where-Object { $_.Description -like "Built-in account for administering the computer/domain" }
    $DesiredLocalAdmins.Add($BuiltInAdmin.Name)
    $DesiredLocalAdmins.Add($RetainAdmin)

    # Retrieve the current local administrators
    $LocalAdmins = ([ADSI]"WinNT://./Administrators").psbase.Invoke('Members') | ForEach-Object {
    ([ADSI]$_).InvokeGet('AdsPath')
    }
    $LocalAdmins = $LocalAdmins -replace 'WinNT://', '' -replace '/', '\' | Where-Object { $_ -notlike "S-1*" }

    # Determine if there are additional local admins
    $ExtraMembersPresent = $LocalAdmins | Where-Object { 
        $MemberWithoutDomain = $_.Split('\')[1]
        $DesiredLocalAdmins -notcontains $MemberWithoutDomain
    }

    try {
        # 
        if ($ExtraMembersPresent.Count -gt 0) {
            # Extra local admins are present, need to remove extras
            Write-Log "[INFO] Found extra local administrators. Executing the remediation script"
            exit 1
        }
        if ($ExtraMembersPresent.Count -eq 0) {
            # No extra local admins are present, no action needed
            Write-Log "[INFO] No extra local admins found. Skipping the remediation script, no action needed"
            exit 0
        }
    }
    catch {
        # Catch any exception and handle it
        Write-Error "[ERROR] Error encountered while attempting to determine if extra local admins are present. Error: $($_.Exception.Message)"
        exit 1
    }

}

Detect-LocalAdminMembership -RetainAdmin "cloud_laps"