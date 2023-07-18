$results = New-Object System.Collections.Generic.List[System.Object]

foreach ($obj in $Objects) {
    $UserExport = [PSCustomObject]@{
        Name = $obj.Name
        Email = $obj.Email
    }
    $results.Add($UserExport)
}

