Clear-Host

Get-NetAdapter
Write-Host ""
$adapter = Read-Host "Enter the name of the interface"
$interface = $null

try{
    # Test to see if the input was valid
    Get-NetAdapter -Name $adapter -ErrorAction "Stop" > $null
    }
catch [Microsoft.PowerShell.Cmdletization.Cim.CimJobException]{
    Write-Host "Invalid adapter. Please try again"
    Break
    }    

    # Switch for static or dynamic IP

    $interface = Get-NetAdapter -Name $adapter

    Write-Host "1: Press '1' to set to DHCP."
    Write-Host "2: Press '2' to statically assign IP(s)."
    Write-Host "Q: Press 'Q' to quit without making changes."

    $inputMain = Read-Host "Please make a selection"
    switch($inputMain){
        '1'{ 
            Write-Host "This will set NIC to DHCP"
 
            $interface | Remove-NetIPAddress -AddressFamily IPv4 -Confirm:$false
            $interface | Remove-NetRoute -AddressFamily IPv4 -Confirm:$false
            $interface | Set-NetIPInterface -DHCP Enabled
            $interface | Set-DnsClientServerAddress -ResetServerAddresses
            ipconfig /flushdns > $null
            ipconfig /renew > $null

            }
        '2'{
            Write-Host "This will statically assign IP(s)"

            do{

                Write-Host "1: Press '1' to enter the primary static IP"
                Write-Host "2: Press '2' to enter secondary IPs"
                Write-Host "2: Press '3' to enter static DNS"
                Write-Host "q: Press 'q' to quit"

                $inputStatic = Read-Host "Get input"

                switch($inputStatic){
                '1'{
                    $ipAddress = Read-Host "Enter the IP address (ex: 192.168.1.50)"
                    $cidrLength = Read-Host "Enter the CIDR length (ex: 24 for 255.255.255.0)"
                    $defaultGateway = Read-Host "Enter the default gateway (ex: 192.168.1.254)"
                    
                    $interface | Remove-NetIPAddress -AddressFamily IPv4 -Confirm:$false -ErrorAction SilentlyContinue
                    $interface | Remove-NetRoute -AddressFamily IPv4 -Confirm:$false -ErrorAction SilentlyContinue
                    $interface | New-NetIPAddress -AddressFamily IPv4 -IPAddress $ipAddress -PrefixLength $cidrLength -DefaultGateway $defaultGateway -SkipAsSource:$false > $null
                    }
                '2'{
                    $ipAddress = Read-Host "Enter the IP address (ex: 192.168.1.50)"
                    $cidrLength = Read-Host "Enter the CIDR length (ex: 24 for 255.255.255.0)"
                    $defaultGateway = Read-Host "Enter the default gateway (ex: 192.168.1.254)"
                    $interface | New-NetIPAddress -AddressFamily IPv4 -IPAddress $ipAddress -PrefixLength $cidrLength -DefaultGateway $defaultGateway -SkipAsSource:$true > $null
                    }
                '3'{
                    $dns = Read-Host "Enter the primary and secondary DNS servers separated by comma (8.8.8.8,1.1.1.1)"
                    $interface | Set-DnsClientServerAddress -ServerAddresses $dns

                    # This will be to set static DNS
                    }

                'q'{
                    return
                    }
                }
                }
                until ($inputStatic -eq 'q')
    }
    }


