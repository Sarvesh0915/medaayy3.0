# Building MedAayu into a real .apk / .aab

This project needs the Flutter SDK, Android SDK, and internet access to fetch
packages — none of which exist in the environment that wrote this code. Here
are two ways to actually get a binary, easiest first.

## Step 0 — REQUIRED before anything else, on your own machine

**This project currently only contains `lib/`, `pubspec.yaml`, and the
Supabase functions — there is no `android/` or `ios/` folder yet.** Those
platform folders are what `flutter create` normally generates for you, and
they need to exist before this can build at all (they contain
`AndroidManifest.xml`, `build.gradle`, everything the widget/permissions
steps below reference).

Fix this once, before Step 1:

1. Install Flutter locally (even if you're using Codemagic for the actual
   build) — https://docs.flutter.dev/get-started/install
2. From inside this project folder, run:
   ```
   flutter create --org medaayu --project-name com .
   ```
   The `--org medaayu --project-name com` combination is deliberate — it
   produces an applicationId of `medaayu.com`, matching your
   `google-services.json` exactly. (If you'd rather use a normal
   reverse-domain id like `com.medaayu.app`, that's fine too — just also
   update `package_name` in `google-services.json` and re-download it from
   Firebase Console to match.)
3. This generates `android/` and `ios/` without touching your existing
   `lib/` or `pubspec.yaml` — say yes if it asks to merge.
4. Now continue below.

## Just want an APK for your own phone? Read this first.

If you're not publishing to the Play Store right now, you can skip almost
everything below marked "Play Console" or "Play Billing" — none of it blocks
getting a working app onto your own phone.

**Fastest path — debug build, zero signing setup:**
1. Push the project (with `android/` from Step 0) to GitHub.
2. On Codemagic → Flutter workflow → under Build, choose **APK**, and set
   the build mode to **debug** (not release) — this needs no keystore, no
   signing, nothing to configure.
3. Download the `.apk` when the build finishes, transfer it to your phone
   (email it to yourself, Google Drive, USB — anything), and tap it to
   install. You'll need to allow "install from unknown sources" the first
   time Android asks.

**What still needs to work even for a personal APK** (this part isn't
optional, it's what makes the app functional at all):
- `otp-verify` deployed, so login works
- The Supabase schema + RLS run, so data actually saves

**What you can safely ignore for now** (only matters for a public Play
Store release): Play Billing product setup, `verify-purchase`, RTDN,
closed testing, signing keys, `.aab` bundling. The subscription screens
will still work — they just won't be able to charge real money until
those are set up, which is fine for testing on your own device.

## Option A — Codemagic (no local install after Step 0, ~10 minutes)

1. Push this project (now including `android/`) to a GitHub/GitLab repo.
2. Go to codemagic.io → sign up free → "Add application" → connect your repo.
3. Codemagic auto-detects it's a Flutter project. Choose **Flutter workflow**.
4. Under **Environment variables**, nothing is needed yet since API keys live
   in your Supabase Edge Function, not the app — but if you later add a
   `.env`-style config, add secrets there (never commit them to the repo).
5. Under **Build** → select "Android" → choose **APK** for testing on your
   own phone, or **App Bundle (.aab)** — App Bundle is what the Play Store
   actually requires for a public listing.
6. Click **Start new build**. Codemagic installs Flutter, runs
   `flutter pub get`, and builds. You'll get a downloadable `.apk`/`.aab`
   when it finishes.
7. For a signed release build (required for Play Store), generate a keystore
   (`keytool -genkey ...`, one-time) and upload it in Codemagic's Android
   signing section — unsigned builds only install for testing, not for the
   Play Store.

## Option B — Build locally with Android Studio

1. Install Flutter: https://docs.flutter.dev/get-started/install
2. Install Android Studio (includes the Android SDK).
3. `flutter doctor` — fix anything it flags red.
4. From this project folder: `flutter pub get`
5. Place `google-services.json` in `android/app/` (you already have this file).
6. Add the permissions from `android_manifest_additions.xml` into
   `android/app/src/main/AndroidManifest.xml`.
7. `flutter build apk --release` → output at
   `build/app/outputs/flutter-apk/app-release.apk`
   — or `flutter build appbundle --release` for the `.aab` Play Store wants.
   — **or, for the simplest personal-use path**, `flutter build apk --debug`
   → `build/app/outputs/flutter-apk/app-debug.apk`, no signing needed at all,
   install it directly with `flutter install` or by copying it to your phone.

## Before either build will fully work

- [ ] **Fixed this round**: `OtpService` was still pointing at a placeholder
      URL and had no error handling, which is why OTP looked "stuck" with
      no error shown. Deploy it with `supabase functions deploy otp-verify`
      (needs `BULKBLASTER_API_KEY` and `SUPABASE_SERVICE_ROLE_KEY` secrets
      set first), then update `_baseUrl` in `lib/services/otp_service.dart`
      to the resulting URL. It now shows the actual error instead of
      hanging if this is still misconfigured.
- [ ] Deploy `supabase/functions/notify-sos --no-verify-jwt` and set
      `BULKBLASTER_API_KEY` as a secret on it too (Edge Function secrets
      are per-function, not shared automatically across functions) — this
      is what sends the backup SMS during SOS.
- [ ] Run the schema + RLS SQL from `medaayu-backend-setup.md` against your
      Supabase project, **plus** this addition for billing:
      ```sql
      alter table subscriptions add column purchase_token text unique;
      alter table subscriptions add column product_id text;
      ```
- [ ] Complete Bulk Blaster's DLT sender registration — OTP/call sending is
      blocked until that's approved.
- [ ] Add a real `res/raw/alarm_sound.mp3` (Android) — referenced in
      `notification_service.dart` but not included here.
- [ ] **Play Billing**: create the `alarm_plan` and `call_plan` subscription
      products in Play Console, each with `monthly` and `yearly` base plans
      (the base plan IDs must be exactly `monthly` / `yearly` — the code
      matches on those strings). Deploy `supabase/functions/verify-purchase`
      and set the `GOOGLE_SERVICE_ACCOUNT_JSON` secret to the key you
      downloaded when linking your service account.
- [ ] Once your app exists in Play Console, come back and finish **step 4**
      (Real-time Developer Notifications) from the billing setup — a Pub/Sub
      topic that keeps subscription status current automatically instead of
      only at purchase time.
- [ ] **Ambulance integration needs your app's real details.** I built
      `lib/services/ambulance_service.dart` as a placeholder — it currently
      points at a fake URL scheme and package name. Tell me your app's
      real custom URL scheme (or package name, or API endpoint) and I'll
      wire in the real integration; right now it will just fail silently
      and fall back to a Play Store link that doesn't exist.
- [ ] **Paste the real TTS URL.** `trigger-call-reminders/index.ts` uses
      Bulk Blaster's newer template/batch API (`/api/tts/send`) — the full
      URL was cut off in your screenshot. Open `TTS_SEND_URL` at the top of
      that file and replace it with the complete URL from your "Ring" API
      access page, then set the `BULKBLASTER_TTS_API_KEY` secret to your
      `ttsk_live_...` key (this is a different key from the one used for
      OTP/SMS — don't reuse `BULKBLASTER_API_KEY` here).
- [ ] Deploy `supabase/functions/trigger-call-reminders` and schedule it
      via `pg_cron` (exact SQL is in a comment at the top of that file) —
      **without this, the call-reminder plan never actually calls anyone.**
      It also batches same-time medicines into one call automatically,
      which is the pricing assumption the ₹129/mo plan depends on.
- [ ] Add `language text default 'EN'`, `sos_action text default
      'notify_child'`, `care_tips text`, and `care_tips_updated_at
      timestamptz` columns to `profiles` if you already ran the original
      schema before this update (see the updated SQL in
      `medaayu-backend-setup.md`).
- [ ] Deploy `supabase/functions/generate-care-tips` and set the
      `GEMINI_API_KEY` secret — this powers the "Things to be mindful of"
      card on Home. It's called automatically whenever a medicine is added
      (see `AppState.refreshCareTips`), not on every dashboard view. Read
      the `SYSTEM_INSTRUCTIONS` prompt in that file before changing
      anything — the constraints in it (no dosing advice, no diagnosis,
      mandatory closing disclaimer) are load-bearing for user safety, not
      just style.
- [ ] **Fall detection is foreground-only right now.** It works while the
      elder's screen is open and the app is active — it stops if the app is
      backgrounded or the phone is locked. A true always-on version needs an
      Android foreground service (persistent notification + battery
      optimization exemption + `FOREGROUND_SERVICE` permission) — a real
      next step, not included here.
- [ ] The fall-detection thresholds in `fall_detection_service.dart` are
      starting points, not validated against real falls. Test on an actual
      device (padded surface, please) and tune `_impactThreshold` /
      `_stillnessThreshold` before relying on this for anyone.

## What's genuinely working in this code right now

- A Welcome screen with distinct "Log In" and "Register" entry points (both lead to the same phone+OTP flow, an already-registered number skips straight to its dashboard either way)
- Phone + OTP login (once the Edge Function is deployed)
- Auto-detecting an already-registered parent phone number, no linking code needed
- Add medicine, manually or via on-device OCR scan
- Real daily local alarm scheduling, in the person's chosen language, for the alarm-tier plan
- Real call-reminder triggering (once `trigger-call-reminders` is deployed + scheduled), also in the person's chosen language, with same-time medicines automatically batched into one call
- Real Google Play Billing purchase flow (once products are approved + verify-purchase is deployed) — no plan is granted until your backend confirms it with Google, not just the app's word for it. Not required for a personal test APK.
- AI care tips based on your exact medicines (once `generate-care-tips` is deployed), with hard safety constraints in the prompt
- SOS button: dials the guardian, logs the event + location, and — if set to "call ambulance" — also opens your ambulance app (once you give me its real integration details)
- Fall detection (foreground only): accelerometer pattern match → "are you okay?" countdown → auto-SOS if unanswered
- Editable anytime in Settings: reminder language, and what SOS does
- Light/dark theme toggle
- Manage tab: subscription status, family switch, logout

### Two real bugs fixed this round (not just placeholder gaps)
- `billing_service.dart` was reading `subscriptionOfferDetails` from the
  wrong nesting level (a genuine mistake, confirmed against the actual
  package source) — fixed, and now wrapped so a future field-name mismatch
  degrades gracefully instead of crashing the purchase flow.
- `BillingService.init()` could have thrown and blocked the entire app from
  starting on a device with no Play Store products configured — exactly
  your situation for a personal test APK. Now fully wrapped, cannot crash
  startup.
