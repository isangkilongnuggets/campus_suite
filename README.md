# Smart Campus Drop-Off Locker (Prototype)

Two Flutter apps sharing one Firebase project:

| Folder | What it is | Run on |
|---|---|---|
| `campus_locker/` | User app (book, pay, scan QR, pick up) | Real Android/iOS phone |
| `locker_display/` | Locker touchscreen simulator | Chrome (laptop) |
| `campus_shared/` | Shared models and Firestore code | (not run directly) |

## Requirements
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (run `flutter doctor`)
- An Android phone with USB debugging on (phone OTP login does not work on desktop)
- Access to the team's Firebase project

## Setup
1. Clone the repo and keep the three folders side by side.
2. Create the platform folders and install packages, in each app folder:
   ```
   cd campus_locker
   flutter create . --platforms=android,ios
   flutter pub get

   cd ../locker_display
   flutter create . --platforms=web
   flutter pub get
   ```

## Run
```
# Locker display (laptop)
cd locker_display
flutter run -d chrome

# User app (phone plugged in)
cd campus_locker
flutter devices
flutter run -d <device-id>
```

## Login
Real SMS is disabled. Use a **test phone number** added in Firebase Console > Authentication > Sign-in method > Phone > *Phone numbers for testing* (ask the owner for the numbers and codes).

## Android build note
Phone login needs your computer's SHA-1 and SHA-256 added in Firebase (Project settings > Your apps > Add fingerprint). Get them with `./gradlew signingReport` inside `campus_locker/android` and send them to the project owner. If the build complains about minSdk, set it to 23 in `android/app/build.gradle`.

## Quick demo
1. Phone: log in, create a profile, book a locker (recipient number = another test account), pay.
2. Locker screen: **Drop-off**, enter the PIN, scan the QR with the phone (or type the code), press **Close door**.
3. Recipient account: **Pick Up** tab shows the PIN. On the locker choose **Pick-up**, enter the PIN, scan the QR, press **Close door**.

Prototype only: checks run in the apps, PINs are unhashed, Firestore is in test mode, GCash is simulated.
