# Used to convert either an AD user's objectGUID to AAD user immutableID, or vice versa
# Provide one user property (parameter) and receive the other

[CmdletBinding()]
param (
    [parameter(ParameterSetName = "setA")][String]$objectGUID,
    [parameter(ParameterSetName = "setB")][String]$immutableID
)

if($objectGUID){
    try {
        return "ImmutableID: " + [system.convert]::ToBase64String(([GUID]$objectGUID).ToByteArray())
        # return [system.convert]::ToBase64String(([GUID]$objectGUID).ToByteArray())
    }
    catch {
        Write-Warning "Incorrect value for objectGUID provided, try again"
    }
}

if ($immutableID) {
    try {
        return "ObjectGUID: " + ([Guid]([Convert]::FromBase64String("$immutableID")) | Select-Object -ExpandProperty GUID)
    }
    catch {
        Write-Warning "Incorrect value for immutableID provided, try again"
    }
}