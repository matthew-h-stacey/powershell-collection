$string = @"
line1
line2
line3
"@

$array = $string -split '\r?\n' # Split on newlines (\r\n for Windows, \n for Unix)

$array