$Users = Get-ChildItem -Path "Registry::HKEY_USERS"

foreach ($User in $Users) {
    $UserRegPath = "Registry::$($user.Name)"
    # Array containing the registry entries to add
    $RegEntries = @(
        @{
            Path  = $UserRegPath + "\SOFTWARE\Microsoft\Office\16.0\Common\Identity"
            Name  = "EnableADAL"
            Type  = "DWORD"
            Value = "1"
        },
        @{
            Path  = $UserRegPath + "\SOFTWARE\Microsoft\Office\16.0\Common\Identity"
            Name  = "DisableADALatopWAMOverride"
            Type  = "DWORD"
            Value = "1"
        },
        @{
            Path  = $UserRegPath + "\SOFTWARE\Microsoft\Office\16.0\Common\Identity"
            Name  = "DisableAADWAM"
            Type  = "DWORD"
            Value = "1"
        }
    )

    $RegEntries | ForEach-Object {
        # Create/update the value of the registry item
        try { 
            New-ItemProperty -Path $_.Path -Name $_.Name -Value $_.Value -PropertyType $_.Type -Force -ErrorAction Stop | Out-Null
            Write-Output "[INFO] Successfully created/updated the registry item: $($Item.Name)"
        }
        catch {
            Write-Output "[ERROR] Failed to create/update the registry item: $($Item.Name). Error: $($_.Exception.Message)"   
        }
    }

}