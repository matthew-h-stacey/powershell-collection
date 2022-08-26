# Create the initial hash table with default values for FilterHashtable
$filterOptions = @{
    LogName = "Security"
    ID      = "$LockOutID"
}

# Adds the values of optional parameters above, if applicable
if($StartTime){
    $filterOptions.StartTime = Get-Date -Date $StartTime
}
if($EndTime){
    $filterOptions.EndTime = Get-Date -Date $EndTime
}