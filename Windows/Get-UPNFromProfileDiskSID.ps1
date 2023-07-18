$Output = @()
$Warnings = @()

$Path = "D:\Shares\RDS.Profiles"
$VHDs = Get-ChildItem -Path $Path | ? {$_.Extension -eq ".vhdx" -and $_.Name -notLike "*template*"}

$VHDs | ForEach-Object { 
    $SID = $_.Name -replace '^UVHD-(.*)\.vhdx$', '$1'
    try {
        $ADUser = Get-ADUser $SID
        $Output += [PSCustomObject]@{
            UserPrincipalName = $ADUser.UserPrincipalName
            SID = $SID
        }
    }
    catch {
        $Output += [PSCustomObject]@{
            UserPrincipalName = "Unknown"
            SID = $SID
        }
        $Warnings += "WARNING: Unable to locate user with SID: $SID"
    }
   
} 

$Output | sort UserPrincipalName
$Warnings | sort
