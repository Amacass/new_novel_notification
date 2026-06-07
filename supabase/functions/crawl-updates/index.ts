import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { corsHeaders } from "../_shared/cors.ts";
import { createServiceClient } from "../_shared/supabase-client.ts";
import { fetchNarouNovels } from "../_shared/crawlers/narou.ts";
import { fetchHamelnNovel } from "../_shared/crawlers/hameln.ts";
import { fetchArcadiaNovel } from "../_shared/crawlers/arcadia.ts";
import { sendFcmNotifications } from "../_shared/fcm.ts";

const MAX_NOVELS_PER_RUN = 50;
const SKIP_WINDOW_MS = 18 * 60 * 60 * 1000; // 18時間

interface NovelUpdate {
  // deno-lint-ignore no-explicit-any
  novel: any;
  newTotal: number;
}

interface BatchItem {
  novel_id: number;
  title: string;
  new_total: number;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const startTime = Date.now();

  try {
    const client = createServiceClient();

    const { data: novels, error } = await client
      .from("novels")
      .select("*, last_shared_verified_at")
      .lt("crawl_error_count", 5)
      .order("last_crawled_at", { ascending: true, nullsFirst: true })
      .limit(MAX_NOVELS_PER_RUN);

    if (error) throw error;
    if (!novels || novels.length === 0) {
      return new Response(
        JSON.stringify({ message: "No novels to crawl", processed: 0 }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // ブックマークされている小説のみ対象
    const novelIds = novels.map((n) => n.id);
    const { data: bookmarkedNovelIds } = await client
      .from("bookmarks")
      .select("novel_id")
      .in("novel_id", novelIds);

    const bookmarkedSet = new Set(
      bookmarkedNovelIds?.map((b) => b.novel_id) ?? [],
    );

    // 最終確認（クロール or 共有）が18時間以内の小説はスキップ
    const targetNovels = novels.filter((n) => {
      if (!bookmarkedSet.has(n.id)) return false;
      const lastCrawled = n.last_crawled_at ? Date.parse(n.last_crawled_at) : 0;
      const lastShared = n.last_shared_verified_at
        ? Date.parse(n.last_shared_verified_at)
        : 0;
      return Math.max(lastCrawled, lastShared) < Date.now() - SKIP_WINDOW_MS;
    });

    const skippedCount =
      novels.filter((n) => bookmarkedSet.has(n.id)).length - targetNovels.length;

    const narouNovels = targetNovels.filter((n) => n.site === "narou");
    const hamelnNovels = targetNovels.filter((n) => n.site === "hameln");
    const arcadiaNovels = targetNovels.filter((n) => n.site === "arcadia");

    // 全サイトを並列処理 — この時点では通知しない
    const results = await Promise.allSettled([
      processNarou(client, narouNovels),
      processHameln(client, hamelnNovels),
      processArcadia(client, arcadiaNovels),
    ]);

    const allUpdates: NovelUpdate[] = [];
    let updatedCount = 0;

    for (const result of results) {
      if (result.status === "fulfilled") {
        updatedCount += result.value.count;
        allUpdates.push(...result.value.updates);
      } else {
        console.error("Crawl batch error:", result.reason);
      }
    }

    // 全クロール完了後に一括通知
    const notifiedUserCount = await notifyBatch(client, allUpdates);

    const duration = Date.now() - startTime;

    return new Response(
      JSON.stringify({
        message: "Crawl completed",
        processed: targetNovels.length,
        skipped: skippedCount,
        updated: updatedCount,
        notified_users: notifiedUserCount,
        duration_ms: duration,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err) {
    console.error("crawl-updates error:", err);
    return new Response(
      JSON.stringify({ error: "internal_error", message: String(err) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});

// deno-lint-ignore no-explicit-any
async function processNarou(client: any, novels: any[]): Promise<{ count: number; updates: NovelUpdate[] }> {
  if (novels.length === 0) return { count: 0, updates: [] };

  const updates: NovelUpdate[] = [];
  let updatedCount = 0;
  const ncodes = novels.map((n) => n.site_novel_id);
  const narouData = await fetchNarouNovels(ncodes);

  for (const novel of novels) {
    const data = narouData.get(novel.site_novel_id);
    const logStart = Date.now();

    if (!data) {
      await handleCrawlError(client, novel, "No data returned from API");
      continue;
    }

    const oldTotal = novel.total_episodes ?? 0;
    const hasUpdate = data.totalEpisodes > oldTotal;

    await client
      .from("novels")
      .update({
        title: data.title,
        author_name: data.writer,
        total_episodes: data.totalEpisodes,
        site_updated_at: data.lastUpdated,
        last_crawled_at: new Date().toISOString(),
        crawl_error_count: 0,
        updated_at: new Date().toISOString(),
      })
      .eq("id", novel.id);

    if (hasUpdate) {
      const newEpisodes = [];
      for (let i = oldTotal + 1; i <= data.totalEpisodes; i++) {
        newEpisodes.push({
          novel_id: novel.id,
          site_episode_id: String(i),
          episode_number: i,
        });
      }
      if (newEpisodes.length > 0) {
        await client
          .from("episodes")
          .upsert(newEpisodes, { onConflict: "novel_id,site_episode_id" });
      }

      updates.push({ novel: { ...novel, title: data.title }, newTotal: data.totalEpisodes });
      updatedCount++;
    }

    await logCrawl(
      client, novel, "success",
      hasUpdate ? data.totalEpisodes - oldTotal : 0,
      null, Date.now() - logStart,
    );
  }

  return { count: updatedCount, updates };
}

// deno-lint-ignore no-explicit-any
async function processHameln(client: any, novels: any[]): Promise<{ count: number; updates: NovelUpdate[] }> {
  const updates: NovelUpdate[] = [];
  let updatedCount = 0;

  for (const novel of novels) {
    const logStart = Date.now();

    try {
      const data = await fetchHamelnNovel(novel.site_novel_id);

      if (!data) {
        await handleCrawlError(client, novel, "Failed to fetch/parse");
        continue;
      }

      const oldTotal = novel.total_episodes ?? 0;
      const hasUpdate = data.totalEpisodes > oldTotal;

      await client
        .from("novels")
        .update({
          title: data.title,
          author_name: data.author,
          total_episodes: data.totalEpisodes,
          latest_episode_id: data.latestEpisodeId,
          latest_episode_title: data.latestEpisodeTitle,
          site_updated_at: data.latestUpdatedAt,
          last_crawled_at: new Date().toISOString(),
          crawl_error_count: 0,
          updated_at: new Date().toISOString(),
        })
        .eq("id", novel.id);

      if (hasUpdate) {
        const episodeRecords = data.episodes.map((ep) => ({
          novel_id: novel.id,
          site_episode_id: ep.siteEpisodeId,
          episode_number: ep.episodeNumber,
          title: ep.title ?? null,
        }));
        if (episodeRecords.length > 0) {
          await client
            .from("episodes")
            .upsert(episodeRecords, { onConflict: "novel_id,site_episode_id" });
        }

        updates.push({ novel: { ...novel, title: data.title }, newTotal: data.totalEpisodes });
        updatedCount++;
      }

      await logCrawl(
        client, novel, "success",
        hasUpdate ? data.totalEpisodes - oldTotal : 0,
        null, Date.now() - logStart,
      );
    } catch (err) {
      await handleCrawlError(client, novel, String(err));
    }

    await new Promise((resolve) => setTimeout(resolve, 3000));
  }

  return { count: updatedCount, updates };
}

// deno-lint-ignore no-explicit-any
async function processArcadia(client: any, novels: any[]): Promise<{ count: number; updates: NovelUpdate[] }> {
  const cutoff = new Date(Date.now() - 24 * 60 * 60 * 1000);
  const novelsToCrawl = novels.filter(
    (n) => !n.last_crawled_at || new Date(n.last_crawled_at) < cutoff,
  );

  if (novelsToCrawl.length === 0) return { count: 0, updates: [] };

  const updates: NovelUpdate[] = [];
  let updatedCount = 0;

  for (const novel of novelsToCrawl) {
    const logStart = Date.now();

    try {
      const data = await fetchArcadiaNovel(novel.site_novel_id);

      if (!data) {
        await handleCrawlError(client, novel, "Failed to fetch/parse");
        continue;
      }

      const oldTotal = novel.total_episodes ?? 0;
      const hasUpdate = data.totalEpisodes > oldTotal;

      await client
        .from("novels")
        .update({
          title: data.title,
          author_name: data.author,
          total_episodes: data.totalEpisodes,
          latest_episode_id: data.latestEpisodeId,
          last_crawled_at: new Date().toISOString(),
          crawl_error_count: 0,
          updated_at: new Date().toISOString(),
        })
        .eq("id", novel.id);

      if (hasUpdate) {
        const episodeRecords = data.episodes.map((ep) => ({
          novel_id: novel.id,
          site_episode_id: ep.siteEpisodeId,
          episode_number: ep.episodeNumber,
          title: ep.title ?? null,
        }));
        if (episodeRecords.length > 0) {
          await client
            .from("episodes")
            .upsert(episodeRecords, { onConflict: "novel_id,site_episode_id" });
        }

        updates.push({ novel: { ...novel, title: data.title }, newTotal: data.totalEpisodes });
        updatedCount++;
      }

      await logCrawl(
        client, novel, "success",
        hasUpdate ? data.totalEpisodes - oldTotal : 0,
        null, Date.now() - logStart,
      );
    } catch (err) {
      await handleCrawlError(client, novel, String(err));
    }

    await new Promise((resolve) => setTimeout(resolve, 5000));
  }

  return { count: updatedCount, updates };
}

/**
 * 全クロール完了後に呼ぶ一括通知。
 * ユーザーごとに「○件の小説が更新されました」を1通だけ送る。
 */
// deno-lint-ignore no-explicit-any
async function notifyBatch(client: any, updates: NovelUpdate[]): Promise<number> {
  if (updates.length === 0) return 0;

  const novelIds = updates.map((u) => u.novel.id);

  const { data: bookmarks } = await client
    .from("bookmarks")
    .select("user_id, novel_id")
    .in("novel_id", novelIds);

  if (!bookmarks || bookmarks.length === 0) return 0;

  // novel_id → NovelUpdate のマップ
  const updateMap = new Map<number, NovelUpdate>();
  for (const u of updates) updateMap.set(u.novel.id, u);

  // ユーザーごとに関係する更新をグループ化
  const userMap = new Map<string, BatchItem[]>();
  for (const bm of bookmarks) {
    const u = updateMap.get(bm.novel_id);
    if (!u) continue;
    if (!userMap.has(bm.user_id)) userMap.set(bm.user_id, []);
    userMap.get(bm.user_id)!.push({
      novel_id: u.novel.id,
      title: u.novel.title,
      new_total: u.newTotal,
    });
  }

  if (userMap.size === 0) return 0;

  // ユーザーごとに1通の crawl_batch 通知を作成
  const notifications = [];
  for (const [userId, items] of userMap) {
    const count = items.length;
    const title = count === 1
      ? "小説の更新があります"
      : `${count}件の小説が更新されました`;
    const body = count === 1
      ? `「${items[0].title}」第${items[0].new_total}話が公開されました`
      : items.slice(0, 3).map((i) => `「${i.title}」`).join("、") +
        (count > 3 ? ` 他${count - 3}件` : "") + " が更新されました";

    notifications.push({
      user_id: userId,
      type: "crawl_batch",
      // 単体の場合は novel_id をセットしておく（詳細画面へのショートカット）
      novel_id: count === 1 ? items[0].novel_id : null,
      title,
      body,
      metadata: items,
    });
  }

  await client.from("notifications").insert(notifications);

  // FCM は各ユーザーへ個別送信
  for (const notif of notifications) {
    await sendFcmNotifications(
      client,
      [notif.user_id],
      { title: notif.title, body: notif.body },
      { type: "crawl_batch", count: String(notif.metadata.length) },
    );
  }

  return userMap.size;
}

// deno-lint-ignore no-explicit-any
async function handleCrawlError(client: any, novel: any, errorMsg: string) {
  console.error(`Crawl error for ${novel.site}/${novel.site_novel_id}: ${errorMsg}`);

  await client
    .from("novels")
    .update({
      crawl_error_count: (novel.crawl_error_count ?? 0) + 1,
      last_crawled_at: new Date().toISOString(),
    })
    .eq("id", novel.id);

  await logCrawl(client, novel, "error", 0, errorMsg, 0);
}

// deno-lint-ignore no-explicit-any
async function logCrawl(
  client: any, novel: any, status: string,
  episodesFound: number, errorMessage: string | null, durationMs: number,
) {
  await client.from("crawl_logs").insert({
    novel_id: novel.id,
    site: novel.site,
    status,
    episodes_found: episodesFound,
    error_message: errorMessage,
    duration_ms: durationMs,
  });
}
