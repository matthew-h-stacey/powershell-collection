# WIP

# https://learn.microsoft.com/en-us/exchange/permissions-exo/application-rbac
# Make a mail-enabled security group "Restrict password notification app"
# Make a shared mailbox (noreply@, passwordreset@, etc.)
# Add the shared mailbox to the mail-enabled security group
# Make an Enterprise app "PasswordExpirationNotifier." Notate the application and object ID of the enterprise app, not app reg
# Locate the app reg for the newly created Enterprise app. Upload a device certificate from the machine that will later run the script
# Create SPN
$spn = New-ServicePrincipal -AppId $entAppId -ObjectId $entObjId -DisplayName $spnDn
# Create management role assignment to restrict the app to send only from the accounts in the mail-enabled security group
New-ManagementRoleAssignment -App $spn.AppId -Role "Application Mail.Send" -SecurityGroup $securityGroup
# Connect to Graph using the certificate thumbprint
# Send email using SendMgUserMail


Import-Module Microsoft.Graph.Users.Actions
Connect-MgGraph -CertificateThumbprint $thumbPrint -ClientId $clientId -TenantId $tenantId
