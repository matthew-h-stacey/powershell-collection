param(
    [Parameter(Mandatory = $true)] [string] $UPN,
    [Parameter(Mandatory = $true)] [string] $Domain


# PRE-WORK:
# Ensure user is Soft Deleted from Azure AD for DirSynced users
#   (Move the user to a non-AAD synced OU. Once that occurs it will SoftDelete the user)


# Connect to MsolService and record the necessary TenantID in a variable
Write-Host "Connecting to Msolservice (Delegated)"
$TenantID = .\Connect-DelegatedMsolService.ps1 -Domain $domain

### 1) Restore the deleted user
# Retrieve ID of deleted user
$objectID = Get-MsolUser -TenantId $TenantID -ReturnDeletedUsers -SearchString $UPN  -ErrorAction Stop | Select-Object -ExpandProperty objectID
# Restore the deleted user, which restores them as a cloud-only user
Restore-MsolUser -TenantId $TenantID  -ObjectId $objectID -AutoReconcileProxyConflicts
Write-Host "Waiting 1 minute for MsolUser to be restored"
Start-Sleep -Seconds 60

### 2) Clear immutableID property
try {
    $msolUser = Get-MsolUser -UserPrincipalName $UPN -TenantId $TenantID -ErrorAction Stop
}
catch {
    "ERROR: MsolUser with provided UPN was not found. Please try again"
}
if ($null -ne $msolUser.ImmutableID) { Set-MsolUser -UserPrincipalName $msolUser.UserPrincipalName -TenantId $TenantID -ImmutableId "$null" }

### 3) Convert mailbox into a SharedMailbox
# Connect EXO
Write-Host "Connecting to Exchange Online (delegated), enter your credentials"
.\Connect-DelegatedExchangeOnline.ps1 -Domain $domain
Write-Host "Waiting 2 minutes for mailbox to be re-added to account"
Start-Sleep -Seconds 120
Set-Mailbox -Identity $UPN -Type Shared

### 4) Remove all licenses from user by UPN (https://docs.microsoft.com/en-us/microsoft-365/enterprise/remove-licenses-from-user-accounts-with-microsoft-365-powershell?view=o365-worldwide)
connect-azuread -TenantId $TenantID
$Skus = Get-AzureADUser -ObjectId $msolUser.UserPrincipalName | Select-Object -ExpandProperty AssignedLicenses | Select-Object SkuID
if ($Skus.count -ne 0) {
    if ($Skus -is [array]) {
        $licenses = New-Object -TypeName Microsoft.Open.AzureAD.Model.AssignedLicenses
        for ($i = 0; $i -lt $Skus.Count; $i++) {
            $Licenses.RemoveLicenses += (Get-AzureADSubscribedSku | Where-Object -Property SkuID -Value $Skus[$i].SkuId -EQ).SkuID   
        }
        Set-AzureADUserLicense -ObjectId $UPN -AssignedLicenses $licenses
    }
    else {
        $licenses = New-Object -TypeName Microsoft.Open.AzureAD.Model.AssignedLicenses
        $Licenses.RemoveLicenses = (Get-AzureADSubscribedSku | Where-Object -Property SkuID -Value $Skus.SkuId -EQ).SkuID
        Set-AzureADUserLicense -ObjectId $UPN -AssignedLicenses $licenses
    }
}

### 5) Hide mailbox from GAL
# NOTE: Do not hide if you will need to add manually to Outlook (vs. using AutoDiscover)
Set-mailbox -Identity $UPN -HiddenFromAddressListsEnabled:$true

### 6) Ensure account is enabled
Set-AzureADUser -ObjectId $UPN -AccountEnabled $true

### 7) OPTIONAL: Ensure OWA is enabled
Set-CASMailbox -Identity $UPN -OWAEnabled $true


