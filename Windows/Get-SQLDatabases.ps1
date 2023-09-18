<#
Locate SQL databases on a local network. Parses through servers and instances found and reports a list
Still a WIP
-MHS
#>

$instances = [System.Data.Sql.SqlDataSourceEnumerator]::Instance.GetDataSources()
$errors = @()
$results = @()

foreach ($instance in $instances) {
    $ServerName = $instance.ServerName
    $InstanceName = $instance.InstanceName
    if ( $InstanceName ) { $ServerInstance = $ServerName + '\' + $InstanceName }
    else { $ServerInstance = $ServerName } 
    try {    
        $databases = Invoke-Sqlcmd -ServerInstance $ServerInstance -Query "SELECT name FROM sys.databases" -ErrorAction Stop -WarningAction Stop  | Select-Object -ExpandProperty name
        $databases | foreach-object {
            if ( $instance.InstanceName ) {
                $DBName = if ($InstanceName) { "$ServerName\$InstanceName\$_" } else { "$ServerName\$_" }
                $results += $DBName
            }
            else {
                $DBName = if ($InstanceName) { "$ServerName\$InstanceName\$_" } else { "$ServerName\$_" }
                $results += $DBName
            }
        }
    }
    catch { 
        $errors += "[ERROR] Unable to connect to ${ServerInstance}. Error:"
        $errors += $_
    }
}

$results
$errors