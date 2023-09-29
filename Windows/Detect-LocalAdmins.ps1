# Name of the Cloud LAPS user that should remain a local admin
$DesiredAdminName = "BCS365_TEST"

# Create list of users that should be local admins (built-in admin + $DesiredAdminName)
$DesiredLocalAdmins = New-Object System.Collections.Generic.List[System.Object]
$BuiltInAdmin = Get-LocalUser | ?{$_.Description -like "Built-in account for administering the computer/domain"}
$DesiredLocalAdmins.Add($BuiltInAdmin.Name)
$DesiredLocalAdmins.Add($DesiredAdminName)

# Retrieve the current local administrators
$LocalAdmins = ([ADSI]"WinNT://./Administrators").psbase.Invoke('Members') | % {
 ([ADSI]$_).InvokeGet('AdsPath')
}
$LocalAdmins = $LocalAdmins -replace 'WinNT://', '' -replace '/', '\' | ?{$_ -notlike "S-1*"}

# Determine if there are additional local admins
$ExtraMembersPresent = $LocalAdmins | Where-Object { 
    $MemberWithoutDomain = $_.Split('\')[1]
    $DesiredLocalAdmins -notcontains $MemberWithoutDomain
}

try {
    # If extra local admins are present, throw an exception
    if ($ExtraMembersPresent) {
        exit 1
    }
    else {
        # If no extra local admins are present, exit code 0
        exit 0
    }
}
catch {
    # Catch any exception and handle it
    Write-Error "Error: $_"
    exit 1
}