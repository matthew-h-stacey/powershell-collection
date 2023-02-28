Set-ExecutionPolicy Unrestricted -Force
$ErrorActionPreference = 'SilentlyContinue'
New-PSDrive -PSProvider Registry -Name HKU -Root HKEY_USERS
Remove-Item -Path "HKU:\*\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -Recurse
New-Item -Path "HKU:\*\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" -Name "User Shell Folders" -Force | Out-Null
New-ItemProperty -Path "HKU:\*\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -Name "{374DE290-123F-4565-9164-39C4925E467B}" -Value "%USERPROFILE%\Downloads" -PropertyType ExpandString 
New-ItemProperty -Path "HKU:\*\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -Name "AppData" -Value "%USERPROFILE%\AppData\Roaming" -PropertyType ExpandString 
New-ItemProperty -Path "HKU:\*\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -Name "Cache" -Value "%USERPROFILE%\AppData\Local\Microsoft\Windows\INetCache" -PropertyType ExpandString 
New-ItemProperty -Path "HKU:\*\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -Name "Cookies" -Value "%USERPROFILE%\AppData\Local\Microsoft\Windows\INetCookies" -PropertyType ExpandString 
New-ItemProperty -Path "HKU:\*\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -Name "Desktop" -Value "%USERPROFILE%\Desktop" -PropertyType ExpandString 
New-ItemProperty -Path "HKU:\*\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -Name "Favorites" -Value "%USERPROFILE%\Favorites" -PropertyType ExpandString 
New-ItemProperty -Path "HKU:\*\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -Name "History" -Value "%USERPROFILE%\AppData\Local\Microsoft\Windows\History" -PropertyType ExpandString 
New-ItemProperty -Path "HKU:\*\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -Name "Local AppData" -Value "%USERPROFILE%\AppData\Local" -PropertyType ExpandString 
New-ItemProperty -Path "HKU:\*\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -Name "My Music" -Value "%USERPROFILE%\Music" -PropertyType ExpandString 
New-ItemProperty -Path "HKU:\*\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -Name "My Pictures" -Value "%USERPROFILE%\Pictures" -PropertyType ExpandString 
New-ItemProperty -Path "HKU:\*\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -Name "My Video" -Value "%USERPROFILE%\Videos" -PropertyType ExpandString 
New-ItemProperty -Path "HKU:\*\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -Name "NetHood" -Value "%USERPROFILE%\AppData\Roaming\Microsoft\Windows\Network Shortcuts" -PropertyType ExpandString 
New-ItemProperty -Path "HKU:\*\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -Name "Personal" -Value "%USERPROFILE%\Documents" -PropertyType ExpandString 
New-ItemProperty -Path "HKU:\*\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -Name "PrintHood" -Value "%USERPROFILE%\AppData\Roaming\Microsoft\Windows\Printer Shortcuts" -PropertyType ExpandString 
New-ItemProperty -Path "HKU:\*\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -Name "Programs" -Value "%USERPROFILE%\AppData\Roaming\Microsoft\Windows\Start Menu\Programs" -PropertyType ExpandString 
New-ItemProperty -Path "HKU:\*\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -Name "Recent" -Value "%USERPROFILE%\AppData\Roaming\Microsoft\Windows\Recent" -PropertyType ExpandString 
New-ItemProperty -Path "HKU:\*\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -Name "SendTo" -Value "%USERPROFILE%\AppData\Roaming\Microsoft\Windows\SendTo" -PropertyType ExpandString 
New-ItemProperty -Path "HKU:\*\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -Name "Start Menu" -Value "%USERPROFILE%\AppData\Roaming\Microsoft\Windows\Start Menu" -PropertyType ExpandString 
New-ItemProperty -Path "HKU:\*\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -Name "Startup" -Value "%USERPROFILE%\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup" -PropertyType ExpandString 
New-ItemProperty -Path "HKU:\*\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -Name "Templates" -Value "%USERPROFILE%\AppData\Roaming\Microsoft\Windows\Templates" -PropertyType ExpandString 
