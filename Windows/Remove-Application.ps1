param(
    
    [Parameter(Mandatory = $true)][String]$DisplayName

)

function Remove-Application ([PSCustomObject]$Application) {
    if ($null -ne $Application.QuietUninstallString) {
        Write-Output "Located QuietUninstallString: $($Application.QuietUninstallString)"
    
        $ExtractedString = $Application.QuietUninstallString
        $Regex = [regex]'"([^"]+)"(.*)'
        $Matches = $regex.Match($extractedString)
        $Path = $matches.Groups[1].Value
        $Arguments = $matches.Groups[2].Value.Trim().Split(' ')
        if ( $Arguments.Contains -inotmatches "/NORESTART" ){
            "Arugments contains /NORESTART"
        }

        Write-Output "Attempting to uninstall application ..."
        
        try {
            Start-Process $Path -ArgumentList $Arguments -NoNewWindow -Wait
        }
        catch {
            Write-Error "An error occurred when attempting to uninstall the application:"
            Write-Output $_
        }

    }
    else {

        Write-Output "Attempting to uninstall application ..."

        try {
            Start-Process $Application.UninstallString -ArgumentList $Arguments -NoNewWindow -Wait
        }
        catch {
            Write-Error "An error occurred when attempting to uninstall the application:"
            Write-Output $_
        }


    }
}


$Apps32bit = @()
$Apps32bit += Get-ItemProperty "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" # 32 Bit

$Apps64bit = @()
$Apps64bit += Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"  

Write-Output "Attempting to locate 32-bit version of application: $($DisplayName) ..."
$AppToRemove32bit = $Apps32bit | ? { $_.DisplayName -like $DisplayName }
if ( $null -ne $AppToRemove32bit ) {
    Write-Output "Located 32-bit application $($AppToRemove32bit.DisplayName). Publisher $($AppToRemove32bit.Publisher)."
    Remove-Application $AppToRemove32bit
}
else {
    Write-Output "No 32-bit installed application: $DisplayName. Checking 64-bit next ..."
}

$AppToRemove64bit = $Apps64bit | ? { $_.DisplayName -like $DisplayName }
if ( $null -ne $AppToRemove64bit ) {
    Write-Output "Located 64-bit application $($AppToRemove64bit.DisplayName). Publisher $($AppToRemove64bit.Publisher)."
    Remove-Application $AppToRemove64bit
}
else {
    Write-Output "No 64-bit installed application: $DisplayName."
}