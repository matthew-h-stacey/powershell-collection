Clear-Host

<#
The purpose of this script is to perform an initial cleanup/configuration of an Active Directory environment. It accomplishes the following things:

* Creates a new OU with the name of the AD Domain, along with sub-OUs for computers, users, and security groups
* Creates a new OU "Disabled," along with sub-OUs for computers and users
* Redirects computers to the newly created computers OU
* Redirects users to the newly created users OU
* Moves users and security groups from the Users container to the newly created users OU
* Moves computers (all non-domain controllers) into the newly created computers OU

The prime directive is to clean up fresh installs that do not yet have GPOs in place, though it could be used with care on existing domains

TO DO:
* Find why redircmp/redirusr cannot properly finish on the first time the script is run (NOTE: Find why $newDefault(User/Computers)Container is blank to begin with), but runs fine on second attempt
* General script cleanup/readability improvements
* Find out how to turn the CreateOU function into a function that accepts arrays, to call the function one time only?
* Move disabled computers and accounts into the new Disabled OUs
* Provide cleaner output

#>

Import-Module ActiveDirectory

###
### Establish variables
###

$getCurrentDomainRoot = Get-ADDomain | ForEach-Object { $_.DistinguishedName }
$getDomain = $env:userdomain
$getNewDomainRoot = "OU=$getDomain"+","+"$getCurrentDomainRoot"
$currentDefaultComputersContainer = (Get-ADDomain | Select-Object -ExpandProperty ComputersContainer)
$newDefaultComputersContainer = (Get-ADOrganizationalUnit -Filter * | Where-Object {$_.Name -like "Computers" -and $_.DistinguishedName -like "*$getNewDomainRoot"} | ForEach-Object {$_.DistinguishedName})
$currentDefaultUsersContainer = Get-ADDomain | Select-Object -ExpandProperty UsersContainer
$newDefaultUsersContainer = (Get-ADOrganizationalUnit -Filter * | Where-Object {$_.Name -like "Users" -and $_.DistinguishedName -like "*$getNewDomainRoot"} | ForEach-Object {$_.DistinguishedName})

###
### Establish functions
###

function CreateOU($ouName,$ouPath){
Write-Host "Attempting to create $ouName in $ouPath"
    try{
        New-ADOrganizationalUnit -Name $ouName -Path $ouPath
        Write-Host "OU does not already exist, created successfully"

        }
    catch [Microsoft.ActiveDirectory.Management.ADException]{
        Write-Host "SKIPPING: OU already exists"
        }
    }

###
### Create new OUs
###

CreateOU $getDomain $getCurrentDomainRoot
CreateOU "Computers" (Get-ADOrganizationalUnit -Filter {Name -like $getDomain}| ForEach-Object {$_.DistinguishedName})
CreateOU "Users" (Get-ADOrganizationalUnit -Filter {Name -like $getDomain}| ForEach-Object {$_.DistinguishedName})
CreateOU "Security Groups" (Get-ADOrganizationalUnit -Filter {Name -like $getDomain}| ForEach-Object {$_.DistinguishedName})
CreateOU "Disabled" $getCurrentDomainRoot
CreateOU "Computers" (Get-ADOrganizationalUnit -Filter {Name -like "Disabled"}| ForEach-Object {$_.DistinguishedName})
CreateOU "Users" (Get-ADOrganizationalUnit -Filter {Name -like "Disabled"}| ForEach-Object {$_.DistinguishedName})

###
### Redirect users and computers
###

if($newDefaultComputersContainer -ne $currentDefaultComputersContainer){
    Write-Host "Computers needs to be redirected ..."
    Write-Host "Redirecting new computers from $currentDefaultComputersContainer to $newDefaultComputersContainer"
    redircmp $newDefaultComputersContainer
    }
    else{Write-Host "Computers has already been redirected"}

if($newDefaultUsersContainer -ne $currentDefaultUsersContainer) {
    Write-host "Users needs to be redirected ..."
    Write-Host "Redirecting new users from $currentDefaultUsersContainer to $newDefaultUsersContainer"
    redirusr $newDefaultUsersContainer
    }
    else{Write-Host "Users has already been redirected"}

###
### Move Users to new OU
###

$cnUsers = Get-ADUser -Filter * | Where-Object {$_.DistinguishedName -notlike "*$getNewDomainRoot*"}

if(!$cnUsers)
    { Write-Host "SKIPPING: All users have already been moved" }

foreach($user in $cnUsers){

    if(!(Move-ADObject $user -TargetPath (Get-ADOrganizationalUnit -SearchBase $getNewDomainRoot -Filter {Name -like "Users"}| ForEach-Object {$_.DistinguishedName})))
    { $Status = "SUCCESS" }

    else
    { $Status = "FAILED" }

    $objectOutput = New-Object -TypeName PSobject
    $objectOutput | Add-Member -MemberType NoteProperty -Name ObjectName -Value $user.Name.tostring()
    $objectOutput | Add-Member -MemberType NoteProperty -Name SourcePath -Value $user.DistinguishedName.ToString()
    $objectOutput | Add-Member -MemberType NoteProperty -Name DestinationPath -Value (Get-ADOrganizationalUnit -SearchBase $getNewDomainRoot -Filter {Name -like "Users"}| ForEach-Object {$_.DistinguishedName})
    $objectOutput | Add-Member -MemberType NoteProperty -Name Status -Value $Status
    $objectOutput
    }

###
### Move Computers to new OU
###

$cnComputers = Get-ADComputer -Filter * | Where-Object { $_.DistinguishedName -notlike "*$getNewDomainRoot*" -and $_.DistinguishedName -notlike "*Domain Controllers*"}

if(!$cnComputers)
        { Write-Host "SKIPPING: All computers have already been moved" }

foreach($computer in $cnComputers){

    if(!(Move-ADObject $computer -TargetPath (Get-ADOrganizationalUnit -SearchBase $getNewDomainRoot -Filter {Name -like "Computers"}| ForEach-Object {$_.DistinguishedName}))) 
        { $Status = "SUCCESS" } 

        else 
        { $Status = "FAILED" }

        $objectOutput = New-Object -TypeName PSobject
        $objectOutput | Add-Member -MemberType NoteProperty -Name ObjectName -Value $computer.Name.ToString()
        $objectOutput | Add-Member -MemberType NoteProperty -Name SourcePath -Value $computer.DistinguishedName.ToString()
        $objectOutput | Add-Member -MemberType NoteProperty -Name DestinationPath -Value (Get-ADOrganizationalUnit -SearchBase $getNewDomainRoot -Filter {Name -like "Computers"}| ForEach-Object {$_.DistinguishedName})
        $objectOutput | Add-Member -MemberType NoteProperty -Name Status -Value $Status
        $objectOutput
        }
###
### Move Groups to new OU
###

$cnSecGroups = Get-ADGroup -Filter * | Where-Object {$_.DistinguishedName -notlike "*$getNewDomainRoot*" -and $_.DistinguishedName -notlike "*Builtin*"}

if(!$cnSecGroups)
    { Write-Host "SKIPPING: All security groups have already been moved" }

foreach($secGroup in $cnSecGroups){

    if(!(Move-ADObject $secGroup -TargetPath (Get-ADOrganizationalUnit -SearchBase $getNewDomainRoot -Filter {Name -like "Security Groups"}| ForEach-Object {$_.DistinguishedName})))
    { $Status = "SUCCESS" }

    else
    { $Status = "FAILED" }

    $objectOutput = New-Object -TypeName PSobject
    $objectOutput | Add-Member -MemberType NoteProperty -Name ObjectName -Value $secGroup.Name.tostring()
    $objectOutput | Add-Member -MemberType NoteProperty -Name SourcePath -Value $secGroup.DistinguishedName.ToString()
    $objectOutput | Add-Member -MemberType NoteProperty -Name DestinationPath -Value (Get-ADOrganizationalUnit -SearchBase $getNewDomainRoot -Filter {Name -like "Security Groups"}| ForEach-Object {$_.DistinguishedName})
    $objectOutput | Add-Member -MemberType NoteProperty -Name Status -Value $Status
    $objectOutput

    }