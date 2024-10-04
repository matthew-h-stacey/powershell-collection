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
