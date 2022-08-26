# https://docs.microsoft.com/en-us/windows/configuration/find-the-application-user-model-id-of-an-installed-app

$installedapps = Get-AppxPackage

$aumidList = @()
foreach ($app in $installedapps) {
    foreach ($id in (Get-AppxPackageManifest $app).package.applications.application.id) {
        $aumidList += $app.packagefamilyname + "!" + $id
    }
}

$aumidList