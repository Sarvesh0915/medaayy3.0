// Deploy with: supabase functions deploy generate-care-tips
// Set secret: supabase secrets set GEMINI_API_KEY=xxx
//
// Generates general, medicine-aware "things to be mindful of" tips —
// deliberately NOT dosing advice, NOT a diagnosis, NOT a substitute for a
// doctor. Read the prompt below carefully before changing it: the framing
// is doing real safety work, not just tone.
//
// Called by the app whenever a medicine is added or removed (see
// SupabaseService.refreshCareTips), NOT on every dashboard load — this
// keeps Gemini calls proportional to actual changes, not page views.

import { serve } from "https://deno.land/std@0.203.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = "https://ptqsrehgftghnuhduqao.supabase.co";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY")!;
const GEMINI_URL =
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent";

const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

const SYSTEM_INSTRUCTIONS = `You write short, general-awareness notes for a medicine reminder app.
The reader may be an elderly person or their family member — plain language, no jargon.

STRICT RULES, do not break these:
- NEVER give a dosage, a dose change, or timing instruction — the app already handles timing.
- NEVER diagnose a condition or suggest what the medicines are "for" if that isn't explicitly given.
- NEVER tell the reader to stop, start, or adjust any medicine.
- ONLY include well-established, low-risk general information: common things
  to be mindful of (e.g. "some people feel drowsy after this — avoid driving
  if that happens to you", "take with food if it upsets your stomach"),
  well-known interactions worth knowing about (e.g. avoiding alcohol), and
  general lifestyle notes (e.g. sun sensitivity).
- If you are not confident a point is well-established and low-risk, leave it out.
- Every response must end with exactly this sentence, verbatim:
  "This is general information only — always follow your doctor's or pharmacist's specific instructions."
- Keep the whole response under 120 words. Plain text, no markdown, no headers.
- If the medicine list is empty or you don't recognize any of them, just return
  the closing sentence above and nothing else.`;

serve(async (req) => {
  const { medicineNames } = await req.json();

  if (!Array.isArray(medicineNames) || medicineNames.length === 0) {
    return Response.json({
      tips: "This is general information only — always follow your doctor's or pharmacist's specific instructions.",
    });
  }

  const prompt = `Medicines currently being taken: ${medicineNames.join(", ")}.\n\nWrite the note now, following every rule above.`;

  const res = await fetch(`${GEMINI_URL}?key=${GEMINI_API_KEY}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      systemInstruction: { parts: [{ text: SYSTEM_INSTRUCTIONS }] },
      contents: [{ parts: [{ text: prompt }] }],
      generationConfig: { temperature: 0.3, maxOutputTokens: 220 },
    }),
  });

  if (!res.ok) {
    console.error(await res.text());
    return Response.json({ tips: null, error: "Gemini request failed" }, { status: 502 });
  }

  const data = await res.json();
  const tips: string | undefined = data?.candidates?.[0]?.content?.parts?.[0]?.text?.trim();

  if (!tips) {
    return Response.json({ tips: null, error: "No content returned" }, { status: 502 });
  }

  return Response.json({ tips });
});
