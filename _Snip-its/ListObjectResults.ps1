$results = [System.Collections.Generic.List[System.Object]]::new()

foreach ($obj in $Objects) {
    $UserExport = [PSCustomObject]@{
        Name = $obj.Name
        Email = $obj.Email
    }
    $results.Add($UserExport)
}

