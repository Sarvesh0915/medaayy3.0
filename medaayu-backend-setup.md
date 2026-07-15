# MedAayu — Backend Setup Reference

Stack: **Supabase** (DB + storage) · **Firebase** (FCM + Crashlytics only, not Auth) · **Bulk Blaster** (OTP + TTS calls) · **ML Kit** (on-device OCR)

---

## 1. The auth pattern (important — read this first)

You're using Bulk Blaster for OTP instead of Supabase's own phone auth. That's fine, but
Supabase's Row Level Security relies on `auth.uid()` — which only exists if the request
carries a real Supabase session. So the flow needs to be:

1. App calls **your backend** with the phone number → your backend calls Bulk Blaster `/send-otp`.
2. User enters the OTP → app sends it to **your backend** (not Supabase, not Bulk Blaster
   directly) → your backend verifies it against what it sent.
3. On success, your backend uses the **Supabase service role key** (server-side only, never
   in the app) to call `supabase.auth.admin.createUser()` (first time) or look up the
   existing user by phone, then issues a session for that user
   (`generateLink` / admin session creation) and returns the Supabase access token to the app.
4. The Flutter app stores that token and uses it for all further Supabase calls — now
   `auth.uid()` works and RLS applies normally.

This means you need a small backend function (Supabase Edge Function or a tiny Node service)
sitting between the app and both Bulk Blaster + Supabase admin calls. The service role key
must **only** ever live there — never in the Flutter app.

---

## 2. Database schema

```sql
-- One row per person being tracked — either the account owner ("self") or a parent they added.
create table profiles (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid references auth.users(id), -- null for a parent who hasn't logged in themselves yet
  owner_id uuid references profiles(id),        -- the account that manages this profile (self-reference for "self")
  role text check (role in ('self', 'parent')) not null,
  full_name text,
  age int,
  gender text,
  blood_group text,
  phone text unique,
  sos_contact_phone text,
  language text default 'EN', -- Bulk Blaster language code: EN, HI, TE, TA, KN, ML, BN, GU, MR, PA
  sos_action text default 'notify_child' check (sos_action in ('notify_child', 'ambulance')),
  care_tips text, -- AI-generated, cached — see generate-care-tips Edge Function
  care_tips_updated_at timestamptz,
  created_at timestamptz default now()
);

create table subscriptions (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid references profiles(id) not null,
  plan_type text check (plan_type in ('alarm', 'call')) not null,
  billing_cycle text check (billing_cycle in ('monthly', 'yearly')) not null,
  status text default 'active',
  current_period_end timestamptz,
  created_at timestamptz default now()
);

create table medicines (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid references profiles(id) not null,
  owner_id uuid references profiles(id) not null, -- denormalized for simple RLS checks
  name text not null,
  form text,
  frequency text,
  dose_time time,
  pills_left int,
  food_instruction text,
  created_at timestamptz default now()
);

create table dose_logs (
  id uuid primary key default gen_random_uuid(),
  medicine_id uuid references medicines(id) not null,
  owner_id uuid references profiles(id) not null,
  scheduled_at timestamptz not null,
  taken_at timestamptz,
  status text check (status in ('pending', 'taken', 'missed')) default 'pending'
);

create table appointments (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid references profiles(id) not null,
  owner_id uuid references profiles(id) not null,
  title text not null,
  when_text text,
  doctor text,
  created_at timestamptz default now()
);

create table diary_notes (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid references profiles(id) not null,
  owner_id uuid references profiles(id) not null,
  note text not null,
  created_at timestamptz default now()
);

create table health_contacts (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid references profiles(id) not null,
  owner_id uuid references profiles(id) not null,
  name text not null,
  phone text not null
);

create table health_trackers (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid references profiles(id) not null,
  owner_id uuid references profiles(id) not null,
  type text check (type in ('bp', 'sugar', 'weight')) not null,
  value text not null,
  recorded_at timestamptz default now()
);

create table sos_events (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid references profiles(id) not null,
  owner_id uuid references profiles(id) not null,
  triggered_at timestamptz default now(),
  location_lat double precision,
  location_lng double precision,
  status text default 'sent'
);
```

`owner_id` is repeated on every child table on purpose — it makes every RLS policy a
one-line check instead of a multi-table join, which matters for both performance and for not
getting the policy subtly wrong.

---

## 3. Row Level Security (non-negotiable before launch)

```sql
alter table profiles enable row level security;
alter table subscriptions enable row level security;
alter table medicines enable row level security;
alter table dose_logs enable row level security;
alter table appointments enable row level security;
alter table diary_notes enable row level security;
alter table health_contacts enable row level security;
alter table health_trackers enable row level security;
alter table sos_events enable row level security;

-- profiles: a user can see/manage their own profile + any parent profiles they own
create policy "own or managed profiles"
  on profiles for all
  using (auth_user_id = auth.uid() or owner_id in (
    select id from profiles where auth_user_id = auth.uid()
  ));

-- every child table follows the same simple pattern
create policy "owner access" on medicines for all
  using (owner_id in (select id from profiles where auth_user_id = auth.uid()));
create policy "owner access" on dose_logs for all
  using (owner_id in (select id from profiles where auth_user_id = auth.uid()));
create policy "owner access" on appointments for all
  using (owner_id in (select id from profiles where auth_user_id = auth.uid()));
create policy "owner access" on diary_notes for all
  using (owner_id in (select id from profiles where auth_user_id = auth.uid()));
create policy "owner access" on health_contacts for all
  using (owner_id in (select id from profiles where auth_user_id = auth.uid()));
create policy "owner access" on health_trackers for all
  using (owner_id in (select id from profiles where auth_user_id = auth.uid()));
create policy "owner access" on sos_events for all
  using (owner_id in (select id from profiles where auth_user_id = auth.uid()));
create policy "owner access" on subscriptions for all
  using (profile_id in (select id from profiles where owner_id in (
    select id from profiles where auth_user_id = auth.uid()
  )));
```

Test this by trying to read another account's data with a real (non-service-role) session —
if you can see it, a policy is wrong.

---

## 4. Flutter dependencies (`pubspec.yaml`)

```yaml
dependencies:
  supabase_flutter: ^2.5.0
  firebase_core: ^3.1.0
  firebase_messaging: ^15.0.0
  firebase_crashlytics: ^4.0.0
  google_mlkit_text_recognition: ^0.15.1
  flutter_local_notifications: ^17.2.0   # the on-device alarm layer
  android_alarm_manager_plus: ^4.0.0     # exact daily alarm scheduling on Android
  geolocator: ^12.0.0                    # SOS location
  permission_handler: ^11.3.0
  http: ^1.2.0
  intl: ^0.19.0
```

`google-services.json` goes in `android/app/`. Add it to `.gitignore` if this repo is ever
public — not because the key is secret, but because there's no reason to expose your
project structure/app IDs unnecessarily.

`main.dart` initialization order matters:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await Supabase.initialize(
    url: 'https://ptqsrehgftghnuhduqao.supabase.co',
    anonKey: 'sb_publishable_s0SNO_RB0eJZ7L8RHG4Lmw_8DuNl_cc',
  );
  runApp(const MedAayuApp());
}
```

---

## 5. OCR disclaimer (required on every scan result screen)

Since `google_mlkit_text_recognition` runs on-device with no human review, every prescription
scan result must show, non-dismissibly, before the user can save:

> "This was read automatically and may contain mistakes — please check every medicine name,
> dose, and timing against the original prescription before saving."

---

## 6. Still to configure in each console

- [ ] **Google Cloud Console** → restrict the Firebase API key to package `medaayu.com` + your release SHA-1
- [ ] **Supabase** → confirm RLS is *enabled* (not just policies written) on all 9 tables
- [ ] **Supabase** → set up the Edge Function for OTP verify + session issuance (section 1)
- [ ] **Bulk Blaster** → complete DLT sender registration before sending any real OTP/call
- [ ] **Play Console** → declare `SCHEDULE_EXACT_ALARM` usage + background location usage
- [ ] **Play Console** → Google Play Billing product IDs for the ₹99/₹149 plans
