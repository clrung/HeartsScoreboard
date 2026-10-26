# App Store header and search results assets

`header.html` (3840×1646, uploaded as PNG; App Store Connect rejects .jpg for the header) and
`search.html` (3840×2560) lay out screenshots from the sibling folders. They have no text,
so no per-locale versions are needed. To regenerate, copy these into a folder with
`duo_main.png` (iPhone Duo Open/1), `ip_dark.png` (iOS 6.9/5), `ip_round.png` (iOS 6.9/2) and
`ip_summary.png` (iOS 6.9/3), then render each with headless Chrome:

    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --hide-scrollbars \
      --force-device-scale-factor=1 --allow-file-access-from-files \
      --window-size=3840,1646 --screenshot=header.png file://$PWD/header.html

Strip alpha before uploading (e.g. `sips -s format jpeg` then back to png).
