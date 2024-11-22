function Merge-HashTables {
    <#
    .SYNOPSIS
    Merge two hash tables into one. Creates a new hash table, copies First, then iterates through Second to add/replace values

    .PARAMETER First
    First hashtable input. Becomes the base hashtable in the merge

    .PARAMETER Second
    Second hashtable input. Add or overwrite properties to the base hashtable from this hashtable
    #> 
    
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]
        $First,

        [Parameter(Mandatory = $true)]
        [hashtable]
        $Second  
    )

    # Initialize an empty hashtable to store the merged result
    $mergedHashTable = @{}

    # Loop through each key in $First and add it to $mergedHashTable using PSObject.Copy() for deep copy
    foreach ($key in $First.Keys) {
        $mergedHashTable[$key] = $First[$key].PSObject.Copy()
    }

    # Loop through each key in $Second to merge it into $mergedHashTable
    foreach ($key in $Second.Keys) {

        # Check if the key from $Second exists in the base hashtable
        if ($mergedHashTable.ContainsKey($key)) {
        
            # Loop through each property in the object associated with the key in $Second.
            foreach ($property in $Second[$key].PSObject.Properties) {
            
                # If any property from $Second does not exist in the matched base hashtable object, add it as a new property
                if (-not $mergedHashTable[$key].PSObject.Properties[$property.Name]) {
                    $mergedHashTable[$key] | Add-Member -MemberType NoteProperty -Name $property.Name -Value $property.Value -Force
                } else {
                    # If the property does exist in $mergedHashTable, overwrite the existing property value.
                    $mergedHashTable[$key].PSObject.Properties[$property.Name].Value = $property.Value
                }
            }
        } else {
            # If the key from $Second does not exist in $mergedHashTable, add it as a new entry.
            # Use PSObject.Copy() to ensure the object is deeply copied.
            $mergedHashTable[$key] = $Second[$key].PSObject.Copy()
        }
    }
    return $mergedHashTable
    
}