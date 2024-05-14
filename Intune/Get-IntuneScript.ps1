param (
    # ID of the script. Can be easily retrieved in the UI by opening it and then pulling it from the URL
    [Parameter(Mandatory = $true)]
    [String]
    $ScriptId
)

$uri = "https://graph.microsoft.com/beta/deviceManagement/deviceManagementScripts/$ScriptId"
$script = Invoke-MgGraphRequest -Method GET -Uri $uri
$scriptDecoded = [System.Text.Encoding]::ASCII.GetString([System.Convert]::FromBase64String($($script.scriptContent))) 

return $scriptDecoded