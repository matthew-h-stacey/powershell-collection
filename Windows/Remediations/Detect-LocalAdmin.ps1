# Logging
$OutputDirectory = "C:\Windows\System32\LogFiles\EndpointManager"
New-Folder -Path $OutputDirectory
$LogFile = "$OutputDirectory\LocalAdminUser.log"

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
        # Folder already exists, continue
    }

}

function Write-Log {
    param (
        [String]
        $LogString
    )
    Add-Content -Path $LogFile -Value "$(Get-Date -Format 'MM/dd/yyyy HH:mm:ss') $LogString"
}

function Detect-LocalAdmin {

    param (
        # Name of the local user to check for the presence of
        [Parameter(Mandatory = $true)]
        [String]
        $UserName
    )

    Write-Log "[INFO] Starting Detect-LocalAdmin. Username: $UserName"

    # First check to see if the local user exists. Proceed if they are, exit and trigger remediation if not
    $UserExists = (Get-LocalUser).Name -Contains $UserName

    if ($UserExists) { 
        # Next check if the user is a local admin

        # Query local administrators and format the output
        $LocalAdmins = ([ADSI]"WinNT://./Administrators").psbase.Invoke('Members') | ForEach-Object {
            ([ADSI]$_).InvokeGet('AdsPath')
        }
        $LocalAdmins = $LocalAdmins -replace 'WinNT://', '' -replace '/', '\' | Where-Object { $_ -notlike "S-1*" }
    
        # Check if the user is local admin, store result as boolean
        $IsLocalAdmin = ($LocalAdmins | ForEach-Object { $_ -like "*\$UserName" }) -contains $true
    
        # Provide exit codes depending on whether or not remediation is required
        switch ( $IsLocalAdmin ) {
            True {
                # User is already a local admin, no action needed. Write to the log and console output
                Write-Output "[INFO] User $UserName is already a local admin. No remediation needed"
                Write-Log "[INFO] User $UserName is already a local admin. No remediation needed"
                exit 0
            }
            False {
                # User is not a local admin, remediation required
                Write-Log "[INFO] User $UserName is not a local admin. Initiating remediation"
                exit 1
            }
        }

    } 
  
    # User does not exist, trigger remediation
    else {   
        Write-Log "[INFO] User $UserName is not present. Initiating remediation"
        exit 1
    }

}

Detect-LocalAdmin -UserName "cloud_laps"