# Cinemana Pro (Clean-room)
SwiftUI clean-room implementation using publicly reachable Cinemana/Shabakaty-compatible endpoints discovered from the supplied build.

## Build locally
1. Install XcodeGen: `brew install xcodegen`
2. Run `xcodegen generate`
3. Open `CinemanaPro.xcodeproj` in Xcode.

## GitHub Actions
Push to `main` or run **Build Unsigned IPA** manually. The workflow creates an unsigned IPA as an artifact and publishes it in Releases.

## Notes
The upstream API is undocumented and may require ISP access, authentication, headers, cookies, or endpoint adjustments. The adaptive JSON parser is intentionally tolerant, but API behavior cannot be guaranteed without official documentation.

## API compatibility update 1.1
- Uses the catalog hosts only (`cinemana.shabakaty.com`, `cee.buzz`).
- Supports the actual Cinemana field names found in the supplied build: `ar_title`, `en_title`, `imgObjUrl`, `imgThumbObjUrl`, `ar_content`, `filmRating`, `seriesRating`, and others.
- Sends the same public request headers observed in the supplied build.
- Tries endpoint variants with and without `/api/android` and trailing slash.
- Shows a useful network/API error instead of an empty home screen.

The original IPA is larger mainly because it bundles Google Cast, widgets, fonts, audio and other resources. Binary size does not indicate whether an API is present.
