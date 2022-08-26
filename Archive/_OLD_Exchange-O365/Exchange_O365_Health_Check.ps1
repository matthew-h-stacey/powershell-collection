# NOTE:
# O365 check requires Azure ActiveDirectory (MSOnline) module
# See https://docs.microsoft.com/en-us/powershell/msonline/
# For DL: http://connect.microsoft.com/site1164/Downloads/DownloadDetails.aspx?DownloadID=59185

function Show-Menu
{
    $Title = 'Exchange/Office 365 health check'
    cls
    Write-Host "================ $Title ================"
    Write-Host "================ By Matt Stacey =================================="
    Write-Host "1: Press '1' for on-premises Exchange."
    Write-Host "2: Press '2' hosted Office 365."
    Write-Host "Q: Press 'Q' to quit."
}

do
{
    Show-Menu
    $input = Read-Host "Please make a selection"
    switch ($input) {
        '1' {
            cls
            'You chose on-premises Exchange'
            $Client = Read-Host -Prompt 'Enter client name'
            if($Client -eq [string]::empty){
                    Write-Host "Input was null. Exiting..."}
                else {
                    $exportPath = "C:\ + $Client"
                    $MailboxReport = "C:\" + $Client + "_mailboxes.csv"
                    $DistiReport = "C:\" + $Client + "_distis.csv"
                    Add-PSSnapin Microsoft.Exchange.Management.PowerShell.* -ErrorAction SilentlyContinue

                    # 1. Export list of mailboxes
                    Get-Mailbox -ResultSize Unlimited -RecipientType UserMailbox | select DisplayName,PrimarySMTPAddress,HiddenFromAddressListsEnabled,WhenMailboxCreated | Export-CSV $exportPath\_mailboxes.csv -NoTypeInformation
                    # test ...Get-Mailbox -ResultSize Unlimited -RecipientType UserMailbox | select DisplayName,PrimarySMTPAddress,HiddenFromAddressListsEnabled,WhenMailboxCreated | Export-CSV $MailboxReport -NoTypeInformation
                    
                    # 2. Export list of distribution groups and members
                    $GroupMembers = foreach($member in Get-DistributionGroup){
                        Get-DistributionGroupMember $member | select Name,@{n='Member';e={$member.Name}}
                        }
                        $GroupMembers | Export-Csv $DistiReport -Notypeinformation

                    Write-Host "Exported mailbox report to $MailboxReport"
                    Write-Host "Exported distribution group report to $DistiReport"

                    # 3. Remove all ActiveSync partnerships that are 90+ days old
                    Write-Host "Removing stale ActiveSync partnerships"
                        try{
                            $OldActiveSyncPartnerships = Get-ActiveSyncDevice -result unlimited | Get-ActiveSyncDeviceStatistics | where {$_.LastSuccessSync -le (Get-Date).AddDays("-90")}
                            $OldActiveSyncPartnerships | foreach-object {Remove-ActiveSyncDevice ([string]$_.Guid) -confirm:$false} -ErrorAction Ignore
                            }
                    catch {
                    Write-Host "SKIPPING: No stale ActiveSync partnerships"
                    }

                    # 4. Export all ActiveSync partnerships
                    $AllActiveSyncPartnerships = Get-CASMailbox -Filter {hasactivesyncdevicepartnership -eq $true -and -not displayname -like "CAS_{*"} | Get-Mailbox
                    $AllActiveSyncPartnerships | foreach { Get-ActiveSyncDeviceStatistics -Mailbox $_} | select Identity,DeviceFriendlyName,LastSuccessSync | Export-CSV C:\Scripts\AllActiveSyncPhones_Before.csv -NoTypeInformation
                    Write-Host "Exported list of all ActiveSync partnerships to C:\Scripts\AllActiveSyncPhones_Before.csv"
                    



                    # Get all remaining ActiveSync partnerships and export to a CSV

                    $AllActiveSyncPartnerships = Get-CASMailbox -Filter {hasactivesyncdevicepartnership -eq $true -and -not displayname -like "CAS_{*"} | Get-Mailbox
                    $AllActiveSyncPartnerships | foreach { Get-ActiveSyncDeviceStatistics -Mailbox $_} | select Identity,DeviceFriendlyName,LastSuccessSync | Export-CSV C:\Scripts\AllActiveSyncPhones_After.csv -NoTypeInformation
                    Write-Host "Exported list of all remaining ActiveSync partnerships to C:\Scripts\AllActiveSyncPhones_After.csv"

                    
                    Write-Host "Press Enter to continue...:"

                    cmd /c pause | out-null
                    }
                       
                }
        '2' {
            cls
            'You chose hosted Office 365'
            if (Get-Module -ListAvailable -Name MSOnline) {
                Write-Host "SUCCESS: MSOnline installed. Continuing..."
                $Client = Read-Host -Prompt 'Enter client name'
                if($Client -eq [string]::empty){
                    Write-Host "Input was null. Exiting..."}
                else {
                    $UserReport = "C:\" + $Client + "_O365_mailboxes.csv"
                    $LicenseReport = "C:\" + $Client + "_O365_licenses.csv"
                    Connect-MsolService
                    Get-Msoluser -All | select DisplayName,UserPrincipalName,WhenCreated,isLicensed,@{ expression={$_.Licenses.AccountSkuID}; label='License'} | Export-CSV $UserReport -NoTypeInformation
                    Write-Host "Exported user report to $UserReport"
                    Get-MsolAccountSku | select @{expression={$_.SkuPartNumber};label='License'},@{expression={$_.ActiveUnits};label='Valid'},@{expression={$_.ConsumedUnits};label='Assigned'},@{expression={$_.WarningUnits};label='Expired'} | Export-CSV $LicenseReport -NoTypeInformation
                    Write-Host "Exported license report to $LicenseReport"}
                    Get-PSSession | Remove-PSSession
                    }
                    else {
                        Write-Host "FAILED: MSOnline not installed. Please install first then run again (see script comments)"
                        cmd /c pause | out-null}
                    }
        'q' {
                return
        }
     }
     pause
}
until ($input -eq 'q')