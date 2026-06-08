import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { corsHeaders } from "../_shared/cors.ts";
import { createServiceClient } from "../_shared/supabase-client.ts";

const TOP_N = 200;

const PERIODS = [
  { key: "daily",   hours: 24 },
  { key: "weekly",  hours: 24 * 7 },
  { key: "monthly", hours: 24 * 30 },
] as const;

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const client = createServiceClient();
  const now = new Date();

  for (const period of PERIODS) {
    const since = new Date(now.getTime() - period.hours * 3_600_000).toISOString();

    // 期間内の recommendation ごとのいいね数を集計
    const { data: likes, error } = await client
      .from("recommendation_likes")
      .select("recommendation_id")
      .gte("created_at", since);

    if (error) {
      console.error(`likes fetch error (${period.key}):`, error);
      continue;
    }

    // 集計
    const counts = new Map<number, number>();
    for (const row of likes ?? []) {
      counts.set(row.recommendation_id, (counts.get(row.recommendation_id) ?? 0) + 1);
    }

    // approved & public のみ対象
    const recIds = [...counts.keys()];
    if (recIds.length === 0) {
      // 期間内いいねなし → スナップショットをクリア
      await client.from("recommendation_ranking_snapshots")
        .delete().eq("period", period.key);
      continue;
    }

    const { data: recs, error: recErr } = await client
      .from("recommendations")
      .select("id")
      .in("id", recIds)
      .eq("moderation_status", "approved")
      .eq("is_public", true);

    if (recErr) {
      console.error(`rec fetch error (${period.key}):`, recErr);
      continue;
    }

    const validIds = new Set((recs ?? []).map((r) => r.id));
    const ranked = [...counts.entries()]
      .filter(([id]) => validIds.has(id))
      .sort((a, b) => b[1] - a[1])
      .slice(0, TOP_N);

    const rows = ranked.map(([id, cnt], i) => ({
      period: period.key,
      rank: i + 1,
      recommendation_id: id,
      likes_in_period: cnt,
      computed_at: now.toISOString(),
    }));

    // スナップショットを入れ替え（upsert）
    await client.from("recommendation_ranking_snapshots")
      .delete().eq("period", period.key);

    if (rows.length > 0) {
      const { error: insErr } = await client
        .from("recommendation_ranking_snapshots").insert(rows);
      if (insErr) console.error(`snapshot insert error (${period.key}):`, insErr);
    }

    console.log(`ranking computed (${period.key}): ${rows.length} entries`);
  }

  return new Response(JSON.stringify({ ok: true }), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
});
