Param
(   
    [Parameter(Mandatory = $true)] [string] $Name,
    [Parameter(Mandatory = $true)] [string] $ManagedBy,
    [Parameter(Mandatory = $true)] [string] $CaseNumber,
    [Parameter(Mandatory = $true)] [string] $PrimarySmtpAddress
)

# Get list of users to add by email from text file
$Users = Get-Content C:\TempPath\DistiUsers.txt

Connect-ExchangeOnline -ShowBanner:$false

New-DistributionGroup -Name $Name -ManagedBy $ManagedBy -Notes $CaseNumber -PrimarySmtpAddress $PrimarySmtpAddress

foreach($u in $Users){
    Add-DistributionGroupMember -Identity $Name -Member $u
}