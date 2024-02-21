function Test-Input {
    param(
        [Parameter()]
        [ValidatePattern('^\d{5}$', IgnoreCase = $false, Multiline = $false, SingleLine = $true, Description = 'Five-digit ZIP code')]
        [string]$ZipCode
    )

    process {
        try {
            # Attempt to use the input
        }
        catch {
            # Handle the validation error with a more user-friendly message
            Write-Host "Error: Please enter a valid five-digit ZIP code."
        }
    }
}

# Example usage with invalid input
Test-Input -ZipCode "1234A"

#########################################

function Validate-YesOrNo {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet("yes", "no")]
        [string]$Choice
    )

    # Rest of your script/function logic goes here
    Write-Host "You chose: $Choice"
}

# Example usage:
Validate-YesOrNo -Choice "yes"
Validate-YesOrNo -Choice "no"
