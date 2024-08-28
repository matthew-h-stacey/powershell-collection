function Merge-HashTables {
        # Function to merge two hash tables into one
        param (
            [Parameter(Mandatory = $true)]
            [hashtable]
            $First, 

            [Parameter(Mandatory = $true)]
            [hashtable]
            $Second
        )

        # Store the merged results in this hash table
        $mergedHashTable = @{}

        # Copy the first hash table to the result
        foreach ($key in $First.Keys) {
            $mergedHashTable[$key] = $First[$key].PSObject.Copy()
        }

        # Merge the second hash table into the result
        foreach ($key in $Second.Keys) {
            if ($mergedHashTable.ContainsKey($key)) {
                foreach ($property in $Second[$key].PSObject.Properties) {
                    if (-not $mergedHashTable[$key].PSObject.Properties[$property.Name]) {
                        $mergedHashTable[$key] | Add-Member -MemberType NoteProperty -Name $property.Name -Value $property.Value -Force
                    } else {
                        $mergedHashTable[$key].PSObject.Properties[$property.Name].Value = $property.Value
                    }
                }
            } else {
                $mergedHashTable[$key] = $Second[$key].PSObject.Copy()
            }
        }
        return $mergedHashTable
    }