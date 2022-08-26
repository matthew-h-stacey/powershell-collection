# Establish variables
$exportPath = "C:\TempPath\"
$mailboxExport = $exportPath + "_mailboxes.csv"
$distiReport = $exportPath + "_distis.csv"
$activeSyncReport = $exportPath + "_activesync.csv"

function Show-Menu
{
    $Title = 'Exchange/Office 365 health check'
    Clear-Host
    Write-Host "================ $Title ================"
    Write-Host "================ By Matt Stacey =================================="
    Write-Host "1: Press '1' for on-premises Exchange."
    Write-Host "2: Press '2' hosted Office 365."
    Write-Host "Q: Press 'Q' to quit."
}
function Connect-O365 {
    # Acquire MSOnline module
    Find-PackageProvider -Name 'Nuget' -ForceBootstrap -IncludeDependencies
    Install-Module MSOnline -Confirm:$false -Force -Scope CurrentUser
    # Request credentials
    $UserCredential = Get-Credential
    # Connect to MsolService and Office365
    Connect-MsolService -Credential $UserCredential
    $365session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri "https://outlook.office365.com/powershell-liveid/" -Credential $UserCredential -Authentication Basic -AllowRedirection 
    Import-Module (Import-PSSession $365session -AllowClobber) -Global
}

do
{
    Show-Menu
    $menuInput = Read-Host "Please make a selection"
    switch ($menuInput){
        '1' {
            Clear-Host
            'You chose on-premises Exchange'
            $client = Read-Host -Prompt 'Enter client name'
            if($client -eq [string]::empty){Write-Host "Input was null. Exiting..."}
            else{
                # Load Exchange Shell
                Add-PSSnapin Microsoft.Exchange.Management.PowerShell.* -ErrorAction SilentlyContinue

                # 1. Export list of mailboxes
                Get-Mailbox -ResultSize Unlimited -RecipientType UserMailbox | Select-Object DisplayName,PrimarySMTPAddress,HiddenFromAddressListsEnabled,WhenMailboxCreated | Export-CSV $mailboxExport -NoTypeInformation
                Write-Host "Exported mailbox report to $MailboxReport"
                    
                # 2. Export list of distribution groups and members
                $groupMembers = foreach($member in Get-DistributionGroup){Get-DistributionGroupMember $member | Select-Object Name,@{n='Member';e={$member.Name}}}
                $groupMembers | Export-Csv $distiReport -NoTypeInformation
                Write-Host "Exported distribution group report to $distiReport"

                # 3. Remove all ActiveSync partnerships that are 90+ days old
                Write-Host "Removing stale ActiveSync partnerships"
                try{
                    $oldActiveSyncPartnerships = Get-ActiveSyncDevice -result unlimited | Get-ActiveSyncDeviceStatistics | Where-Object {$_.LastSuccessSync -le (Get-Date).AddDays("-90")}
                    $oldActiveSyncPartnerships | foreach-object {Remove-ActiveSyncDevice ([string]$_.Guid) -confirm:$false} -ErrorAction Ignore
                    }
                catch {Write-Host "SKIPPING: No stale ActiveSync partnerships"}

                # 4. Export all ActiveSync partnerships
                $allActiveSyncPartnerships = Get-CASMailbox -Filter {hasactivesyncdevicepartnership -eq $true -and -not displayname -like "CAS_{*"} | Get-Mailbox
                $allActiveSyncPartnerships | ForEach-Object { Get-ActiveSyncDeviceStatistics -Mailbox $_} | Select-Object Identity,DeviceFriendlyName,LastSuccessSync | Export-CSV $activeSyncReport -NoTypeInformation
                Write-Host "Exported list of all ActiveSync partnerships to $activeSyncReport"
                    
                Write-Host "Press Enter to continue...:"

                cmd /c pause | out-null
                }
             }
        '2' {
            Clear-Host
            'You chose hosted Office 365'
            if (Get-Module -ListAvailable -Name MSOnline){
                Write-Host "SUCCESS: MSOnline installed. Continuing..."
                $client = Read-Host -Prompt 'Enter client name'
                if($client -eq [string]::empty){Write-Host "Input was null. Exiting..."}
                else{

                    $userReport = $exportPath + $client + "_O365_mailboxes.csv"
                    $licenseReport = $exportPath + $client + "_O365_licenses.csv"
                    $distiReport = $exportPath + $client + "_O365_distis.csv"
                
                    Connect-O365
                    Get-Msoluser -All | Select-Object DisplayName,UserPrincipalName,WhenCreated,isLicensed,@{ expression={$_.Licenses.AccountSkuID}; label='License'} | Export-CSV $userReport -NoTypeInformation
                    Write-Host "Exported user report to $userReport"
                    Get-MsolAccountSku | Select-Object @{expression={$_.SkuPartNumber};label='License'},@{expression={$_.ActiveUnits};label='Valid'},@{expression={$_.ConsumedUnits};label='Assigned'},@{expression={$_.WarningUnits};label='Expired'} | Export-CSV $licenseReport -NoTypeInformation
                    Write-Host "Exported license report to $licenseReport"}

                     $results = @()
                     $allDistis = Get-Group -RecipientTypeDetails MailUniversalDistributionGroup | Sort-Object DisplayName | Select-Object -expandproperty DisplayName
                     foreach ($disti in $allDistis) {
                                             $distimember = Get-DistributionGroupMember -Identity $disti
                                             foreach ($d in $distimember) {
                                                 $arrayDetails = @{
                                                     Group  = $disti
                                                     Member = $d
                                                    }
                                                    $results += New-Object psobject -Property $arrayDetails
                                                }
                                            }
                    $results | Export-Csv $distiReport -NoTypeInformation
                    Write-Host "Exported disti report to $licenseReport"
                    Get-PSSession | Remove-PSSession
                                        }
                    else{
                        Write-Host "Failed to install required modules"
                    }
                }
            
        'q' {
                return
        }
    }
     pause
}
until ($menuInput -eq 'q')