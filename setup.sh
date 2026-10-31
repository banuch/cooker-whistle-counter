#!/usr/bin/env bash
# Generates the android/ and ios/ platform folders and adds the microphone
# permissions. Safe to run more than once. Used locally and by GitHub Actions.
set -euo pipefail
cd "$(dirname "$0")"

flutter create --org com.banuch --project-name cooker_whistle_counter \
  --platforms=android,ios .

# flutter create adds a sample test that doesn't match this app.
rm -f test/widget_test.dart

# --- Android permissions ---
MANIFEST=android/app/src/main/AndroidManifest.xml
if ! grep -q RECORD_AUDIO "$MANIFEST"; then
  sed -i '0,/<manifest[^>]*>/s//&\n    <uses-permission android:name="android.permission.RECORD_AUDIO"\/>\n    <uses-permission android:name="android.permission.VIBRATE"\/>/' "$MANIFEST"
fi

# --- Android minSdk >= 23 (needed by the record plugin) ---
if [ -f android/app/build.gradle.kts ]; then
  sed -i 's/minSdk = flutter.minSdkVersion/minSdk = maxOf(23, flutter.minSdkVersion)/' android/app/build.gradle.kts
elif [ -f android/app/build.gradle ]; then
  sed -i 's/minSdkVersion flutter.minSdkVersion/minSdkVersion Math.max(23, flutter.minSdkVersion)/; s/minSdk = flutter.minSdkVersion/minSdk = Math.max(23, flutter.minSdkVersion)/' android/app/build.gradle
fi

# --- iOS microphone usage text ---
PLIST=ios/Runner/Info.plist
if [ -f "$PLIST" ] && ! grep -q NSMicrophoneUsageDescription "$PLIST"; then
  sed -i '0,/<dict>/s//<dict>\n\t<key>NSMicrophoneUsageDescription<\/key>\n\t<string>Listens for pressure cooker whistles to count them.<\/string>/' "$PLIST"
fi

flutter pub get
echo "Setup done. Run: flutter run --release"
