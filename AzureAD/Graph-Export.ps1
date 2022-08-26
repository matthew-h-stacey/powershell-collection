Param
(   
    [Parameter(Mandatory = $true)] [string] $ClientName,
    [Parameter(Mandatory = $true)] [string] $GraphAppID,
    [Parameter(Mandatory = $true)] [string] $GraphAppSecret,
    [Parameter(Mandatory = $true)] [string] $AzureTenantDomain
)

# Error log export
$outputFolder = "C:\Scripts\Output\"
$logFile = $outputFolder + "Graph-Export_$($ClientName)_$((Get-Date -Format "MM-dd-yyyy_HHmm"))_errors.log" # Ex: Graph-Export_ABC-Corp_02-14-2021_0913_errors.log

function New-Folder{
    Param([Parameter(Mandatory = $True)][String] $folderPath)
    if (-not (Test-Path -LiteralPath $folderPath)) {
        try {
        New-Item -Path $folderPath -ItemType Directory -ErrorAction Stop | Out-Null
        }
        catch {
        Write-Error -Message "Unable to create directory '$folderPath'. Error was: $_" -ErrorAction Stop
        }
    }
    else {
    "Folder already exists"
    }
}

Function Write-Log{
    Param ([string]$logstring)
    Add-Content $logFile -Value "$(Get-Date -Format "MM/dd/yyyy HH:mm") $logstring"
    }

function Get-MSGraphDetails {
    
    # Graph request token
    $ReqTokenBody = @{
        Grant_Type    = "client_credentials"
        Scope         = "https://graph.microsoft.com/.default"
        client_Id     = $GraphAppID
        Client_Secret = $GraphAppSecret
    }
    # Initiate MS Graph request 
    $TokenResponse = Invoke-RestMethod -Uri "https://login.microsoftonline.com/$AzureTenantDomain/oauth2/v2.0/token" -Method POST -Body $ReqTokenBody
    $uri = 'https://graph.microsoft.com/beta/users?$select=displayName,userPrincipalName,signInActivity,assignedlicenses'

    # If the result is more than 999, we need to read the @odata.nextLink to show more than one side of users
    $Data = while (-not [string]::IsNullOrEmpty($uri)) {
        # API Call
        $apiCall = try {
            Invoke-RestMethod -Headers @{Authorization = "Bearer $($Tokenresponse.access_token)" } -Uri $uri -Method Get
        }
        catch {
            $errorMessage = $_.ErrorDetails.Message | ConvertFrom-Json
            Write-Log $errorMessage
        }
        $uri = $null
        if ($apiCall) {
            # Check if any data is left
            $uri = $apiCall.'@odata.nextLink'
            $apiCall
        }
    }
    # Output the result of the Graph API call into an variable
    $graphOutput = ($Data | select-object Value).Value
    return $graphOutput
}

New-Folder $outputFolder
Get-MSGraphDetails