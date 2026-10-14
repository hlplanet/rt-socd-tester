# Builds the Windows app into dist\RT-SOCD-Tester\ and a portable zip.
# Needs nothing extra: the C# compiler ships with Windows (.NET Framework 4.8) and WebView2 is built into Windows 11.
# The tester page itself (HTML/CSS/JS) comes from ..\rt-socd-extension, so both always match.
# Run from PowerShell:  .\build.ps1
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$root = $PSScriptRoot
$extension = Join-Path $root '..\rt-socd-extension'
$version = (Get-Content (Join-Path $extension 'manifest.json') -Raw | ConvertFrom-Json).version
$csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$fx = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319'
$lib = Join-Path $root 'lib'
$dist = Join-Path $root 'dist'
$app = Join-Path $dist 'RT-SOCD-Tester'

if (Test-Path $dist) { Remove-Item -Recurse -Force $dist }
New-Item -ItemType Directory -Force (Join-Path $app 'web\icons') | Out-Null

# Keep the exe version in step with the extension version
$source = Get-Content (Join-Path $root 'src\App.cs') -Raw
$source = $source -replace 'Assembly(File)?Version\("[^"]*"\)', ('Assembly$1Version("' + $version + '.0")')
$tempSource = Join-Path $dist 'App.cs'
[System.IO.File]::WriteAllText($tempSource, $source)

& $csc /nologo /target:winexe /platform:x64 /optimize+ `
    "/out:$(Join-Path $app 'RT-SOCD-Tester.exe')" `
    "/win32icon:$(Join-Path $root 'src\app.ico')" `
    "/win32manifest:$(Join-Path $root 'src\app.manifest')" `
    "/reference:$(Join-Path $fx 'System.Windows.Forms.dll')" `
    "/reference:$(Join-Path $fx 'System.Drawing.dll')" `
    "/reference:$(Join-Path $lib 'Microsoft.Web.WebView2.Core.dll')" `
    "/reference:$(Join-Path $lib 'Microsoft.Web.WebView2.WinForms.dll')" `
    $tempSource
if ($LASTEXITCODE -ne 0) { throw "Compile failed" }
Remove-Item $tempSource

Copy-Item (Join-Path $lib '*.dll') $app
Copy-Item (Join-Path $lib 'WebView2-LICENSE.txt') $app
Copy-Item (Join-Path $extension 'tester.html'), (Join-Path $extension 'tester.css'), (Join-Path $extension 'tester.js') (Join-Path $app 'web')
Copy-Item (Join-Path $extension 'icons\*.png') (Join-Path $app 'web\icons')

# Portable zip (forward-slash paths, works everywhere)
$zipPath = Join-Path $dist "RT-SOCD-Tester-$version-win-x64.zip"
$zip = [System.IO.Compression.ZipFile]::Open($zipPath, 'Create')
try {
    Get-ChildItem $app -Recurse -File | ForEach-Object {
        $rel = 'RT-SOCD-Tester/' + $_.FullName.Substring($app.Length + 1).Replace('\', '/')
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $_.FullName, $rel, 'Optimal') | Out-Null
    }
} finally {
    $zip.Dispose()
}
Write-Host "Built $app"
Write-Host "Built $zipPath"
