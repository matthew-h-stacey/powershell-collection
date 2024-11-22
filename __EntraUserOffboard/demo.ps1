### Create demo user
$first = "Santa"
$last = "Claus"
$upn = "${first}.${last}@5r86fn.onmicrosoft.com"
$params = @{
    UPNMatchesMail                = $True
    ForceChangePasswordNextSignIn = $False
    GivenName                     = $first
    Surname                       = $last
    UserPrincipalName             = $upn
    UsageLocation                 = 'US'
    Password                      = 'T3ch##2013$$'
    AddLicenses                   = @('c42b9cae-ea4f-4ab7-9717-81576235ccac')
    CompanyName                   = 'Contoso'
    JobTitle                      = 'Software Engineer'
    Department                    = 'Engineering'
    Manager                       = 'JoniS@5r86fn.onmicrosoft.com'
    EmployeeID                    = '12345'
    HireDate                      = '2020-02-18'
    StreetAddress                 = '123 Main St'
    City                          = 'Redmond'
    State                         = 'WA'
    PostalCode                    = '98052'
    BusinessPhones                = '555-123-4567'
    MobilePhone                   = '505-124-1230'
}
New-M365User @params

### Add user to Unified groups
$user = Get-MgUser -UserId $upn

$groupsToJoin = @(
    "cf307315-14d7-4aed-ada4-f6337fb7198e" # Coffee Crew
    "e89462a6-645c-4a43-ab1f-705414b9bb99" # Superstars
    "b61f2340-ff38-4b2a-b0dd-447cbfa21ffd" # Digital Initiative Public Relations
    "4f16c778-b405-46e0-a85f-13eeeb003a25" # Retail
    "8c7333c6-6adc-4297-8f30-60dafd09752f" # All Company
)
$params = @{
    "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$($user.Id)"
}
$groupsToJoin | ForEach-Object {
    New-MgGroupMemberByRef -GroupId $_ -BodyParameter $params
}

### Grant user ownership of Unified groups
$groupsToOwn = @(
    "4f16c778-b405-46e0-a85f-13eeeb003a25" # Retail
    "e89462a6-645c-4a43-ab1f-705414b9bb99" # Superstars
)
$groupsToOwn | ForEach-Object {
    New-MgGroupOwnerByRef -GroupId $_ -BodyParameter $params
}

### Add user to distis
Add-DistributionGroupMember -Identity InboundLeads@5r86fn.onmicrosoft.com -Member $User.UserPrincipalName
Add-DistributionGroupMember -Identity SeattleOffice@5r86fn.onmicrosoft.com -Member $User.UserPrincipalName

### Add user to Entra security groups
$securityGroups = @(
    "4fad90ce-3176-4e8b-b6fb-bde848336a1b" # SEC - MFA Bypass
    "cd84c441-c68f-4f3d-842c-72960bc7fb95" # SSPR Users
)
$securityGroups | ForEach-Object {
    New-MgGroupMemberByRef -GroupId $_ -BodyParameter $params
}

### Log in and set MFA

### Offboard user
$params = @{
    SharedMailbox       = $True
    ForwardEmail        = $True
    GrantMailboxAccess  = $True
    GrantOneDriveAccess = $True
    UserConfirmation    = 'Yes'
    UserPrincipalName   = $upn
    ForwardingAddress   = 'cloudadmin@5r86fn.onmicrosoft.com'
    MailboxTrustee      = 'cloudadmin@5r86fn.onmicrosoft.com'
    OneDriveTrustee     = 'cloudadmin@5r86fn.onmicrosoft.com'
}
Revoke-EntraUserAccess @params