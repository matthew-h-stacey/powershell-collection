$searchDirectory = E:\Users
$excludeDirectory = "E:\UserProfiles"
$missingFolder = "*FolderName*"

Get-ChildItem -Path $searchDirectory -Exclude $excludeDirectory -Recurse -WarningAction SilentlyContinue -ErrorAction SilentlyContinue | ?{$_.PSIsContainer -eq $true
-and $_.Name -like $missingFolder } | select -ExpandProperty FullName