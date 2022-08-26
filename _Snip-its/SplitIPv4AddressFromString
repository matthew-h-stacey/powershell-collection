# Standalone
$IPv4Regex = '((?:(?:0?0?\d|0?[1-9]\d|1\d\d|2[0-5][0-5]|2[0-4]\d)\.){3}(?:0?0?\d|0?[1-9]\d|1\d\d|2[0-5][0-5]|2[0-4]\d))'
[regex]::Matches($String, $IPv4Regex)

# Example
$testPort = "192.168.119.97_1,192.168.119.97_2" # this is the 'input,' an array of PrinterPorts that has multiple IPs
$testArray = $testPort.Split('_*,') # RegEx to split by (underscore,anything,comma). Results in 192.168.119.97,1,192.168.119.97,2
$IPv4Regex = '((?:(?:0?0?\d|0?[1-9]\d|1\d\d|2[0-5][0-5]|2[0-4]\d)\.){3}(?:0?0?\d|0?[1-9]\d|1\d\d|2[0-5][0-5]|2[0-4]\d))' # RegEx to match an IPv4 address
$filteredIPs = [regex]::Matches($testArray, $IPv4Regex).Value | Get-Unique # Match the IPs from the array (drop the 1 and 2), then grab the unique values only. In this example, there was a duplicate port so it will only report 192.168.119.97 once
