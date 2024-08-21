<#
Description:

ISO 8601 timestamp for Powershell logging/output
Example output: 2024-08-21T15:26:58-04:00

#>

$timeStamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssK"
Write-Output "$timeStamp [SUCCESS] Thing succeeded!"