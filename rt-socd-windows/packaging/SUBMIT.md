# Submitting to winget, Chocolatey and Scoop

All three download the app zip from a permanent public URL and check its SHA256 checksum.
Do steps 1-2 once, then 3-5 in any order.

## 1. Host the zip on GitHub (free)
1. Create a public repo named `rt-socd-tester` on your GitHub account.
2. Add `icon128.png` (from `..\..\rt-socd-extension\icons\`) to the repo root (Chocolatey shows it as the package icon) and a short README linking to https://www.hlplanet.com/online-keyboard-tester-tool/
3. Create a release with tag `v1.0.0` and attach `..\dist\RT-SOCD-Tester-1.0.0-win-x64.zip`. Upload that exact file: rebuilding the zip changes its checksum.

## 2. Generate the packages for your account
```
.\make-packages.ps1 -Owner your-github-name -ChocolateyUser your-chocolatey-name
```
Everything is written to `out\`.

## 3. winget (Windows Package Manager, built into Windows)
Easiest: install wingetcreate (`winget install Microsoft.WingetCreate`) and run
```
wingetcreate submit --token <github-token> out\winget\manifests\h\HLPlanet\RTSOCDTester\1.0.0
```
(Or fork github.com/microsoft/winget-pkgs, copy the `manifests\h\HLPlanet\...` folder in, and open a pull request.)
Automated checks run first, then a Microsoft moderator reviews it, usually within a few days.
Users install with: `winget install HLPlanet.RTSOCDTester`

## 4. Chocolatey
1. Create an account at https://community.chocolatey.org (the username must match `-ChocolateyUser`).
2. Install Chocolatey, then in `out\chocolatey\`:
```
choco pack
choco push rt-socd-tester.1.0.0.nupkg --source https://push.chocolatey.org/ --api-key <your-key>
```
Automated validation, verification and a human moderator review follow; first packages can take one to a few weeks.
Users install with: `choco install rt-socd-tester`

## 5. Scoop
The main Scoop "Extras" bucket only accepts reasonably well-known apps, so a brand-new app will likely be declined.
Create your own bucket instead:
1. Make a public repo named `scoop-bucket`, put `out\scoop\rt-socd-tester.json` in a `bucket\` folder.
2. Users install with:
```
scoop bucket add hlplanet https://github.com/your-github-name/scoop-bucket
scoop install rt-socd-tester
```
Once the app has users and GitHub stars, open a pull request to github.com/ScoopInstaller/Extras.

## New version later
1. Bump `version` in `rt-socd-extension\manifest.json`, run `..\build.ps1`
2. New GitHub release `v<version>` with the new zip
3. Re-run `make-packages.ps1` and submit again (winget: `wingetcreate update HLPlanet.RTSOCDTester ...`)
