$DaysInactive = 90
$time = (Get-Date).Adddays( - ($DaysInactive))

Get-ADComputer -Filter { LastLogonTimeStamp -lt $time } -ResultPageSize 2000 -resultSetSize $null -Properties * | select Name, OperatingSystem, @{N = 'LastLogonTimestamp'; E = { [DateTime]::FromFileTime($_.LastLogonTimeStamp) } }, DistinguishedName | export-csv c:\TempPath\OldPCs.csv -NoTypeInformation
Get-ADUser -Filter { LastLogonTimeStamp -lt $time } -ResultPageSize 2000 -resultSetSize $null -Properties * | select Name, @{N = 'LastLogonTimestamp'; E = { [DateTime]::FromFileTime($_.LastLogonTimeStamp) } }, DistinguishedName | export-csv C:\TempPath\oldUsers.csv -NoTypeInformation