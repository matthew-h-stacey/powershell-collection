Param
(   
    [Parameter(Mandatory = $true)] [string] $CaseNumber,
    [Parameter(Mandatory = $true)] [string] $DisplayName,
    [Parameter(Mandatory = $true)] [string] $ManagedBy,
    [Parameter(Mandatory = $true)] [string] $PrimarySmtpAddress,
    [Parameter(Mandatory = $true)] [string] $OU
)

# Create new ADGroup with appropriate properties
New-ADGroup -Description $CaseNumber -DisplayName $DisplayName -GroupCategory Distribution -GroupScope Global -ManagedBy $ManagedBy -Name $DisplayName -OtherAttributes @{'mail' = "$PrimarySmtpAddress" } -Path $OU

# Create and import a txt file with the DisplayName of each user to be added
$members = Get-Content C:\TempPath\DistiUsers.txt

# Add each user from the txt file to the new group
foreach( $m in $members ){ 
    
    $samAccountName = Get-ADUser -Filter {DisplayName -like $m} | Select-Object -ExpandProperty samAccountName
    Add-ADGroupMember -Identity "Christmas Tree Shops" -Members $samAccountName
    
    }