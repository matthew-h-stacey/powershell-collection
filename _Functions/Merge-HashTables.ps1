function Merge-HashTables {
    <#
    .SYNOPSIS
    Merge two hash tables into one.

    .DESCRIPTION
    Creates a new hash table using $First as the base.
    Values from $Second are added or overwrite existing ones.
    Hashtable values are merged by keys.
    Object values are merged by properties.
    #>

    param (
        [Parameter(Mandatory = $true)]
        [hashtable]
        $First,

        [Parameter(Mandatory = $true)]
        [hashtable]
        $Second
    )

    # Result hashtable
    $merged = @{}

    # Copy all entries from First (shallow copy of values)
    foreach ($key in $First.Keys) {
        $merged[$key] = $First[$key]
    }

    # Merge in Second
    foreach ($key in $Second.Keys) {

        # If key doesn't exist, just copy it
        if (-not $merged.ContainsKey($key)) {
            $merged[$key] = $Second[$key]
            continue
        }

        $baseValue = $merged[$key]
        $overlayValue = $Second[$key]

        # Situation 1: Both values are hashtables: merge by keys
        if ($baseValue -is [hashtable] -and $overlayValue -is [hashtable]) {
            foreach ($subKey in $overlayValue.Keys) {
                $baseValue[$subKey] = $overlayValue[$subKey]
            }
        }

        # Situation 2: Both values are objects: merge by properties
        elseif ($baseValue -is [psobject] -and $overlayValue -is [psobject]) {
            foreach ($prop in $overlayValue.PSObject.Properties) {
                if ($baseValue.PSObject.Properties[$prop.Name]) {
                    $baseValue.PSObject.Properties[$prop.Name].Value = $prop.Value
                } else {
                    $baseValue | Add-Member `
                        -MemberType NoteProperty `
                        -Name $prop.Name `
                        -Value $prop.Value
                }
            }
        }

        # Situation 3: Any other type = overwrite
        else {
            $merged[$key] = $overlayValue
        }
    }

    return $merged
}