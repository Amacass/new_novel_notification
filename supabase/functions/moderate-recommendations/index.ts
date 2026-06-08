import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { corsHeaders } from "../_shared/cors.ts";
import { createServiceClient } from "../_shared/supabase-client.ts";
import { GemmaModerationProvider } from "../_shared/moderation/gemma.ts";

// RPM 15 → 1リクエスト/4秒で安全に収まる
const RATE_LIMIT_MS = 4_000;
const BATCH_SIZE = 100;

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const apiKey = Deno.env.get("GEMMA_API_KEY");
  if (!apiKey) {
    return new Response("GEMMA_API_KEY not set", { status: 500 });
  }

  const client = createServiceClient();
  const provider = new GemmaModerationProvider(apiKey);

  const { data: pending, error } = await client
    .from("recommendations")
    .select("id, heading, body, novel_id, novels(title, synopsis)")
    .eq("moderation_status", "pending")
    .order("created_at")
    .limit(BATCH_SIZE);

  if (error) {
    console.error("fetch pending error:", error);
    return new Response(JSON.stringify({ error: error.message }), { status: 500 });
  }

  let approved = 0;
  let rejected = 0;
  let failed = 0;

  for (const rec of pending ?? []) {
    // deno-lint-ignore no-explicit-any
    const novel = (rec as any).novels as { title?: string; synopsis?: string } | null;

    try {
      const result = await provider.classify({
        heading: rec.heading,
        body: rec.body,
        novelTitle: novel?.title ?? "",
        synopsis: novel?.synopsis ?? "",
      });

      const updatePayload: Record<string, unknown> = {
        moderation_status: result.allow ? "approved" : "rejected",
        moderated_at: new Date().toISOString(),
      };
      if (!result.allow) updatePayload.moderation_reason = result.reason;

      await client.from("recommendations")
        .update(updatePayload)
        .eq("id", rec.id);

      // work_kind が推定できたら novels を補完（未設定の場合のみ）
      if (result.workKind && novel) {
        await client.from("novels")
          .update({ work_kind: result.workKind })
          .eq("id", rec.novel_id)
          .is("work_kind", null);
      }

      result.allow ? approved++ : rejected++;
    } catch (err) {
      console.error(`moderation failed for rec ${rec.id}:`, err);
      failed++;
    }

    // レート制限: RPM 15 対応
    await new Promise((resolve) => setTimeout(resolve, RATE_LIMIT_MS));
  }

  const summary = { processed: (pending ?? []).length, approved, rejected, failed };
  console.log("moderation summary:", summary);

  return new Response(JSON.stringify(summary), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
});
