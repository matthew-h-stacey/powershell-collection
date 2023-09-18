<#
.SYNOPSIS
	Get the date of the last password change for a specific user, or all users in a tenant.

.DESCRIPTION
	This script uses MgGraph to return LastPasswordChangeDateTime for all users, or a particular user. 

.PARAMETER All
	Check the last password change date for all users by using this switch.

.PARAMETER UserPrincipalName
	Check the last password change date for a single user by providing their UserPrincipalName.

.EXAMPLE
	Get-AADUserPWChangeDateTime.ps1 -All
    Get-AADUserPWChangeDateTime.ps1 -UserPrincipalName jsmith@contoso.com

.NOTES
	Author: Matt Stacey
	Date:   March 28, 2023
	Tags: 	#CloudManager
#>

param(

    [Parameter(ParameterSetName="All")]
    [Switch]
    $All,

    [Parameter(ParameterSetName="Single")]
    [String]
    $UserPrincipalName

)

if ( $All ) {
    $Users = (Invoke-MgGraphRequest -Method GET 'https://graph.microsoft.com/beta/users?$select=DisplayName,UserPrincipalName,LastPasswordChangeDateTime').Value
    $Users | Select-Object DisplayName,UserPrincipalName,LastPasswordChangeDateTime
}

if ( $UserPrincipalName ) {
    $URL = "https://graph.microsoft.com/beta/users/$UserPrincipalName" + '?$select=DisplayName,UserPrincipalName,LastPasswordChangeDateTime'
    $User = Invoke-MgGraphRequest -Method GET $URL
    $User | Select-Object DisplayName,UserPrincipalName,LastPasswordChangeDateTime

}
