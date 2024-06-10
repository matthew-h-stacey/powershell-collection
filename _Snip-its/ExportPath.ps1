<#
1) Note block:

.PARAMETER ExportPath
The local directory to export the script output to

###########################

2) Parameter:
[Parameter(Mandatory=$true)]
[String]
$ExportPath

###########################

3) Script body 
$ExportPath = $($ExportPath.TrimEnd("\")) # trim trailing "\"

#>