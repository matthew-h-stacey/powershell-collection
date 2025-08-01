function Clear-TeamsCache {
    <#
    .SYNOPSIS
    Stops Microsoft Teams and clears the cache.

    .EXAMPLE
    Clear-TeamsCache

    .NOTES
    Reference: https://learn.microsoft.com/en-us/troubleshoot/microsoftteams/teams-administration/clear-teams-cache
    #>

    # Stop Teams
    $teamsProcs = Get-Process | Where-Object { $_.name -like "*teams*" }
    if ( $teamsProcs ) {
        $teamsProcs | Stop-Process -Force
    }

    Start-Sleep -Seconds 15

    # Clear Teams cache
    $teamsPaths = @(
        "$env:LOCALAPPDATA\Microsoft\Teams"
        "$env:LOCALAPPDATA\Packages\MSTeams_8wekyb3d8bbwe\LocalCache\Microsoft\MSTeams"
    )
    foreach ( $path in $teamsPaths ) {
        if ( Test-Path $path ) {
            Get-ChildItem -Path $path -Recurse | Remove-Item -Force -Recurse
        }
    }

}

Clear-TeamsCache