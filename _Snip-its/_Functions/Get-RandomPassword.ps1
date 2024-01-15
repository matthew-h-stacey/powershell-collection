function Get-RandomPassword {

    <#
    .SYNOPSIS
    Generate a random password

    .EXAMPLE
    $password = Get-RandomPassword -Length 32
    $password = (ConvertTo-SecureString (Get-RandomPassword -Length $PasswordLength) -AsPlainText -Force)
    #>

    param (
        [Parameter(Mandatory)]
        [int] $Length
    )
    
    $charSet = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()'.ToCharArray()
    $password = -join (Get-Random -InputObject $CharSet -Count 32)
    $password

}