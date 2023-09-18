function Get-IPLogins {
    param(
       
        [Parameter(Mandatory = $true)]
        [CustomerContext[]]
        $SelectCustomers,

        [SkyKickParameter(
            DisplayName = "IP Address",    
            HintText = "Enter an IPv4 address to search for login attempts to client tenants."
        )]
        [ValidatePattern(
            "^((?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$",
            ErrorMessage = "Input provided was not a valid IPv4 address. Please try again"
        )]
        [Parameter (Mandatory = $true)]
        [String[]]$ipAddress,

        [SkyKickParameter(
            HintText = "Only show clients who have sign-ins from the provided IP(s). Disable this to show the full list of clients and whether or not there was a sign-in from the provided IP(s)."
        )]
        [Parameter (Mandatory = $false )]
        [Boolean]$MatchedClientsOnly = $true
    )

    # Cloud Manager block for iterating through an array of clients
    $SelectCustomers | ForEach-Object -process {
        Set-CustomerContext $_

        # Variables for the current client in the array
        $Customer = Get-CustomerContext
        $CustomerName = $Customer.CustomerName

        # Filter for Get-AzureADAuditSigninLogs
        $ipFilter = "IpAddress eq '" + ($ipAddress -join "',IpAddress eq '") + "'"
        
        # Object that retrieves a single sign-in (if found) for the provided IP
        $signIns = Get-AzureADAuditSignInLogs -Filter $ipFilter | Group-Object -Property UserPrincipalName | Select-Object -ExpandProperty Group | Select-Object -First 1

        if ($signIns) { # If a sign-in was found, the following block will output the login attempt with the username used and date accessed
            $username = $signIns.UserPrincipalName
            $lastdate = $signIns.CreatedDateTime
            Write-Host "Sign-ins found at $CustomerName from IP address $($ipAddress -join ',') by $username on $lastdate"
    
        }
        else { # If no sign-in was found, only output 'No sign-in found ..' based on the value of the $MatchedClientsOnly boolean
            if ( $MatchedClientsOnly -eq $false ){
                Write-Host "No sign-ins found at $CustomerName from IP address $($ipAddress -join ',')"
            }
        }
    }
}