// Deploy with: supabase functions deploy verify-purchase
// Set secrets with:
//   supabase secrets set GOOGLE_SERVICE_ACCOUNT_JSON='<paste the full JSON key you downloaded>'
//   supabase secrets set SUPABASE_SERVICE_ROLE_KEY=xxx
//
// This is the server-side check that a purchase reported by the app is
// real and currently active — never trust the app's own "purchase
// succeeded" signal for granting access to the call-reminder tier.

import { serve } from "https://deno.land/std@0.203.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { GoogleAuth } from "https://esm.sh/google-auth-library@9";

const SUPABASE_URL = "https://ptqsrehgftghnuhduqao.supabase.co";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const GOOGLE_SA_JSON = JSON.parse(Deno.env.get("GOOGLE_SERVICE_ACCOUNT_JSON")!);
const PACKAGE_NAME = "medaayu.com";

const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

async function getAccessToken(): Promise<string> {
  const auth = new GoogleAuth({
    credentials: GOOGLE_SA_JSON,
    scopes: ["https://www.googleapis.com/auth/androidpublisher"],
  });
  const client = await auth.getClient();
  const token = await client.getAccessToken();
  return token.token as string;
}

serve(async (req) => {
  const { productId, purchaseToken } = await req.json();

  const accessToken = await getAccessToken();
  const url =
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/` +
    `${PACKAGE_NAME}/purchases/subscriptions/${productId}/tokens/${purchaseToken}`;

  const res = await fetch(url, {
    headers: { Authorization: `Bearer ${accessToken}` },
  });

  if (!res.ok) {
    return Response.json({ valid: false, error: `Publisher API returned ${res.status}` }, { status: 200 });
  }

  const data = await res.json();
  // paymentState: 0 = pending, 1 = received, 2 = free trial, 3 = deferred
  const valid = data.paymentState === 1 || data.paymentState === 2;

  if (valid) {
    // Record/refresh the active subscription in your own table so the rest
    // of the app can check entitlement without calling Google every time.
    await admin.from("subscriptions").upsert({
      purchase_token: purchaseToken,
      product_id: productId,
      status: "active",
      current_period_end: new Date(Number(data.expiryTimeMillis)).toISOString(),
    });
  }

  return Response.json({ valid });
});

/*
Wire up Real-time Developer Notifications (once your app exists in Console,
per step 4 you deferred) to call this same verification logic automatically
on renewal/cancellation/refund events, instead of only checking at purchase
time. Without RTDN, a cancelled subscription keeps working until something
else happens to re-check it.
*/
