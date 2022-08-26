cls
Get-NetAdapter
$adapter = Read-Host "Enter the name of the interface"
$interface = Get-NetAdapter -Name $adapter
$interface | Remove-NetIPAddress -AddressFamily IPv4 -Confirm:$false -ErrorAction SilentlyContinue
$interface | Remove-NetRoute -AddressFamily IPv4 -Confirm:$false -ErrorAction SilentlyContinue
$interface | New-NetIPAddress -AddressFamily IPv4 -IPAddress 192.168.55.40 -PrefixLength 24 -DefaultGateway 192.168.55.254 -SkipAsSource:$false > $null
$interface | New-NetIPAddress -AddressFamily IPv4 -IPAddress 192.168.1.40 -PrefixLength 24 -DefaultGateway 192.168.1.254 -SkipAsSource:$true > $null
$interface | New-NetIPAddress -AddressFamily IPv4 -IPAddress 192.168.10.40 -PrefixLength 24 -DefaultGateway 192.168.10.254 -SkipAsSource:$true > $null
$interface | New-NetIPAddress -AddressFamily IPv4 -IPAddress 192.168.50.40 -PrefixLength 24 -DefaultGateway 192.168.50.254 -SkipAsSource:$true > $null
$interface | New-NetIPAddress -AddressFamily IPv4 -IPAddress 192.168.75.40 -PrefixLength 24 -DefaultGateway 192.168.75.254 -SkipAsSource:$true > $null
$interface | New-NetIPAddress -AddressFamily IPv4 -IPAddress 192.168.100.40 -PrefixLength 24 -DefaultGateway 192.168.100.254 -SkipAsSource:$true > $null
$interface | New-NetIPAddress -AddressFamily IPv4 -IPAddress 192.168.200.40 -PrefixLength 24 -DefaultGateway 192.168.200.254 -SkipAsSource:$true > $null
$interface | New-NetIPAddress -AddressFamily IPv4 -IPAddress 192.168.220.40 -PrefixLength 24 -DefaultGateway 192.168.220.254 -SkipAsSource:$true > $null
$interface | New-NetIPAddress -AddressFamily IPv4 -IPAddress 10.10.30.40 -PrefixLength 24 -DefaultGateway 10.10.30.254 -SkipAsSource:$true > $null
$interface | New-NetIPAddress -AddressFamily IPv4 -IPAddress 10.10.40.40 -PrefixLength 24 -DefaultGateway 10.10.40.254 -SkipAsSource:$true > $null
$interface | New-NetIPAddress -AddressFamily IPv4 -IPAddress 10.10.50.40 -PrefixLength 24 -DefaultGateway 10.10.50.254 -SkipAsSource:$true > $null
$interface | New-NetIPAddress -AddressFamily IPv4 -IPAddress 10.10.60.40 -PrefixLength 24 -DefaultGateway 10.10.60.254 -SkipAsSource:$true > $null
$interface | New-NetIPAddress -AddressFamily IPv4 -IPAddress 10.0.1.40 -PrefixLength 24 -DefaultGateway 10.0.1.1 -SkipAsSource:$true > $null
$interface | Set-DnsClientServerAddress -ServerAddresses 1.1.1.1,8.8.8.8