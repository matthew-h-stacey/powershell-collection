function Clear-EXOMailboxMobileData {

    param(
        [Parameter(Mandatory=$True)]
        [String]
        $UserPrincipalName	
    )

    # Objective: Using a provided UPN, locate and initiate a data removal command to delete Outlook data from the phone (not a remote wipe)

    $userPhones = Get-MobileDevice -Mailbox $UserPrincipalName
    if ($null -eq $userPhones){
        Write-Output "[Clear mobile devices] No mobile devices found for $UserPrincipalName."
    }
    else {
        Write-Output "[Clear mobile devices] Found mobile device(s) for $UserPrincipalName. Initiating data removal commands to each device."
        foreach ($p in $userPhones) {    
            Clear-MobileDevice -Identity $p.DistinguishedName -AccountOnly -Confirm:$false
        }
    }
    
}