# Can only use Var1 and Var, OR Var3 and Var4

param (
    [parameter(ParameterSetName = "SetA")]
    [String]
    $Var1,

    [parameter(ParameterSetName = "SetA")]
    [String]
    $Var2,

    [parameter(ParameterSetName = "SetB")]
    [String]
    $Var3,
    
    [parameter(ParameterSetName = "SetB")]
    [String]
    $Var4
)

if ($PSCmdlet.ParameterSetName -eq "SetA") {
    Write-Host "SetA was used."
    # Put code specific to SetA here
}