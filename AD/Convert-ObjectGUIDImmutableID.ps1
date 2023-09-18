<#
.SYNOPSIS
	Convert ObjectGUID to ImmutableID and vice versa

.DESCRIPTION
	Convert ObjectGUID string to Base64 ImmutableID, or Base64 ImmutalbeID to ObjectGUID using .NET. This can be helpful when hard-linking Azure AD synced users, or if you need to do a lookup using either property.

.PARAMETER ObjectGUID
	Use this switch to convert from ObjectGUID to ImmutableID.

.PARAMETER ImmutableID
	Use this switch to convert from ImmutableID to ObjectGUID.

.EXAMPLE
	Convert-ObjectGUIDImmutableID.ps1 -ObjectGUID f7cc07d7-7c15-447d-876d-c01b0e5a9e38
    -> "ImmutableID: 1wfM9xV8fUSHbcAbDlqeOA=="

.NOTES
	Author: Matt Stacey
	Date:   March 28, 2023
	Tags: 	
#>

[CmdletBinding()]
param (
    [parameter(ParameterSetName = "ObjectGUID")][String]$ObjectGUID,
    [parameter(ParameterSetName = "ImmutableID")][String]$ImmutableID
)

if($ObjectGUID){
    try {
        return "ImmutableID: " + [system.convert]::ToBase64String(([GUID]$ObjectGUID).ToByteArray())
    }
    catch {
        Write-Warning "Incorrect value provided for ObjectGUID, please try again"
    }
}

if ($ImmutableID) {
    try {
        return "ObjectGUID: " + ([Guid]([Convert]::FromBase64String("$ImmutableID")) | Select-Object -ExpandProperty GUID)
    }
    catch {
        Write-Warning "Incorrect value provided for ImmutableID, try again"
    }
}