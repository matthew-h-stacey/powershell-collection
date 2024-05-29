# EXAMPLE: 
# Add properties individually to a new custom PSObject, only if the input has value. The input checking is not present here but the format can be used

$myObject = ""
$groupProperties = New-Object -TypeName PSObject
if ( $null -ne $myObject.Name) { Add-Member -InputObject $groupProperties -MemberType NoteProperty -Name Name -Value $myObject.Name }
if ( $null -ne $myObject.Alias) { Add-Member -InputObject $groupProperties -MemberType NoteProperty -Name Alias -Value $myObject.Alias }