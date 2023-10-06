function New-LocalAdmin {

    param (
        # Username for the new local admin
        [Parameter(Mandatory = $true)]
        [String]
        $UserName,

        # Description for the new local admin
        [Parameter(Mandatory = $false)]
        [String]
        $UserDescription,

        # Length of the initial password the user should be created with
        [Parameter(Mandatory = $true)]
        [Int]
        $PasswordLength
    )

    function Get-RandomPassword {
    
        param (
            [Parameter(Mandatory)]
            [int] $Length
        )
        
        $CharSet = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()'.ToCharArray()
        $Password = -join (Get-Random -InputObject $CharSet -Count $Length)
        
        return $Password
    
    }

    $Password = (ConvertTo-SecureString (Get-RandomPassword -Length $PasswordLength) -AsPlainText -Force)

    $params = @{
        Name        = $userName
        Password    = $Password
        Description = $userDescription
    }

    try { 
        New-LocalUser @params
        Add-LocalGroupMember -Group Administrators -Member $userName
        Exit 0
    }   
    Catch {
        Write-error $_
        Exit 1
    } 

}

New-LocalAdmin -UserName "cloud_laps" -UserDescription "User account for Cloud LAPS" -PasswordLength 32