# https://www.itechguides.com/powershell-try-catch-finally/
# Generate an error then run the following to capture the full error message:

$error[0].exception.gettype().fullname # full exception mame ***Most helpful***

($error.CategoryInfo).Reason # error categories/reasons

$error.clear() # clear errors

#

Try {
    Get-Content D:\PS-Tutorial\folder-names.txt -ErrorAction Stop
} 
Catch [System.UnauthorizedAccessException] {
}


try {
    $disti = Get-DistributionGroup -Identity $newPrimarySmtpAddress -ErrorAction Stop
}
catch {
    Write-Warning "Error locating Distribution Group using new PrimarySmtpAddress $newPrimarySmtpAddress"
}

#

try { NonsenseString }
catch {
    Write-Host "An error occurred:"
    Write-Host $_
}

Output:
An Error occurred:
The term 'NonsenseString' is not recognized as the name of a cmdlet, function,
script file, or operable program. Check the spelling of the name, or if a path
was included, verify that the path is correct and try again.