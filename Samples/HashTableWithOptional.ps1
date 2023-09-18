$userHashTable = @{
        DisplayName                 =   $User.DisplayName
        UPN                         =   $UPN
        Mail                        =   $User.Mail
        UserType                    =   $User.UserType
        AccountEnabled              =   $User.AccountEnabled
    }
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
    foreach ($property in $optionalProperties) {
        if ($property.Include) {
            $userHashTable.Add($property.Name, $property.Value)
        }
    }
    $results += $userHashTable