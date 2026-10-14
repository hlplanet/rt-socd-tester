# Rapid Trigger & SOCD Tester (browser extension)

Toolbar extension with the two Hall effect tests from https://www.hlplanet.com/online-keyboard-tester-tool/

One Manifest V3 package works in Chrome, Edge, Brave, Opera and Firefox (140+).

## Files
- `manifest.json`: extension settings (name, version, icons, homepage link, Firefox id)
- `tester.html`, `tester.css`, `tester.js`: the tester (popup, or a full tab with `?tab=1`)
- `icons/`: toolbar and store icons
- `build.ps1`: makes the upload zip in `dist/`
- `STORE-LISTING.md`: texts and answers for the store forms
- `PRIVACY.md`: privacy policy you can host on hlplanet.com

## Try it locally
Chrome / Edge / Brave:
1. Open `chrome://extensions` (or `edge://extensions`)
2. Turn on Developer mode
3. Click "Load unpacked" and pick this folder
   (a warning about `browser_specific_settings` is expected: that key is for Firefox and Chrome ignores it)

Firefox:
1. Open `about:debugging#/runtime/this-firefox`
2. Click "Load Temporary Add-on" and pick `manifest.json`

## Publish
1. Bump `version` in `manifest.json` for every update
2. Run `.\build.ps1` and upload `dist\rt-socd-tester-<version>.zip` to:
   - Chrome Web Store: https://chrome.google.com/webstore/devconsole (one-time $5 developer fee)
   - Edge Add-ons: https://partner.microsoft.com/dashboard/microsoftedge (free)
   - Firefox Add-ons: https://addons.mozilla.org/developers/ (free)
3. Opera users can install the Chrome Web Store version. Safari needs a separate Xcode conversion (`xcrun safari-web-extension-converter`) and an Apple developer account.

## Links back to hlplanet.com
- `homepage_url` in the manifest (shown as the extension's website in the browser)
- "by HLPlanet.com" in the header and the call-to-action at the bottom of the tester,
  tagged with `utm_source=rt-socd-extension` so visits show up separately in analytics
- The store listing website field and description (see STORE-LISTING.md)
