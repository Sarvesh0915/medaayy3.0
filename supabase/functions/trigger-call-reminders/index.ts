// Deploy with: supabase functions deploy trigger-call-reminders
// Set secret: supabase secrets set BULKBLASTER_TTS_API_KEY=xxx
//   (this is the "ttsk_live_..." key from Bulk Blaster's "Ring" API access
//   page — a DIFFERENT key from BULKBLASTER_API_KEY used for OTP/SMS,
//   don't mix them up)
//
// This is the piece that makes the ₹129/mo "call reminder" plan actually
// DO anything — without a scheduled job like this, medicines on the call
// plan just sit there with nothing ever triggering Bulk Blaster.
//
// TODO: paste the FULL endpoint URL from your Bulk Blaster dashboard below —
// the one in your screenshot was cut off ("https://tts-api-4-bussinesse-290...
// run.app/api/tts/send"). This placeholder will fail until you fix it.
const TTS_SEND_URL = "https://tts-api-4-bussinesse-290441563653.PASTE-YOUR-REGION.run.app/api/tts/send";
//                                                            ^^^^^^^^^^^^^^^^^^^^ confirm this part
//
// Schedule it to run every minute via Supabase's pg_cron:
//   select cron.schedule(
//     'trigger-call-reminders-every-minute',
//     '* * * * *',
//     $$
//     select net.http_post(
//       url := 'https://ptqsrehgftghnuhduqao.supabase.co/functions/v1/trigger-call-reminders',
//       headers := '{"Authorization": "Bearer YOUR_SERVICE_ROLE_KEY"}'::jsonb
//     );
//     $$
//   );

import { serve } from "https://deno.land/std@0.203.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = "https://ptqsrehgftghnuhduqao.supabase.co";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const TTS_API_KEY = Deno.env.get("BULKBLASTER_TTS_API_KEY")!;

const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

// {{double curly}} placeholders match the new API's template syntax.
// Keep in sync with lib/services/localization_service.dart.
const CALL_TEMPLATES: Record<string, string> = {
  EN: "Hello {{name}}. It is time to take your {{medicine}}.",
  HI: "नमस्ते {{name}}. आपकी {{medicine}} लेने का समय हो गया है।",
  TE: "హలో {{name}}. మీ {{medicine}} తీసుకోవాల్సిన సమయం అయింది.",
  TA: "வணக்கம் {{name}}. உங்கள் {{medicine}} எடுக்க வேண்டிய நேரம் இது.",
  KN: "ಹಲೋ {{name}}. ನಿಮ್ಮ {{medicine}} ತೆಗೆದುಕೊಳ್ಳುವ ಸಮಯ ಇದು.",
  ML: "ഹലോ {{name}}. നിങ്ങളുടെ {{medicine}} കഴിക്കേണ്ട സമയമായി.",
  BN: "নমস্কার {{name}}. আপনার {{medicine}} খাওয়ার সময় হয়েছে।",
  GU: "નમસ્તે {{name}}. તમારી {{medicine}} લેવાનો સમય થયો છે.",
  MR: "नमस्कार {{name}}. तुमची {{medicine}} घेण्याची वेळ झाली आहे.",
  PA: "ਸਤ ਸ੍ਰੀ ਅਕਾਲ {{name}}. ਤੁਹਾਡੀ {{medicine}} ਲੈਣ ਦਾ ਸਮਾਂ ਹੋ ਗਿਆ ਹੈ।",
};

serve(async () => {
  const now = new Date();
  const hh = String(now.getHours()).padStart(2, "0");
  const mm = String(now.getMinutes()).padStart(2, "0");
  const currentTime = `${hh}:${mm}:00`;

  // Step 1 — batching: group by profile so two medicines due at the same
  // moment for the same person become ONE reminder, not two. This is the
  // optimization the ₹129/mo pricing math depends on.
  const { data: dueMeds, error } = await admin
    .from("medicines")
    .select("id, name, dose_time, profile_id, profiles!inner(id, full_name, phone, language, plan_type:subscriptions(plan_type))")
    .eq("dose_time", currentTime);

  if (error) {
    console.error(error);
    return new Response("error", { status: 500 });
  }

  const byProfile = new Map<string, { profile: any; medicines: string[] }>();
  for (const med of dueMeds ?? []) {
    const profile = (med as any).profiles;
    // Only call-plan profiles get calls — alarm-plan medicines are handled
    // entirely on-device and should never reach this function's cost.
    const isCallPlan = profile?.plan_type?.some((p: any) => p.plan_type === "call");
    if (!isCallPlan || !profile?.phone) continue;

    if (!byProfile.has(profile.id)) byProfile.set(profile.id, { profile, medicines: [] });
    byProfile.get(profile.id)!.medicines.push(med.name);
  }

  // Step 2 — the new API's `language` field is per-REQUEST, not per
  // recipient, so group profiles by language and send one batched request
  // per language instead of one request per person.
  const byLanguage = new Map<string, { phone: string; variables: Record<string, string> }[]>();
  for (const { profile, medicines } of byProfile.values()) {
    const lang = profile.language ?? "EN";
    if (!byLanguage.has(lang)) byLanguage.set(lang, []);
    byLanguage.get(lang)!.push({
      phone: profile.phone,
      variables: { name: profile.full_name, medicine: medicines.join(medicines.length > 1 ? " and " : "") },
    });
  }

  const results = [];
  for (const [lang, recipients] of byLanguage.entries()) {
    const templateText = CALL_TEMPLATES[lang] ?? CALL_TEMPLATES.EN;

    const res = await fetch(TTS_SEND_URL, {
      method: "POST",
      headers: { "Content-Type": "application/json", "X-API-Key": TTS_API_KEY },
      body: JSON.stringify({ templateText, recipients, language: lang }),
    });

    results.push({ language: lang, recipientCount: recipients.length, ok: res.ok, status: res.status });
  }

  return Response.json({ triggered: results.length, results });
});
