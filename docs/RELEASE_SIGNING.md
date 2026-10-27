# Release Signing

## Android (Google Play)

1. Create an upload key (keep it outside the repo):
   ```bash
   keytool -genkeypair -v -keystore upload.jks -alias upload -keyalg RSA -keysize 4096 -validity 10000
   ```
2. Add GitHub repository secrets:
   `ANDROID_KEYSTORE_BASE64` (`base64 -w0 upload.jks`), `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`,
   `ANDROID_KEY_PASSWORD`.
3. CI writes `android/key.properties` + `android/app/upload.jks` only for the build step. Without secrets the
   release AAB is **unsigned** and CI prints a warning — it cannot be uploaded to Play.
4. Local release builds: create `apps/mobile/android/key.properties`
   (`storeFile`, `storePassword`, `keyAlias`, `keyPassword`; git-ignored).

## iOS (TestFlight)

Requires an Apple Developer Program team, a distribution certificate and an App Store provisioning profile for
`app.yuz.beauty`. CI currently runs `flutter build ios --no-codesign` (compile verification only). To ship:

1. Add `APPLE_TEAM_ID`, the certificate (`.p12`, base64) and password, the provisioning profile (base64) and an
   App Store Connect API key as secrets.
2. Import them into a temporary keychain on the macOS runner and run
   `flutter build ipa --release --export-options-plist=ios/ExportOptions.plist`.
3. Upload with `xcrun altool`/`notarytool` or Transporter.

No signing material exists in this repository; store submission requires the owner's credentials.
