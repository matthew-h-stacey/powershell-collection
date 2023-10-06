function Get-RandomPassword {
    
    param (
        [Parameter(Mandatory)]
        [int] $Length
    )
    
    $CharSet = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()'.ToCharArray()
    $Password = -join (Get-Random -InputObject $CharSet -Count $Length)
    
    return $password

}

<#

Example: 
$Password = (ConvertTo-SecureString (Get-RandomPassword -Length $Length) -AsPlainText -Force)

$params = @{
    Name        = $userName
    Password    = $Password
    Description = $userDescription
}
New-LocalUser @params

#>