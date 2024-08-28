function Convert-HashTableKey {

    <#
    .SYNOPSIS
    Re-key a hash table to use a specific identifier as the new key

    .DESCRIPTION
    This function takes a single hash table and re-keys it using the value of a specified key as the new identifier
    The resulting hash table will have the new key, and the original hash table will be the value.

    .PARAMETER HashTable
    The single hash table to re-key

    .PARAMETER IdentifierKey
    The key in the hash table whose value will be used as the new key.

    .EXAMPLE
    $ht = @{
        UserPrincipalName = 'jsmith@contoso.com'
        DisplayName       = 'John Smith'
        Department        = 'IT'
    }

    $rekeyedHash = Convert-HashTableKey -HashTable $ht -IdentifierKey 'UserPrincipalName'

    # Now you can reference the original hash table using the UserPrincipalName as the key:
    # $rekeyedHash['jsmith@contoso.com']

    # The result:
    # {
    #     UserPrincipalName = 'jsmith@contoso.com'
    #     DisplayName       = 'John Smith'
    #     Department        = 'IT'
    # }
    #>
    
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]
        $HashTable,

        [Parameter(Mandatory = $true)]
        [string]
        $IdentifierKey
    )

    # Initialize the new hash table
    $newHashTable = @{}

    # Check if the identifier key exists and has a value in the input hash table
    if ($HashTable[$IdentifierKey]) {
        $newHashTable[$HashTable[$IdentifierKey]] = $HashTable
    } else {
        Write-Warning "Warning: $IdentifierKey is missing or null in the input hash table"
    }

    # Return the new hash table
    return $newHashTable
}