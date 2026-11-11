# Epsilon Store Release

## Build outputs

- Google Play App Bundle: `build/app/outputs/bundle/release/app-release.aab`
- App Store IPA: `build/ios/ipa/Epsilon.ipa`
- iOS archive: `build/ios/archive/Runner.xcarchive`

## Version

- Version name: `1.0.5`
- Build number: `9`
- Android package: `com.epsilon.academy.said`
- iOS bundle id: `com.epsilon.education`

## Store notes

- Google Play: upload the `.aab` file to a release track.
- App Store: upload `Epsilon.ipa` using Transporter or App Store Connect tooling.
- iOS push entitlement is set to `production`.
- Android release signing uses `android/key.properties` and `android/app/upload-keystore.jks`.
- iOS includes `ios/Runner/PrivacyInfo.xcprivacy`.

## Required store metadata

- App name, short description, full description.
- Screenshots for required phone sizes.
- Privacy policy URL.
- Support/contact URL or email.
- Google Play data safety answers.
- App Store privacy nutrition answers.
