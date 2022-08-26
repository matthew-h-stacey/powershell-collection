Get-SPOSite -Filter { Url -like "*/personal/*" } -IncludePersonalSite $true -Limit ALL | sort Url | select Owner, StorageUsageCurrent | Export-Csv C:\TempPath\OneDrive_usage.csv -NoTypeInformation