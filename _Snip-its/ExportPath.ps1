<#
1) Parameter:

# Path to export results to
[Parameter(Mandatory=$true)]
[String]
$ExportPath

2) Remove trailing "\"
$ExportPath = $($ExportPath.TrimEnd("\")) # trim trailing "\""
#>