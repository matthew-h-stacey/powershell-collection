Set-ExecutionPolicy RemoteSigned

Clear-Host
Write-Host "Empty Folders Deleter"; Write-Host "";

$FolderPath = Read-Host -Prompt 'Enter path of directory to search'

Get-ChildItem -LiteralPath $FolderPath -Force -Recurse | Where-Object {
    $_.PSIsContainer -and `
    @(Get-ChildItem -LiteralPath $_.Fullname -Force -Recurse | Where { -not $_.PSIsContainer }).Count -eq 0 } |
    Remove-Item -Recurse -WhatIf