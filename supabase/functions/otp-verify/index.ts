// Deploy with: supabase functions deploy otp-verify
// Set secrets with:
//   supabase secrets set BULKBLASTER_API_KEY=xxx
//   supabase secrets set SUPABASE_SERVICE_ROLE_KEY=xxx
//
// This is the ONLY place the Bulk Blaster key and the Supabase service role
// key should ever exist. Never put either of them in the Flutter app.

import { serve } from "https://deno.land/std@0.203.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = "https://ptqsrehgftghnuhduqao.supabase.co";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const BULKBLASTER_KEY = Deno.env.get("BULKBLASTER_API_KEY")!;

const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

// In-memory OTP store is fine for a single Edge Function instance during
// early development; move this to a `otp_codes` table (with an expiry
// column) before real launch so it survives cold starts and scales.
const otpStore = new Map<string, string>();

serve(async (req) => {
  const { pathname } = new URL(req.url);
  const body = await req.json();

  if (pathname.endsWith("/send-otp")) {
    const { phone } = body;
    const code = Math.floor(100000 + Math.random() * 900000).toString();
    otpStore.set(phone, code);

    const res = await fetch(
      "https://bulkblaster-biotp-api-290441563653.asia-south1.run.app/send-otp",
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          apiKey: BULKBLASTER_KEY,
          phone,
          otp: code,
          senderType: "DASSAM",
        }),
      },
    );
    const data = await res.json();
    return Response.json({ success: data.success ?? false });
  }

  if (pathname.endsWith("/verify-otp")) {
    const { phone, otp } = body;
    const expected = otpStore.get(phone);
    if (!expected || expected !== otp) {
      return Response.json({ success: false, error: "Invalid code" }, { status: 401 });
    }
    otpStore.delete(phone);

    // Find or create the Supabase auth user for this phone.
    const fakeEmail = `${phone}@medaayu.phone`; // Supabase auth needs an identifier; phone-as-email is a common workaround when not using their native phone provider
    let { data: existing } = await admin.auth.admin.listUsers();
    let user = existing.users.find((u) => u.email === fakeEmail);

    if (!user) {
      const { data: created, error } = await admin.auth.admin.createUser({
        email: fakeEmail,
        email_confirm: true,
        user_metadata: { phone },
      });
      if (error) return Response.json({ success: false, error: error.message }, { status: 500 });
      user = created.user;
    }

    const { data: session, error: sessionError } = await admin.auth.admin.generateLink({
      type: "magiclink",
      email: fakeEmail,
    });
    if (sessionError) {
      return Response.json({ success: false, error: sessionError.message }, { status: 500 });
    }

    // generateLink gives a redirect URL containing the tokens — extract them.
    const hashParams = new URL(session.properties.action_link).searchParams;
    return Response.json({
      success: true,
      access_token: hashParams.get("access_token"),
      refresh_token: hashParams.get("refresh_token"),
      user_id: user.id,
    });
  }

  return new Response("Not found", { status: 404 });
});

/*
BONUS — SOS -> push notification trigger (separate function, `notify-sos`):

Add a Postgres trigger on `sos_events` (via Supabase Dashboard -> Database ->
Webhooks) that calls a second Edge Function on INSERT. That function should:
  1. Look up the FCM device token for the owning child's account
     (store it in a `device_tokens` table when the app registers for
     notifications via firebase_messaging).
  2. POST to https://fcm.googleapis.com/v1/projects/medaayu/messages:send
     with a Firebase service account credential (NOT the API key from
     google-services.json — that only works client-side).
This is what makes the child's phone light up immediately when SOS is
pressed, rather than relying on them noticing a missed call.
*/
