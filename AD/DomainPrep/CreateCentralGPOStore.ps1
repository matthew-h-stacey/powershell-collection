cls
$Sysvol = "\\localhost\sysvol\$env:USERDNSDOMAIN"
New-Item "$Sysvol\Policies\PolicyDefinitions" -ItemType directory -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
Copy-Item "C:\Windows\PolicyDefinitions\*" "$Sysvol\Policies\PolicyDefinitions" -Recurse -WarningAction SilentlyContinue -ErrorAction SilentlyContinue