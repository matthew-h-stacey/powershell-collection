#Set NTDS RPC port to static setting
New-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\NTDS\Parameters" -Name "TCP/IP Port" -Value 55000 -PropertyType "DWord"

#Set Netlogon RPC port to static setting
New-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon\Parameters" -Name "DCTcpipPort Port" -Value 55001 -PropertyType "DWord"

#Set NtFrs RPC port to static setting
New-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\NtFrs\Parameters" -Name "RPC TCP/IP Port Assignment" -Value 55002 -PropertyType "DWord"

#Set RPC dynamic ports to static range setting
New-Item "HKLM:\Software\Microsoft\RPC\Internet"
New-ItemProperty "HKLM:\Software\Microsoft\RPC\Internet" -Name "Ports" -Value '55003-55303' -PropertyType MultiString -Force
New-ItemProperty "HKLM:\SOFTWARE\Microsoft\Rpc\Internet" -Name "PortsInternetAvailable" -Value Y -PropertyType "String"
New-ItemProperty "HKLM:\SOFTWARE\Microsoft\Rpc\Internet" -Name "UseInternetPorts" -Value Y -PropertyType "String"