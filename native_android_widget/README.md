# SOS home screen widget — install instructions

These files can't live inside `android/` yet because that folder doesn't
exist until you run Step 0 in `BUILD_INSTRUCTIONS.md`
(`flutter create --org medaayu --project-name com .`). Once it does, copy
each file to its target path (noted in a comment at the top of each file):

| File here | Goes to |
|---|---|
| `sos_widget.xml` | `android/app/src/main/res/layout/sos_widget.xml` |
| `sos_widget_info.xml` | `android/app/src/main/res/xml/sos_widget_info.xml` |
| `SosWidgetProvider.kt` | `android/app/src/main/kotlin/medaayu/com/SosWidgetProvider.kt` |
| `AndroidManifest_widget_snippet.xml` | merge into `android/app/src/main/AndroidManifest.xml` (inside `<application>`) |

## Also required

- Add `home_widget: ^0.6.0` to `pubspec.yaml` — already done in this project.
- If your generated package path isn't `medaayu/com/` (i.e. you used a
  different `--org`/`--project-name` in Step 0), update the `package`
  line at the top of `SosWidgetProvider.kt` to match, and place the file
  at the matching path instead.
- `MainActivity::class.java` in the Kotlin file assumes the default
  generated `MainActivity` — leave as-is unless you renamed it.

## How it behaves

One tap on the home screen widget opens the app directly into the SOS
screen (see `lib/services/widget_service.dart` and the startup check in
`main.dart`) — using the elder's profile cached locally the last time they
opened the app normally, so it works even from a cold start without
needing to log in again.

## What I genuinely can't verify from here

I don't have Flutter, Android Studio, or a real device available to
compile and test this. Native widget code is the single most likely part
of this whole project to need a debugging pass — expect to iterate on it
in Android Studio rather than have it work first try. If it doesn't render
or the tap doesn't open the app, start by checking Logcat for the
`SosWidgetProvider` class actually being found (a mismatched package path
is the most common cause).
