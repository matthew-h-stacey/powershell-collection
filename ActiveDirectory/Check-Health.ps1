Import-Module *active*

# Export path
$ExportDir = "C:\ADHealthCheck"

# Check for directory, create if it does not exist
Write-Host "Checking for $ExportDir, creating directory if it does not exist"
if((Test-Path $ExportDir) -like $false){
    Write-Host "Created $ExportDir"
    New-Item -ItemType Directory -Force -Path $ExportDir | Out-Null}
else{Write-Host "$ExportDir exists, continuing ..."}

# Get FSMO Masters
netdom query fsmo | Out-File $ExportDir\FSMO.txt

# Check AD diagnostics
dcdiag /v /c /f:$ExportDir\dcdiag.txt

# Check replication
repadmin /replsummary | Out-File $ExportDir\repadmin_summary.txt
repadmin /showrepl | Out-File $ExportDir\repadmin_Log.txt

# Get DHCP servers
netsh dhcp show server | Out-File $ExportDir\dhcpservers.txt

# Get Services
get-service -Name dns,netlogon,ntds | Sort-Object DisplayName | Select-Object DisplayName,Name,Status | Out-File $ExportDir\services.txt

# Get disabled accounts
$builtinUsers = @("Guest","DefaultAccount","krbtgt")
$disabledOU = Get-ADOrganizationalUnit -Filter * -SearchBase (Get-ADDomain).DistinguishedName -SearchScope OneLevel | Where-Object{ $_.Name -like "*Disabled*" }
$disabledUsers = Get-ADUser -Filter * | Where-Object{ $_.Enabled -eq $false -and $_.SamAccountName -notIn $builtinUsers -and $_.DistinguishedName -notLike "*$disabledOU"}

Write-Host "Attempting to move disabled users to proper OU ..."
if(!$disabledUsers)
    { Write-Host "SKIPPING: No disabled users found outside proper OU" }
foreach($user in $disabledUsers){
    if(!(Move-ADObject $user -TargetPath $disabledOU))
    { $Status = "SUCCESS" }
    else
    { $Status = "FAILED" }
    $disabledUsersOutput = New-Object -TypeName PSobject
    $disabledUsersOutput | Add-Member -MemberType NoteProperty -Name Source -Value ($user | Select-Object -expandproperty distinguishedName)
    $disabledUsersOutput | Add-Member -MemberType NoteProperty -Name Destination -Value $disabledOU
    $disabledUsersOutput | Add-Member -MemberType NoteProperty -Name Status -Value $Status
    $disabledUsersOutput
    }

    Write-Host "Active Directory health reports exported to $ExportDir"

# Find all disabled users
Get-ADUser -Filter * -Properties * | Where-Object {$_.DistinguishedName -like "*Disabled*" -and $_.SamAccountName -notIn $builtinUsers} | Select-Object samAccountName,DisplayName,Created,PasswordLastSet | Export-Csv $ExportDir\DisabledUsers.csv -NoTypeInformation
Write-Host "Exported list of Disabled users to $ExportDir"

# Find all "active" users -not
Get-ADUser -Filter * -Properties * | Where-Object {$_.DistinguishedName -notlike "*Disabled*" -and $_.SamAccountName -notIn $builtinUsers} | Select-Object samAccountName,DisplayName,Created,PasswordLastSet | Export-Csv $ExportDir\ActiveUsers.csv -NoTypeInformation
Write-Host "Exported list of Enabled users to $ExportDir"


