########################
# Example 1 - Basic
########################

# Create the initial hash table with default values
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

########################
# Example 2 - More advanced
########################

# Create the initial hash table with default values
$userHashTable = @{
    DisplayName                 =   $User.DisplayName
    UPN                         =   $UPN
    Mail                        =   $User.Mail
    UserType                    =   $User.UserType
    AccountEnabled              =   $User.AccountEnabled
}
# Create an array with hash table entries for optional values
$optionalProperties = @(
    @{
        Name = 'LastLogin'  
        Include = $IncludeLastLogin
        Value = $LastLogin
    },
    @{
        Name = 'Licenses'
        Include = $IncludeLicenses      	
        Value = $Licenses -join "; "
    },
    @{
        Name = 'Department'
        Include = $IncludeDepartment      	
        Value = $User.Department
    }
)
# Loop through the hash table. if $Include, add the property to the main hash table
foreach ($property in $optionalProperties) {
    if ($property.Include) {
        $userHashTable.Add($property.Name, $property.Value)
    }
}
$results += $userHashTable