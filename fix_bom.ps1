$enc = [System.Text.UTF8Encoding]::new($false)
Get-ChildItem -Path libraries\react-shared-libraries\src\translation\locales -Filter translation.json -Recurse | ForEach-Object {
    $content = [System.IO.File]::ReadAllText($_.FullName)
    [System.IO.File]::WriteAllText($_.FullName, $content, $enc)
    Write-Host "Fixed file: $($_.FullName)"
}
Write-Host "BOM Stripping Complete."
