function New-RegistryEntry {

    param (
        [Parameter(Mandatory = $true)][String]$Path, # Path in the registry, including key name (ex: "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Associations")
        [Parameter(Mandatory = $true)][String]$Type, # Type of registry entry (ex: "String", "DWORD")
        [Parameter(Mandatory = $true)][String]$Name, # Name of the registry entry (ex: "LowRiskFileTypes")
        [Parameter(Mandatory = $true)][String]$Value # Value of the registry entry (ex: ".pdf;.epub;.ica")
    )

    # Create the registry key if it does not exist
    if ((Test-Path -LiteralPath $Path) -ne $true) {  
        try {
            New-Item $Path -Force -ErrorAction Stop | Out-Null
            Write-Output "[INFO] Created new registry key: $Path" 
        }
        catch {
            Write-Output "[ERROR] Failed to create new registry key: $Path. Error: $($_.Exception.Message)"
            exit 1
        }
    }

    # Create/update registry entry if it does not exist
    $CurrentValue = (Get-ItemProperty $Path).$Name
    if ( $CurrentValue -ne $Value ) {
        try {
            New-ItemProperty -LiteralPath $Path -Name $Name -Value $Value -PropertyType $Type -Force | Out-Null
            Write-Output "[INFO] Created new registry $Type"
            Write-Output "- Name: $Name"
            Write-Output "- Path: $Path"
            Write-Output "- Value: $Value" 
        }
        catch {
            Write-Output "[ERROR] Failed to create new registry ${Type} in $Path. Error: $($_.Exception.Message)"
            exit 1
        }
    }
    else {
        # Value matches
        Write-Output "[INFO] Registry $Type $Name in $Path is already set to $Value"
        exit 0
    }
}

$Skip = @(".DEFAULT", "S-1-5-18")
$Users = Get-ChildItem -Path "Registry::HKEY_USERS"
$Users = $Users | Where-Object { $_.PSChildName -notLike "*Classes*" -and $_.PSChildName -NotIn $Skip } 

foreach ($User in $Users) {
    $UserKey = $User.Name

    $params = @{
        Path  = "Registry::$UserKey\Policies\Microsoft\Windows\WindowsCopilot"
        Type  = "DWORD"
        Name  = "TurnOffWindowsCopilot"
        Value = "1"
    }

    New-RegistryEntry @params
}       