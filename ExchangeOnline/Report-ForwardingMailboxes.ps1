######## Base Variables ########

# File the mailbox forwarding report will be exported to 
$workDir = "C:\Scripts" # root working directory
$exportFile = "$workDir\Exchange_Forwarding_Mailboxes.csv"

# Values for the email report. Change as needed
$mailTo = "it@contoso.com"
$mailFrom = "administrator@contoso.com"
$mailSubject = "Exchange Mailbox Forwarding Report"
$mailSMTPServer = "CONTOSO-SMTP.domain.local"

# Variables used for certificate-based App Reg authentication to EXO
$certName = [System.Environment]::UserName + "_" + [system.environment]::MachineName
$certThumbprint = Get-ChildItem Cert:\CurrentUser\My\ | Where-Object { $_.Subject -like "*$certName*" } | Select-Object -ExpandProperty Thumbprint
$appID = "XXXXX-XXXX-XXXX-XXXX-XXXXXXXX"
$orgName = "XXXXX.onmicrosoft.com"

######## Script start ########

Start-Transcript -Path "$workDir\Report-ForwardingMailboxes.log"

# Connect to EXO using App Reg application and certificate
Connect-ExchangeOnline -CertificateThumbPrint $certThumbprint -AppID $appID -Organization $orgName -ShowBanner:$false

# Retrieve all mailboxes with forwarding enabled
$forwardingMBs = Get-Mailbox | Where-Object { ($_.ForwardingSMTPAddress -ne $null) -or ($_.ForwardingAddress -ne $null) }
# $forwardingMBs | Sort-Object DisplayName | Select-Object DisplayName, UserPrincipalName, ForwardingSMTPAddress, ForwardingAddress

# For-each loop to gather and format properties for all the mailboxes with forwarding
$results = @()
foreach ( $user in $forwardingMBs ) {
    
    if ( $null -ne $user.ForwardingAddress ) {
        $ForwardingAddressUser = (Get-Recipient $user.ForwardingAddress).PrimarySmtpAddress
    } 
    else {
        $ForwardingAddressUser = $null
    }

    $output = [PSCustomObject]@{
        DisplayName = $user.DisplayName
        UserPrincipalName = $user.UserPrincipalName
        ForwardingSMTPAddress = $user.ForwardingSMTPAddress
        ForwardingAddress            = $ForwardingAddressUser
    }
    $results += $output

}
# Export results to the report file
$results | Export-Csv -Path $exportFile -NoTypeInformation

Disconnect-ExchangeOnline -Confirm:$false # disconnect from EXO once finished

######## Outbound email portion ########

# Retrieve attachment to check length
$attachment = Get-Item $exportFile -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

# If report is 0Kb it has no content (no users with large mailbox). If the file is not empty, attach it to the email
if (Test-Path $attachment) {

    If ((Get-Item $attachment).length -gt 0kb) {
        # At least once user has a large mailbox
        $mailBody = "Please see the attached report of all mailboxes with email forwarding and the addresses the mail is being forwarded to."
        Write-Output "Sending email - Mailboxes with forwarding found"
        Send-MailMessage -To $mailTo -From $mailFrom -Subject $mailSubject -SmtpServer $mailSMTPServer -Body $mailBody -Attachments $attachment.FullName
    }
    Else {
        # No users with a large mailbox
        $mailBody = "There are no mailboxes with email forwarding."
        Write-Output "sending email - No large mailboxes"  
        Send-MailMessage -To $mailTo -From $mailFrom -Subject $mailSubject -SmtpServer $mailSMTPServer -Body $mailBody
    }
}

######## End ########