Param
(
    [Parameter(Mandatory = $true)] [string] $group
)

# Ref: https://techcommunity.microsoft.com/t5/exchange-team-blog/basic-authentication-and-exchange-online-september-2021-update/ba-p/2772210

<#
############### DO THIS FIRST ###############
1. Ensure Modern Auth is enabled
Get-OrganizationConfig | select Name,OAuth2ClientProfileEnabled

2. Create new AuthenticationPolicy
New-AuthenticationPolicy -Name "Block Basic Auth"

"By default, when you create a new authentication policy without specifying any protocols, Basic authentication is blocked for all client protocols in Exchange Online"
Ref: https://docs.microsoft.com/en-us/exchange/clients-and-mobile-in-exchange-online/disable-basic-authentication-in-exchange-online
Optional: To see this, after creating the policy run "Get-AuthenticationPolicy -Identity "Block Basic Auth" | select *basic*"

#>

# Get users
# Use CSV with column names: "DisplayName," "Mail," and "Group" (at least)
$users = Import-Csv C:\TempPath\Basic_Auth_Users.csv | Sort-Object DisplayName

# Connect to EXO
Connect-ExchangeOnline

foreach($u in $users){
    if($u.group -like $group){
        Write-Host "Applying new AuthenticationPolicy to:"$u.DisplayName
        Set-User -Identity $u.Mail -AuthenticationPolicy "Block Basic Auth"
    }
}

Disconnect-ExchangeOnline -Confirm:$false

# Optional: verify AuthenticationPolicy is applied
# Get-User -Identity {ID} | select AuthenticationPolicy