# Objective: Update the UserPrincipalName, EmailAddress/mail, and proxyAddresses for a given user after an organization domain change - or when prepping a domain for SSO
#
# Preparation: First create a CSV file with required header "DisplayName" and all users whose UPNs need to be changed. Using a CSV versus a TargetOU allows for a quicker and
# wider application of the script. Save the file as "users.csv" to the $workDir
#
# Usage: .\Update-UPNandEmailAddresses.ps1 -Domain contoso.com
# For each user in the CSV file it will do the following things
# 1) Edit the suffix of the current UPN to be contoso.com
# 2) Change the EmailAddress to be the UPN
# 3) Remove "SMTP:$oldUPN" as a proxy address
# 4) Add "SMTP:$newUPN" as a proxy address
# 5 ) Add "smtp:$oldUPN" as a proxy address

Param
(   
    [Parameter(Mandatory = $true)] [string] $Domain # This is the new vanity domain to update UPN/EmailAddress properties with.  Example domain: contoso.com
)

Function Write-Log {
    Param ([string]$logstring)
    Add-Content $logFile -Value "$(Get-Date -Format "MM/dd/yyyy HH:mm") $logstring"
    Write-Host $logstring
}

# Standard variables
$workDir = "C:\TempPath" # The path which contains the required CSV file, and where to log the output of this script to
$users = Import-Csv $workDir\users.csv # Use a CSV file with header "DisplayName" and list of all users whose UPN/EmailAddress need to be updated
$logFile = "$workDir\UPN_Mail_Change_Report_$((Get-Date -Format "MM-dd-yyyy_HHmm")).log" # The name/path of the log file

# Initialize an empty variable for the script output later
$results = @()

# Start for-each to work through all users
foreach ($u in $users) {

    $displayName = $u.DisplayName
    $ADUser = Get-ADUser -Filter { DisplayName -like $displayName } -Properties EmailAddress,ProxyAddresses
    $UPN = $ADUser.UserPrincipalName
    $emailAddress = $ADUser.EmailAddress
    $newUPN = $UPN.Split("@")[0] + "@" + $domain # remove old domain, append new domain

    # Retrieve original values for user
    $userExport = New-Object -TypeName PSObject
    Add-Member -InputObject $userExport -MemberType NoteProperty -Name oldUPN -Value $UPN
    Add-Member -InputObject $userExport -MemberType NoteProperty -Name oldMail -Value $emailAddress
    Add-Member -InputObject $userExport -MemberType NoteProperty -Name oldProxyAddressess -Value (($ADUser.ProxyAddresses) -join ";")

    # 1) Change UPN
    Write-Log "[AD] Changing UPN from $($UPN) -> $($newUPN)"
    $ADUser | Set-ADUser -UserPrincipalName $newUPN
    # 2) Change EmailAddress
    Write-Log "[AD] Changing EmailAddress from: $($emailAddress) -> $($newUPN)"
    $ADUser | Set-ADUser -EmailAddress $newUPN

    # Format variables for proxyAddresses
    $replyAddress = "SMTP:"+$UPN
    $newReplyAddress = "SMTP:"+$newUPN
    $oldDomainAlias = "smtp:"+$UPN


    foreach ($proxy in $ADUser.proxyAddresses) {

        if($proxy -like $replyAddress) { # if the current (old UPN) is the reply addresses
            Write-Log "$($ADUser.Name): Removing proxyAddress $($proxy)" 
            Set-ADUser -Identity $ADUser.DistinguishedName -Remove @{'proxyAddresses' = $proxy } # 3) Remove "SMTP:$oldUPN" as a proxy address
            Write-Log "$($ADUser.Name): Replacing it with $($newReplyAddress)"
            Set-ADUser -Identity $ADUser.DistinguishedName -Add @{'proxyAddresses' = $newReplyAddress } # 4) Add "SMTP:$newUPN" as a proxy address
            Write-Log "$($ADUser.Name): Adding $($oldDomainAlias) as a secondary alias"
            Set-ADUser -Identity $ADUser.DistinguishedName -Add @{'proxyAddresses' = $oldDomainAlias } # 5 ) Add "smtp:$oldUPN" as a proxy address
        }
        else {
            Write-Log "$($ADUser.Name): Adding proxyAddress $($newReplyAddress)"
            Set-ADUser -Identity $ADUser.DistinguishedName -Add @{'proxyAddresses' = $newReplyAddress } # 4) Add "SMTP:$newUPN" as a proxy address
            Write-Log "$($ADUser.Name): Adding proxyAddress $($oldDomainAlias)"
            Set-ADUser -Identity $ADUser.DistinguishedName -Add @{'proxyAddresses' = $oldDomainAlias } # 5 ) Add "smtp:$oldUPN" as a proxy address
            
        }
    }


    # Retrieve values for updated user object
    try {
        $ADUser = Get-ADUser -Filter { UserPrincipalName -like $newUPN } -Properties EmailAddress, ProxyAddresses
        Write-Log "[AD] Success: located user using the new UPN:  $($newUPN)"
        Add-Member -InputObject $userExport -MemberType NoteProperty -Name newUPN -Value $ADUser.UserPrincipalName
        Add-Member -InputObject $userExport -MemberType NoteProperty -Name newMail -Value $ADUser.UserPrincipalName
        Add-Member -InputObject $userExport -MemberType NoteProperty -Name newProxyAddressess -Value (($ADUser.ProxyAddresses) -join ";")
    }
    catch {
        $errorRenameFail = "[AD] Error locating ADUser using new UPN: $($newUPN), rename failed"
        Write-Warning $errorRenameFail
        Write-Log $errorRenameFail
    }
    
    $results += $userExport 
    
}

    Write-Log "Exporting results to $workDir\UPN_Mail_Change_Report.csv"
    $results | Export-Csv -Path $workDir\UPN_Mail_Change_Report.csv -NoTypeInformation