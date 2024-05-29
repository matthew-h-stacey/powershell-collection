Select-Object @{Name=Custom;Expression={<Custom Expression Here>}}

Select Object DisplayName,@{
    Name = "MfaStatus"; Expression =
}



$iaasTasks[0].Actions.arguments


$iaasTasks[0] | Select-Object TaskPath, @{Name = "Actions"; Expression = { $_.Actions.Arguments}}