# Builds the store upload zips into dist\:
#   rt-socd-tester-<version>-chrome.zip   Chrome Web Store, Opera (no Firefox-only settings, so no warnings)
#   rt-socd-tester-<version>-edge.zip     Microsoft Edge Add-ons (same contents as the Chrome zip)
#   rt-socd-tester-<version>-firefox.zip  Firefox Add-ons (keeps the add-on id and data-collection declaration)
# Run from PowerShell:  .\build.ps1
# (Compress-Archive isn't used because Windows PowerShell writes "icons\x.png" paths, which stores reject.)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$root = $PSScriptRoot
$manifestText = Get-Content (Join-Path $root 'manifest.json') -Raw
$manifest = $manifestText | ConvertFrom-Json
$version = $manifest.version
$dist = Join-Path $root 'dist'
New-Item -ItemType Directory -Force $dist | Out-Null
Get-ChildItem $dist -Filter '*.zip' | Remove-Item

# Chromium browsers don't know browser_specific_settings, so leave it out of their manifest
$chromium = $manifest | Select-Object -Property * -ExcludeProperty browser_specific_settings
$chromiumText = $chromium | ConvertTo-Json -Depth 10

$files = @('tester.html', 'tester.css', 'tester.js')
$files += Get-ChildItem (Join-Path $root 'icons') -File | ForEach-Object { 'icons/' + $_.Name }

function New-ExtensionZip([string]$name, [string]$manifestJson) {
    $zipPath = Join-Path $dist $name
    $zip = [System.IO.Compression.ZipFile]::Open($zipPath, 'Create')
    try {
        # manifest.json as UTF-8 without BOM (a BOM can make browsers reject the manifest)
        $entry = $zip.CreateEntry('manifest.json', 'Optimal')
        $writer = New-Object System.IO.StreamWriter($entry.Open(), (New-Object System.Text.UTF8Encoding($false)))
        $writer.Write($manifestJson)
        $writer.Dispose()
        foreach ($file in $files) {
            $source = Join-Path $root ($file -replace '/', '\')
            [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $source, $file, 'Optimal') | Out-Null
        }
    } finally {
        $zip.Dispose()
    }
    Write-Host "Built dist\$name"
}

New-ExtensionZip "rt-socd-tester-$version-chrome.zip" $chromiumText
New-ExtensionZip "rt-socd-tester-$version-edge.zip" $chromiumText
New-ExtensionZip "rt-socd-tester-$version-firefox.zip" $manifestText
