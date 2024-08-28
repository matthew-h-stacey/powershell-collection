function ConvertTo-HashTable {
        <#
        .SYNOPSIS
        Quick function to convert a list to hash table

        .PARAMETER Input
        The array or list to convert to a hash table

        .PARAMETER KeyName
        The identifier used to select entries from the hash table (ex: UserPrincipalName, Id, etc.)

        .EXAMPLE
        ConvertTo-HashTable -List $listObjects -KeyName UserPrincipalName
        #>
        param (
            [Parameter(Mandatory = $true)]
            [System.Object]
            $List,

            [Parameter(Mandatory = $true)]
            [string]
            $KeyName
        )
    
        $hashTable = @{}
        if ( $List ) {
            foreach ($item in $List) {
                if ( $item ) {
                    if ( $item.$KeyName ) {
                        $hashTable[$item.$KeyName] = $item
                    } else {
                        Write-Output "$KeyName does not exist on $item"
                    }
                }
            }
            return $hashTable
        } else {
            Write-Output "No input provided"
        }
        
    }