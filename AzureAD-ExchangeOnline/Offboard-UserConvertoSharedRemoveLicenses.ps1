# Csv must use property UserPrincipalName
$terminatedUsers = import-csv C:\TempPath\Terminated_Users.csv

# Step 1 - Convert the users to Shared mailboxes

Connect-ExchangeOnline

foreach($u in $terminatedUsers){
    $UPN = $u.UserPrincipalName
    Set-mailbox -Identity $UPN -Type Shared
}

# Step 2 - Remove all licenses from the users

Connect-MsolService

foreach ($user in $terminatedUsers) {
    Write-Verbose "Processing licenses for user $($user.UserPrincipalName)"
    try { $user = Get-MsolUser -UserPrincipalName $user.UserPrincipalName -ErrorAction Stop }
    catch { continue }

    $SKUs = @($user.Licenses)
    if (!$SKUs) { Write-Verbose "No Licenses found for user $($user.UserPrincipalName), skipping..." ; continue }

    foreach ($SKU in $SKUs) {
        if (($SKU.GroupsAssigningLicense.Guid -ieq $user.ObjectId.Guid) -or (!$SKU.GroupsAssigningLicense.Guid)) {
            Write-Verbose "Removing license $($Sku.AccountSkuId) from user $($user.UserPrincipalName)"
            Set-MsolUserLicense -UserPrincipalName $user.UserPrincipalName -RemoveLicenses $SKU.AccountSkuId
        }
        else {
            Write-Verbose "License $($Sku.AccountSkuId) is assigned via Group, use the Azure AD blade to remove it!"
            continue
        }
    }
}

# Step 3 - remove ImmutableID from user
foreach ($user in $terminatedUsers){
    try { $user = Get-MsolUser -UserPrincipalName $user.UserPrincipalName -ErrorAction Stop }
    catch { continue }
    Set-MsolUser -UserPrincipalName $user.UserPrincipalName -ImmutableId "$null"
}