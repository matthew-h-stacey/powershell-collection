# Ex: Set a department on an AD User by splatting a $parameter variable
$parameter = @{
    Department  =   $ADUser.Department
}
Set-ADUser $ADUser.DistinguishedName @parameter

# Ex2 (advanced): Splat a variable that uses a variable
if ($adUser) {
    $userProps = $csv | Get-Member | Where-Object { $_.MemberType -eq "NoteProperty" } | Select-Object -ExpandProperty Name
        foreach ( $attribute in $userProps) {
            if ( $adUser.$attribute -ne $entry.$attribute) {
                    
                    # Update the property
                    $parameter = @{
                        $attribute = $entry.$attribute
                    }
                    Set-ADUser $adUser.DistinguishedName @parameter
                    Write-Host "Updated $($adUser.DisplayName) $attribute to: $($entry.$attribute)"

                }
            }
        }
        