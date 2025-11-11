# WIP

<#
function Test-WindowsService {
    param(
        [string]$ServiceName
    )

    try {
        $service = Get-Service -Name $ServiceName -ErrorAction Stop
    } catch {
        # service not found
    }
    return ($null -ne $service)
}

function Test-WindowsProgramInstalled {
    param (
        [string]$ProgramDisplayName
    )
    return $installedAppsHashTable.ContainsKey($ProgramDisplayName)

}
#>



function ConvertTo-HashTable {
    <#
        .SYNOPSIS
        Quick function to convert a list to hash table

        .PARAMETER Input
        The array or list to convert to a hash table

        .PARAMETER KeyName
        The identifier used to select entries from the hash table (ex: UserPrincipalName, Id, etc.)

        .EXAMPLE
        ConvertTo-HashTable -List $listObjects -KeyName UserPrincipalName
        #>
    param (
        [Parameter(Mandatory = $true)]
        [System.Object]
        $List,

        [Parameter(Mandatory = $true)]
        [string]
        $KeyName
    )

    $hashTable = @{}
    if ( $List ) {
        foreach ($item in $List) {
            if ( $item ) {
                if ( $item.$KeyName ) {
                    $hashTable[$item.$KeyName] = $item
                } else {
                    Write-Output "$KeyName does not exist on $item"
                }
            }
        }
        return $hashTable
    } else {
        Write-Error "No input provided"
    }

}

function Get-InstalledPrograms {
    # Get list of installed applications as hash table for easy lookup
    $installedApps = [System.Collections.Generic.List[System.Object]]::new()
    Get-ItemProperty 'HKLM:SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*' | ForEach-Object {
        $installedApps.Add([PSCustomObject][Ordered] @{
                'DisplayName'          = if ( $_.DisplayName ) { $_.DisplayName } else { $_.PSChildName }
                'UninstallString'      = $_.UninstallString
                'QuietUninstallString' = $_.QuietUninstallString
            })
    }
    Get-ItemProperty 'HKLM:SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' | ForEach-Object {
        $installedApps.Add([PSCustomObject][Ordered] @{
                'DisplayName'          = if ( $_.DisplayName ) { $_.DisplayName } else { $_.PSChildName }
                'UninstallString'      = $_.UninstallString
                'QuietUninstallString' = $_.QuietUninstallString
            })
    }
    $installedAppsHashTable = ConvertTo-HashTable -List $installedApps -KeyName DisplayName
}

switch ( Test-WindowsService -ServiceName ThreatLockerService ) {
    $true { Ninja-Property-Set devthreatlockerinstalled ebc27b22-073e-4c6c-9eb7-10cb082278b9 }
    $false { Ninja-Property-Set devthreatlockerinstalled f02f22b4-2181-46b9-9fcc-57237928e180 }
}

$csInstalled = Test-WindowsProgramInstalled -ProgramDisplayName "CrowdStrike Windows Sensor"
$qualysInstalled = Test-WindowsProgramInstalled -ProgramDisplayName "Qualys Cloud Security Agent"
$coveInstalled = Test-WindowsProgramInstalled -ProgramDisplayName "Backup Manager"
$umbrellaInstalled = Test-WindowsProgramInstalled -ProgramDisplayName "Cisco Secure Client - Umbrella"


<#
cove
umbrella
qualys

#>


