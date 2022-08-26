Clear-Host

# Two requirements for successfully syncing a user across a federated environment:
# 1) The user's UPN must match their email address
# 2) The user's email address must match the EmailAddress and proxyAddresses (if present) properties of their AD account 

# Import the required Active Directory module
Import-Module Active*

# Establish our variables. Change OU and path as needed
$usersOU = "OU=TestOU,OU=Users,OU=CAMELOTLAB,DC=ad,DC=camelotlab,DC=xyz"
$exportPath = "C:\TempPath"

# Leave these variables as they build off of the exportPath
$logFile = "$($exportPath)\log.txt"
$preEmailAddressUpdate = "$($exportPath)\users.csv"
$postEmailAddressUpdate = "$($exportPath)\users_updated.csv"

# Basic function to write to a log file instead of outputting to a console
Function logWrite{
    Param ([string]$logstring)
    Add-Content $logFile -Value "$(Get-Date -Format "MM/dd/yyyy HH:mm") $logstring"
    }

# Check for export path, create it if it does not exist
if((Test-Path $exportPath) -like $false){
    Write-Host "Created $exportPath"
    New-Item -ItemType Directory -Force -Path $exportPath | Out-Null}

# Get all users in provided OU, retrieve required properties only
Get-ADUser -Filter * -SearchBase $usersOU -Properties * | Select-Object samAccountName,EmailAddress | Export-Csv -Path $preEmailAddressUpdate -NoTypeInformation

# Write-Host "Exported users to $preEmailAddressUpdate"
Write-Host "1. Edit $($preEmailAddressUpdate) and add the EmailAddress values in"
Write-Host "2. Save as $($postEmailAddressUpdate)"
Write-Host "3. Re-run the script"
Write-Host "4. See log.txt for errors/changes"

# Import the CSV to be fed back for EmailAddress/UserPrincipalName changes
try{$updatedUsers = Import-CSV $postEmailAddressUpdate}
catch{logWrite("ERROR: $($postEmailAddressUpdate) could not be found. If this is the first time you ran the script this is okay, proceed to steps #1-4 then re-run the script")}

foreach($user in $updatedUsers){
    
    if($user.EmailAddress){
        try{
            Set-ADUser -Identity $user.samAccountName -EmailAddress $user.EmailAddress
            Set-ADUser -Identity $user.samAccountName -UserPrincipalName $user.EmailAddress
            logWrite( "$($user.samAccountName): set EmailAddress to $($user.EmailAddress)" )
            logWrite( "$($user.samAccountName): set UserPrincipalName to $($user.EmailAddress)" )
            }
        catch{logWrite("There was an error setting the properties for $($user.EmailAddress)")}
        
        }

    else{Write-Host "SKIPPED: $($user.samAccountName) - EmailAddress is null"}

}