function Get-ProfileSids {
    Get-ChildItem -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList" | ForEach-Object {
        [PSCustomObject]@{
            SID  = $_.PSChildName
            Path = (Get-ItemProperty $_.PSPath).ProfileImagePath
        }
    }
}

