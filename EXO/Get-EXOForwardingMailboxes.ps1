function Get-EXOForwardingMailboxes {

param(
)

    # Retrieve all mailboxes with forwarding enabled
    $ForwardingMBs = Get-Mailbox | Where-Object { ($null -ne $_.ForwardingSMTPAddress) -or ($null -ne $_.ForwardingAddress ) }

    # For-each loop to gather and format properties for all the mailboxes with forwarding
    $results = @()
    foreach ( $User in $ForwardingMBs ) {
        
        if ( $User.ForwardingAddress ) {
            $ForwardingAddressUser = (Get-Recipient $User.ForwardingAddress).PrimarySmtpAddress
        } 
        else {
            $ForwardingAddressUser = $null
        }

        $Output = [PSCustomObject]@{
            DisplayName = $User.DisplayName
            UserPrincipalName = $User.UserPrincipalName
            ForwardingSMTPAddress = $User.ForwardingSMTPAddress
            ForwardingAddress            = $ForwardingAddressUser
        }
        $results += $Output

    }
    # Export results to the report file
    $results | Sort-Object DisplayName | Out-SkyKickTableToHtmlReport -IncludePartnerLogo -ReportTitle "Forwarding Mailbox Report" -ReportFooter "Report created using SkyKick Cloud Manager" -OutTo NewTab

	
}