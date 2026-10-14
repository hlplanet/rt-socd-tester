# Rapid Trigger & SOCD Tester for Windows

Native Windows version of the browser extension: a small WinForms window hosting the same tester page with WebView2
(the Edge engine built into Windows 11).

- Size: ~300 KB zipped (27 KB exe + Microsoft's WebView2 libraries)
- Requires: Windows 10/11 x64 with the WebView2 Runtime (built into Windows 11; on Windows 10 the app offers the download link)
- No install needed: unzip and run `RT-SOCD-Tester.exe`
- Browser shortcuts (F5, Ctrl+F, Ctrl+P...) are disabled so every key can be tested
- Links open in the user's normal browser and are tagged `utm_source=rt-socd-windows`
- Settings (best tap score) are stored in `%LOCALAPPDATA%\HLPlanet\RT-SOCD-Tester`

## Build
```
.\build.ps1
```
Output: `dist\RT-SOCD-Tester\` (the app folder) and `dist\RT-SOCD-Tester-<version>-win-x64.zip`.
Nothing to install: it uses the C# compiler that ships with Windows (.NET Framework 4.8).
The version number and the tester page (HTML/CSS/JS/icons) are taken from `..\rt-socd-extension`,
so the app and the extension always match.

## Files
- `src\App.cs`: the app window
- `src\app.manifest`: high-DPI and Windows 10/11 settings
- `src\app.ico`: icon (regenerate with `tools\make-icon.ps1`)
- `lib\`: WebView2 SDK 1.0.4258.31 from NuGet (Microsoft-signed, see WebView2-LICENSE.txt)

## Distribution notes
The exe is not code-signed, so when people download the zip, Windows SmartScreen may show
"Windows protected your PC" until they click "More info > Run anyway". To avoid that:
- Publish through the Microsoft Store (Microsoft signs the package for you), or
- Sign the exe with a code-signing certificate.
