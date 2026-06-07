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

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const startTime = Date.now();

  try {
    const client = createServiceClient();

    // Get novels that need crawling (bookmarked by at least 1 user, error count < 5)
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

    // Filter to only novels that are actually bookmarked
    const novelIds = novels.map((n) => n.id);
    const { data: bookmarkedNovelIds } = await client
      .from("bookmarks")
      .select("novel_id")
      .in("novel_id", novelIds);

    const bookmarkedSet = new Set(
      bookmarkedNovelIds?.map((b) => b.novel_id) ?? [],
    );

    // Skip novels confirmed within the past 18 hours (crawl or share)
    const targetNovels = novels.filter((n) => {
      if (!bookmarkedSet.has(n.id)) return false;
      const lastCrawled = n.last_crawled_at ? Date.parse(n.last_crawled_at) : 0;
      const lastShared = n.last_shared_verified_at
        ? Date.parse(n.last_shared_verified_at)
        : 0;
      const lastConfirmed = Math.max(lastCrawled, lastShared);
      return lastConfirmed < Date.now() - SKIP_WINDOW_MS;
    });

    const skippedCount = novels.filter((n) => bookmarkedSet.has(n.id)).length -
      targetNovels.length;

    // Group by site
    const narouNovels = targetNovels.filter((n) => n.site === "narou");
    const hamelnNovels = targetNovels.filter((n) => n.site === "hameln");
    const arcadiaNovels = targetNovels.filter((n) => n.site === "arcadia");

    // Process all sites in parallel, collecting updates (no notifications yet)
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

    // Send all notifications after all crawls complete
    for (const { novel, newTotal } of allUpdates) {
      await notifyUsers(client, novel, newTotal);
    }

    const duration = Date.now() - startTime;

    return new Response(
      JSON.stringify({
        message: "Crawl completed",
        processed: targetNovels.length,
        skipped: skippedCount,
        updated: updatedCount,
        notified: allUpdates.length,
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
      client,
      novel,
      "success",
      hasUpdate ? data.totalEpisodes - oldTotal : 0,
      null,
      Date.now() - logStart,
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
        client,
        novel,
        "success",
        hasUpdate ? data.totalEpisodes - oldTotal : 0,
        null,
        Date.now() - logStart,
      );
    } catch (err) {
      await handleCrawlError(client, novel, String(err));
    }

    // Rate limit: 3 seconds between requests
    await new Promise((resolve) => setTimeout(resolve, 3000));
  }

  return { count: updatedCount, updates };
}

// deno-lint-ignore no-explicit-any
async function processArcadia(client: any, novels: any[]): Promise<{ count: number; updates: NovelUpdate[] }> {
  // Arcadia: crawl at most once per 24 hours (stricter than the 18h skip window)
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
        client,
        novel,
        "success",
        hasUpdate ? data.totalEpisodes - oldTotal : 0,
        null,
        Date.now() - logStart,
      );
    } catch (err) {
      await handleCrawlError(client, novel, String(err));
    }

    // Rate limit: 5 seconds between requests (Arcadia is fragile)
    await new Promise((resolve) => setTimeout(resolve, 5000));
  }

  return { count: updatedCount, updates };
}

// deno-lint-ignore no-explicit-any
async function notifyUsers(client: any, novel: any, newEpisodeCount: number) {
  const { data: bookmarks } = await client
    .from("bookmarks")
    .select("user_id")
    .eq("novel_id", novel.id);

  if (!bookmarks || bookmarks.length === 0) return;

  const userIds: string[] = bookmarks.map((b: { user_id: string }) => b.user_id);

  const notificationPayload = {
    title: "小説の更新があります",
    body: `「${novel.title}」第${newEpisodeCount}話が公開されました`,
  };

  // episode_milestone で重複送信防止（共有由来の通知とも衝突しない）
  const notifications = userIds.map((userId) => ({
    user_id: userId,
    type: "new_episode",
    novel_id: novel.id,
    episode_milestone: newEpisodeCount,
    ...notificationPayload,
  }));

  // ignoreDuplicates: true で uq_notifications_new_episode 違反を無視
  const { data: inserted } = await client
    .from("notifications")
    .upsert(notifications, {
      onConflict: "user_id,novel_id,episode_milestone",
      ignoreDuplicates: true,
    })
    .select("user_id");

  // FCM は実際に INSERT された分だけ送る（既に通知済みのユーザーには送らない）
  const notifiedUserIds: string[] = (inserted ?? []).map(
    (r: { user_id: string }) => r.user_id,
  );
  if (notifiedUserIds.length === 0) return;

  await sendFcmNotifications(client, notifiedUserIds, notificationPayload, {
    type: "new_episode",
    novel_id: String(novel.id),
  });
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
  client: any,
  novel: any,
  status: string,
  episodesFound: number,
  errorMessage: string | null,
  durationMs: number,
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
