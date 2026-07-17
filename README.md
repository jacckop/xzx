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
