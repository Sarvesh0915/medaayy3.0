// Deploy with: supabase functions deploy notify-sos --no-verify-jwt
// Set secret: supabase secrets set BULKBLASTER_API_KEY=xxx
//
// SMS is used ONLY here, for the emergency path — never for routine
// medicine reminders (those are the on-device alarm or the TTS call).
// It exists as a backup channel: if the guardian doesn't pick up the
// call SOS already places, a text with a location link still gets
// through, and SMS delivery doesn't depend on someone answering live.

import { serve } from "https://deno.land/std@0.203.0/http/server.ts";

const BULKBLASTER_KEY = Deno.env.get("BULKBLASTER_API_KEY")!;

serve(async (req) => {
  const { guardianPhone, elderName, lat, lng } = await req.json();

  if (!guardianPhone) {
    return Response.json({ success: false, error: "guardianPhone is required" }, { status: 400 });
  }

  const locationPart =
    lat != null && lng != null ? ` Location: https://maps.google.com/?q=${lat},${lng}` : "";
  const message =
    `EMERGENCY: ${elderName || "Your family member"} pressed the SOS button on MedAayu ` +
    `and may need help.${locationPart}`.slice(0, 160); // Bulk Blaster's stated SMS limit

  const res = await fetch(
    "https://bulkblaster-india-sms-lc-290441563653.asia-south1.run.app/send-sms",
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        apiKey: BULKBLASTER_KEY,
        phone: guardianPhone,
        message,
      }),
    },
  );

  const data = await res.json();
  return Response.json({ success: data.success ?? false });
});
