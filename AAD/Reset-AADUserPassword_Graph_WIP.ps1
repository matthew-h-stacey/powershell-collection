# THIS MAY NOT BE POSSIBLE WITH GRAPH APPLICATION (vs. DELEGATED) PERMISSIONS

[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][String]$UserPrincipalName,
    [Parameter(Mandatory = $False)][switch]$Random
)
function Get-RandomPassword {
    param (
        [Parameter(Mandatory)]
        [int] $length
    )
    #$charSet = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789{]+-[*=@:)}$^%;(_!&amp;#?>/|.'.ToCharArray()
    $charSet = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()'.ToCharArray()
    $rng = New-Object System.Security.Cryptography.RNGCryptoServiceProvider
    $bytes = New-Object byte[]($length)
 
    $rng.GetBytes($bytes)
 
    $result = New-Object char[]($length)
 
    for ($i = 0 ; $i -lt $length ; $i++) {
        $result[$i] = $charSet[$bytes[$i] % $charSet.Length]
    }
 
    return (-join $result)
}

if ($Random.IsPresent) {
    
    $pwLength = 32
    $pw = Get-RandomPassword($pwLength)
    if ($pw.Length -ge $pwLength) {
        # verify random password was generated successfully
        Write-Output "[AAD] Setting a $($pwLength)-character randomly password on user $($UserPrincipalName)"
        Set-AzureADUserPassword -ObjectId $UserPrincipalName -Password (ConvertTo-SecureString "$pw" -AsPlainText -Force)
    }   
    else { Write-Output "[ERROR] Issue occured during random password generation. Please try again" }
    
}
else {

    Write-Output "[AAD] Resetting password for user: $($UserPrincipalName)"
    Write-Output "Enter new password:"
    $pw = Read-Host -AsSecureString
    try {
        Set-AzureADUserPassword -ObjectId $UserPrincipalName -Password $pw
    }
    catch {
        Write-Output "An error occurred. Please try again."    
    }
}