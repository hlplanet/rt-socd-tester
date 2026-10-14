# Generates winget, Chocolatey and Scoop packages for the built zip in ..\dist.
# The zip must be hosted at a permanent public URL. Default: a GitHub release in <Owner>/rt-socd-tester.
#
#   .\make-packages.ps1 -Owner your-github-name
#
# Upload dist\RT-SOCD-Tester-<version>-win-x64.zip to the GitHub release "v<version>" BEFORE submitting.
# The checksum is taken from that exact file: if you rebuild the zip, re-run this script and re-upload.
param(
    [Parameter(Mandatory = $true)][string]$Owner,
    [string]$Repo = 'rt-socd-tester',
    [string]$ChocolateyUser = 'hlplanet'
)
$ErrorActionPreference = 'Stop'

$root = Split-Path $PSScriptRoot -Parent
$version = (Get-Content (Join-Path $root '..\rt-socd-extension\manifest.json') -Raw | ConvertFrom-Json).version
$zipName = "RT-SOCD-Tester-$version-win-x64.zip"
$zip = Join-Path $root "dist\$zipName"
if (-not (Test-Path $zip)) { throw "Build first: $zip not found" }
$sha = (Get-FileHash $zip -Algorithm SHA256).Hash
$repoUrl = "https://github.com/$Owner/$Repo"
$url = "$repoUrl/releases/download/v$version/$zipName"
$today = Get-Date -Format 'yyyy-MM-dd'
$site = 'https://www.hlplanet.com/online-keyboard-tester-tool/'
$short = 'Test rapid trigger tap speed and SOCD / Snap Tap on Hall effect and TMR keyboards.'
$long = 'Rapid trigger tap test (taps per second, peak rate, shortest release gap) and SOCD / Snap Tap test (detects whether opposite keys are swapped by the keyboard). Small native app, no data collected. Full keyboard tester: ' + $site

$out = Join-Path $PSScriptRoot 'out'
if (Test-Path $out) { Remove-Item -Recurse -Force $out }
$utf8 = New-Object System.Text.UTF8Encoding($false)
function Write-File([string]$path, [string]$text) {
    New-Item -ItemType Directory -Force (Split-Path $path -Parent) | Out-Null
    [System.IO.File]::WriteAllText($path, $text.Replace("`r`n", "`n"), $utf8)
}

# ---- winget (submit as a pull request to github.com/microsoft/winget-pkgs) ----
$id = 'HLPlanet.RTSOCDTester'
$wg = Join-Path $out "winget\manifests\h\HLPlanet\RTSOCDTester\$version"
$schema = '1.12.0'
Write-File "$wg\$id.yaml" @"
# yaml-language-server: `$schema=https://aka.ms/winget-manifest.version.$schema.schema.json
PackageIdentifier: $id
PackageVersion: $version
DefaultLocale: en-US
ManifestType: version
ManifestVersion: $schema
"@
Write-File "$wg\$id.installer.yaml" @"
# yaml-language-server: `$schema=https://aka.ms/winget-manifest.installer.$schema.schema.json
PackageIdentifier: $id
PackageVersion: $version
InstallerType: zip
NestedInstallerType: portable
NestedInstallerFiles:
- RelativeFilePath: RT-SOCD-Tester\RT-SOCD-Tester.exe
  PortableCommandAlias: rt-socd-tester
ArchiveBinariesDependOnPath: true
Dependencies:
  PackageDependencies:
  - PackageIdentifier: Microsoft.EdgeWebView2Runtime
ReleaseDate: $today
Installers:
- Architecture: x64
  InstallerUrl: $url
  InstallerSha256: $sha
ManifestType: installer
ManifestVersion: $schema
"@
Write-File "$wg\$id.locale.en-US.yaml" @"
# yaml-language-server: `$schema=https://aka.ms/winget-manifest.defaultLocale.$schema.schema.json
PackageIdentifier: $id
PackageVersion: $version
PackageLocale: en-US
Publisher: HLPlanet
PublisherUrl: https://www.hlplanet.com/
PublisherSupportUrl: $site
Author: HLPlanet
PackageName: Rapid Trigger & SOCD Tester
PackageUrl: $site
License: MIT
LicenseUrl: $repoUrl/blob/main/LICENSE
Copyright: Copyright (c) 2026 HLPlanet
PrivacyUrl: $repoUrl/blob/main/rt-socd-extension/PRIVACY.md
ReleaseNotesUrl: $repoUrl/releases/tag/v$version
ShortDescription: '$short'
Description: '$long'
Moniker: rt-socd-tester
Tags:
- keyboard
- keyboard-tester
- rapid-trigger
- socd
- snap-tap
- hall-effect
- gaming
ManifestType: defaultLocale
ManifestVersion: $schema
"@

# ---- Chocolatey (pack with "choco pack", push with "choco push" to community.chocolatey.org) ----
$ch = Join-Path $out 'chocolatey'
Write-File "$ch\rt-socd-tester.nuspec" @"
<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://schemas.microsoft.com/packaging/2015/06/nuspec.xsd">
  <metadata>
    <id>rt-socd-tester</id>
    <version>$version</version>
    <title>Rapid Trigger &amp; SOCD Tester</title>
    <authors>HLPlanet</authors>
    <owners>$ChocolateyUser</owners>
    <projectUrl>$site</projectUrl>
    <packageSourceUrl>$repoUrl</packageSourceUrl>
    <projectSourceUrl>$repoUrl</projectSourceUrl>
    <bugTrackerUrl>$repoUrl/issues</bugTrackerUrl>
    <iconUrl>https://cdn.jsdelivr.net/gh/$Owner/$Repo@main/icon128.png</iconUrl>
    <copyright>HLPlanet.com</copyright>
    <licenseUrl>$repoUrl/blob/main/LICENSE</licenseUrl>
    <requireLicenseAcceptance>false</requireLicenseAcceptance>
    <releaseNotes>$repoUrl/releases/tag/v$version</releaseNotes>
    <tags>keyboard keyboard-tester rapid-trigger socd snap-tap hall-effect gaming foss</tags>
    <summary>$short</summary>
    <description>$long</description>
    <dependencies>
      <dependency id="webview2-runtime" />
    </dependencies>
  </metadata>
  <files>
    <file src="tools\**" target="tools" />
  </files>
</package>
"@
Write-File "$ch\tools\chocolateyinstall.ps1" @"
`$ErrorActionPreference = 'Stop'
`$toolsDir = Split-Path -Parent `$MyInvocation.MyCommand.Definition

Install-ChocolateyZipPackage -PackageName `$env:ChocolateyPackageName -UnzipLocation `$toolsDir ``
  -Url64bit '$url' ``
  -Checksum64 '$sha' -ChecksumType64 'sha256'

`$exe = Join-Path `$toolsDir 'RT-SOCD-Tester\RT-SOCD-Tester.exe'
# Mark as a GUI app so the command-line shim doesn't wait for the window to close
New-Item "`$exe.gui" -ItemType File -Force | Out-Null
# Start menu shortcut
Install-ChocolateyShortcut -ShortcutFilePath (Join-Path ([Environment]::GetFolderPath('CommonPrograms')) 'Rapid Trigger & SOCD Tester.lnk') -TargetPath `$exe
"@
Write-File "$ch\tools\chocolateyuninstall.ps1" @"
`$shortcut = Join-Path ([Environment]::GetFolderPath('CommonPrograms')) 'Rapid Trigger & SOCD Tester.lnk'
if (Test-Path `$shortcut) { Remove-Item `$shortcut -Force }
"@

# Pack the Chocolatey files into a .nupkg (Open Packaging Conventions zip, same format "choco pack" makes)
Add-Type -AssemblyName WindowsBase
$nupkgPath = Join-Path $ch "rt-socd-tester.$version.nupkg"
$pkg = [System.IO.Packaging.Package]::Open($nupkgPath, [System.IO.FileMode]::Create)
try {
    $parts = @(
        @{ uri = "/rt-socd-tester.nuspec"; file = (Join-Path $ch "rt-socd-tester.nuspec"); type = "application/octet" },
        @{ uri = "/tools/chocolateyinstall.ps1"; file = (Join-Path $ch "tools/chocolateyinstall.ps1"); type = "application/octet" },
        @{ uri = "/tools/chocolateyuninstall.ps1"; file = (Join-Path $ch "tools/chocolateyuninstall.ps1"); type = "application/octet" }
    )
    foreach ($p in $parts) {
        $part = $pkg.CreatePart((New-Object Uri($p.uri, [UriKind]::Relative)), $p.type, [System.IO.Packaging.CompressionOption]::Normal)
        $bytes = [System.IO.File]::ReadAllBytes($p.file)
        $stream = $part.GetStream()
        $stream.Write($bytes, 0, $bytes.Length)
        $stream.Dispose()
        if ($p.uri -like "*.nuspec") {
            $pkg.CreateRelationship($part.Uri, [System.IO.Packaging.TargetMode]::Internal, "http://schemas.microsoft.com/packaging/2010/07/manifest") | Out-Null
        }
    }
    $pkg.PackageProperties.Identifier = "rt-socd-tester"
    $pkg.PackageProperties.Version = $version
    $pkg.PackageProperties.Creator = "HLPlanet"
    $pkg.PackageProperties.Description = $short
} finally {
    $pkg.Close()
}

# ---- Scoop (your own bucket repo, or a pull request to ScoopInstaller/Extras) ----
$scoop = [ordered]@{
    version      = $version
    description  = $short
    homepage     = $site
    license      = 'MIT'
    depends      = @()
    notes        = 'Needs the Microsoft Edge WebView2 Runtime (built into Windows 11).'
    architecture = [ordered]@{ '64bit' = [ordered]@{ url = $url; hash = $sha.ToLower() } }
    extract_dir  = 'RT-SOCD-Tester'
    shortcuts    = @(, @('RT-SOCD-Tester.exe', 'Rapid Trigger & SOCD Tester'))
    checkver     = [ordered]@{ github = $repoUrl }
    autoupdate   = [ordered]@{ architecture = [ordered]@{ '64bit' = [ordered]@{ url = "$repoUrl/releases/download/v`$version/RT-SOCD-Tester-`$version-win-x64.zip" } } }
}
$scoop.Remove('depends')
Write-File "$out\scoop\rt-socd-tester.json" (($scoop | ConvertTo-Json -Depth 10) -replace '\\u0026', '&')

Write-Host "Version:  $version"
Write-Host "Zip URL:  $url"
Write-Host "SHA256:   $sha"
Write-Host "Written to $out"
Get-ChildItem $out -Recurse -File | ForEach-Object { '  ' + $_.FullName.Substring($out.Length + 1) }
