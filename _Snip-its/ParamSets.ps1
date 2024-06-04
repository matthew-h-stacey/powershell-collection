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

#####################
# Example: switch statement
#####################

switch ($PSCmdlet.ParameterSetName) {
    'ParameterSetA' {
        # Code for parameter set A
        Write-Output "Parameter set A used"
    }
    'ParameterSetB' {
        # Code for parameter set B
        Write-Output "Parameter set B used"
    }
    'ParameterSetC' {
        # Code for parameter set C
        Write-Output "Parameter set C used"
    }
    Default {
        # Default code if none of the parameter sets match
        Write-Output "Unknown parameter set used"
    }
}
