<#
Description:
ISO 8601 timestamp for Powershell logging/output
Example output: 2024-08-21T15:26:58-04:00
#>

# Example 1: Write-Output
$timeStamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssK"
Write-Output "$timeStamp [SUCCESS] Thing succeeded!"

# Example 2: File name for output
$resultsOutput = "$ExportPath\myOutput_$((Get-Date -Format 'yyyy-MM-dd_HHmm')).csv"
# -> \myOutput_2024-10-04_1111.csv

# Example 3: Script timestamp and duration
$start = Get-Date
...
#script here
...
$now = Get-Date
$duration = New-TimeSpan -Start $start -End $now

$nowFormatted = $now.ToString("yyyy-MM-dd HH:mm:ss")

if ($duration.TotalMinutes -lt 1) {
    Write-Host "Script finished at $nowFormatted. Duration: $($duration.Seconds) seconds."
} else {
    Write-Host "Script finished at $nowFormatted. Duration: $($duration.Minutes) minutes and $($duration.Seconds) seconds."
}

