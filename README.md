# Cooker Whistle Counter

A Flutter app that counts pressure cooker whistles using only the phone's microphone and rings an alarm when the target count is reached. No extra hardware needed.

## Features
- Large live count with a settable target (e.g. 3 whistles)
- Looping alarm and vibration at the target (listening stops automatically), until you tap **Stop alarm**
- Live level meter and threshold slider for calibration (settings are saved)
- Whistle log with the time of each whistle and the gap between them
- Screen stays on while listening

## Get the APK without installing Flutter
Every push to `main` builds a release APK with GitHub Actions.
Open the **Actions** tab → latest **Build APK** run → download **cooker-whistle-counter-apk** under *Artifacts*. Unzip it and install `app-release.apk` on your phone.

## Build locally
```bash
git clone https://github.com/banuch/cooker-whistle-counter.git
cd cooker-whistle-counter
bash setup.sh          # generates android/ and ios/, adds mic permissions
flutter run --release  # on a real phone; emulators have no usable mic
```

`setup.sh` runs `flutter create`, adds `RECORD_AUDIO`/`VIBRATE` to the Android manifest, sets `minSdk` ≥ 23, and adds the iOS microphone usage text.

## Calibrating (do this once)
1. Tap **Start listening** with the kitchen in its normal state. Note the dB level.
2. Watch the level during a real whistle (it should jump 15–30 dB).
3. Set the threshold slider roughly halfway between the two.
4. If spoon clinks or the mixie get counted, raise **Advanced → Minimum whistle length** to 600–800 ms.

## How it works
- 16 kHz mono PCM from the mic → 32 ms frames → Hann window → Goertzel filters at 2.0–4.5 kHz (every 125 Hz).
- One whistle = band level above the threshold for ≥ the minimum length; it re-arms after 1.5 s of quiet.
- Detection lives in `lib/whistle_detector.dart`, with unit tests in `test/`.

## Limitations
- The app must stay open in the foreground (Android/iOS restrict background mic use).
- Keep the phone 1–2 m from the cooker, away from the steam.
