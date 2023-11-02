# Local account used for Windows LAPS
$UserName = "cloud_laps"
$UserDescription = "User account for Cloud LAPS"

# Logging
$OutputDirectory = "C:\Windows\System32\LogFiles\EndpointManager"
$LogFile = "$OutputDirectory\LocalAdminUser.log"
Write-Log "[INFO] Starting Remediate-LocalAdmin. Username: $UserName" 

function Get-RandomPassword {
    # Generate a random 32-character password

    param (
        [Parameter(Mandatory)]
        [int] $Length
    )
    
    $CharSet = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()'.ToCharArray()
    $Password = -join (Get-Random -InputObject $CharSet -Count 32)
    
    return $Password

}

function Get-LocalAdmins {
    # Retrieve a list of local admins (not including SID objects which are commonly unrecognized user accounts, or Azure AD roles/groups)

    $LocalAdmins = ([ADSI]"WinNT://./Administrators").psbase.Invoke('Members') | ForEach-Object {
        ([ADSI]$_).InvokeGet('AdsPath')
    }
    $LocalAdminList = $LocalAdmins -replace 'WinNT://', '' -replace '/', '\' | Where-Object { $_ -notlike "S-1*" }

    return $LocalAdminList
}

function Write-Log {
    param (
        [String]
        $LogString
    )
    Add-Content -Path $LogFile -Value "$(Get-Date -Format 'MM/dd/yyyy HH:mm:ss') $LogString"
}

function Remediate-LocalAdmin {

    param (
        # Username for the new local admin
        [Parameter(Mandatory = $true)]
        [String]
        $UserName,

        # Description for the new local admin
        [Parameter(Mandatory = $false)]
        [String]
        $UserDescription
    )

    $UserExists = (Get-LocalUser).Name -Contains $UserName

    switch ($UserExists ) {
        True {
            $LocalAdmins = Get-LocalAdmins
    
            # Check if the user is local admin, store result as boolean
            $IsLocalAdmin = ($LocalAdmins | ForEach-Object { $_ -like "*\$UserName" }) -contains $true

            if (-not $IsLocalAdmin) {
                try {
                    Add-LocalGroupMember -Group Administrators -Member $UserName
                    Write-Log "[INFO] Added $UserName to Administrators"
                }
                catch {
                    Write-Log "[ERROR] An error occurred when attempting to add $UserName to Administrators. Error: $($_.Exception.Message)"
                }
                exit 0
            }
            else {
                Write-Log "[INFO] User $UserName is already a local admin. Exiting remediation"
                exit 0
            }
        }
        False {
            $Password = (ConvertTo-SecureString (Get-RandomPassword -Length $PasswordLength) -AsPlainText -Force)

            $params = @{
                Name        = $UserName
                Password    = $Password
                Description = $UserDescription
            }

            try { 
                New-LocalUser @params
                Add-LocalGroupMember -Group Administrators -Member $UserName
                Write-Log "[INFO] Successfully created a new local admin account: $UserName"
                exit 0
            }   
            catch {
                Write-error $_
                exit 1
            } 
        }

    }

}

Remediate-LocalAdmin -UserName $UserName -UserDescription $UserDescription