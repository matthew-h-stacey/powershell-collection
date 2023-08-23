Connect-ExchangeOnline

# 1)
# Export the current TransportRuleCollection (ALL transport rules) to XML

$file = Export-TransportRuleCollection;
Set-Content -Path "C:\TempPath\TransportRuleCollection_BACKUP.xml" -Value $file.FileData -Encoding Byte;

# 2) 
# Edit the XML, add or remove <rule>...</rule> as needed
# Save as .\TransportRuleCollection_Updated.xml to keep a backup

# 3
# Import the updated XML, which will overwrite ALL transport rules
[Byte[]]$Data = Get-Content -Path "C:\TempPath\TransportRuleCollection_Updated.xml" -Encoding Byte -ReadCount 0;
Import-TransportRuleCollection -FileData $Data;
