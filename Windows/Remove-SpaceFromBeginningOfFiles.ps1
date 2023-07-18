param(
    [Parameter(Mandatory=$true)][String]$Path
)

# Test path before proceeding
if (Test-Path -Path $Path) {

    $Path = "E:\Shared\Users\jcunningham\Desktop\Quotes\"
    $FileWithSpace = Get-ChildItem -Path $Path -Filter " *.*" -Recurse

    $Results = New-Object System.Collections.ArrayList

    foreach ( $File in $FileWithSpace) {

        # Notate the file for output
        $results.Add($File.FullName) | Out-Null
        
        # Create a new string without the space at the beginning
        $newName = $File.name.Substring(1)
            
        # Rename the item
        try {
            $File | Rename-Item -NewName $newName
            Write-Output "Renamed '"$($File.Name)"' to $newName"
        }
        catch {
            Write-Output "[ERROR] Failed to rename file: $($File.FullName)"
            Write-Output $_.Exception.Message
        }
    }

}

else {
    Write-Output "The specified path does not exist: $Path"
}