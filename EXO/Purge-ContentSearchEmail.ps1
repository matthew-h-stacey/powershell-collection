Param
(   
    [Parameter(Mandatory = $true)] [string] $SearchName
)

function Get-ComplianceSearchStatus {
    Get-ComplianceSearch $SearchName | Select-Object -ExpandProperty Status
}

function Request-ComplianceSearchStatus {
    $result = ""
    Write-Host "Checking to see if ComplianceSearch is done ..."
    do {
        $result = Get-ComplianceSearchStatus
        if ($result = "Completed") {
            Write-Host "Not done yet, waiting 30 seconds"
            Start-Sleep -Seconds 30
        }

    } while ($result -notlike "Completed")
    if ($result -eq "Completed") {
        Write-Host "ComplianceSearch is Completed"
    }
}

# Pre-requisite: EXO PS module must be installed
if ($null -eq (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
        Write-Host "[MODULE] Required module ExchangeOnlineManagement is not installed"
        Write-Host "[MODULE] Installing ExchangeOnlineManagement" -ForegroundColor Cyan
        Install-Module ExchangeOnlineManagement -Repository PSGallery -AllowClobber -Force -Scope CurrentUser
    } 
    else { 
        Write-Host "[MODULE] ExchangeOnlineManagement is installed, continuing ..." 
    }

# Connect to Protection and Compliance center
Write-Host "[MODULE] Connecting to M365 Compliance console. Ensure you are authenticating with an account that has proper eDiscovery roles"
Connect-IPPSSession -ConnectionUri https://ps.compliance.protection.outlook.com/powershell-liveid/

Write-Host "Waiting 30s to let ComplianceSearch run ..."
Start-Sleep -Seconds 30

Request-ComplianceSearchStatus

Write-Host "[EXO] Executing deletion of emails found in search name: $($SearchName). Waiting 1 minute"
New-ComplianceSearchAction -SearchName $SearchName -Purge -PurgeType SoftDelete -Confirm:$false | Out-Null
Start-Sleep -Seconds 60
Get-ComplianceSearchAction -Purge | ?{$_.SearchName -eq $SearchName}

# Disconnect
get-pssession | remove-pssession