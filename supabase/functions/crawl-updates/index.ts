import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { corsHeaders } from "../_shared/cors.ts";
import { createServiceClient } from "../_shared/supabase-client.ts";
import { fetchNarouNovels } from "../_shared/crawlers/narou.ts";
import { fetchHamelnNovel } from "../_shared/crawlers/hameln.ts";
import { fetchArcadiaNovel } from "../_shared/crawlers/arcadia.ts";

const MAX_NOVELS_PER_RUN = 50;

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
      .select("*")
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
    const targetNovels = novels.filter((n) => bookmarkedSet.has(n.id));

    // Group by site
    const narouNovels = targetNovels.filter((n) => n.site === "narou");
    const hamelnNovels = targetNovels.filter((n) => n.site === "hameln");
    const arcadiaNovels = targetNovels.filter((n) => n.site === "arcadia");

    let updatedCount = 0;

    // Process all sites in parallel
    const results = await Promise.allSettled([
      processNarou(client, narouNovels),
      processHameln(client, hamelnNovels),
      processArcadia(client, arcadiaNovels),
    ]);

    for (const result of results) {
      if (result.status === "fulfilled") {
        updatedCount += result.value;
      } else {
        console.error("Crawl batch error:", result.reason);
      }
    }

    const duration = Date.now() - startTime;

    return new Response(
      JSON.stringify({
        message: "Crawl completed",
        processed: targetNovels.length,
        updated: updatedCount,
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
async function processNarou(client: any, novels: any[]): Promise<number> {
  if (novels.length === 0) return 0;

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

    const hasUpdate = data.totalEpisodes > (novel.total_episodes ?? 0);

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
      await notifyUsers(client, novel, data.totalEpisodes);
      updatedCount++;
    }

    await logCrawl(client, novel, "success", hasUpdate ? data.totalEpisodes - (novel.total_episodes ?? 0) : 0, null, Date.now() - logStart);
  }

  return updatedCount;
}

// deno-lint-ignore no-explicit-any
async function processHameln(client: any, novels: any[]): Promise<number> {
  let updatedCount = 0;

  for (const novel of novels) {
    const logStart = Date.now();

    try {
      const data = await fetchHamelnNovel(novel.site_novel_id);

      if (!data) {
        await handleCrawlError(client, novel, "Failed to fetch/parse");
        continue;
      }

      const hasUpdate = data.totalEpisodes > (novel.total_episodes ?? 0);

      await client
        .from("novels")
        .update({
          title: data.title,
          author_name: data.author,
          total_episodes: data.totalEpisodes,
          latest_episode_id: data.latestEpisodeId,
          latest_episode_title: data.latestEpisodeTitle,
          last_crawled_at: new Date().toISOString(),
          crawl_error_count: 0,
          updated_at: new Date().toISOString(),
        })
        .eq("id", novel.id);

      if (hasUpdate) {
        await notifyUsers(client, novel, data.totalEpisodes);
        updatedCount++;
      }

      await logCrawl(client, novel, "success", hasUpdate ? data.totalEpisodes - (novel.total_episodes ?? 0) : 0, null, Date.now() - logStart);
    } catch (err) {
      await handleCrawlError(client, novel, String(err));
    }

    // Rate limit: 3 seconds between requests
    await new Promise((resolve) => setTimeout(resolve, 3000));
  }

  return updatedCount;
}

// deno-lint-ignore no-explicit-any
async function processArcadia(client: any, novels: any[]): Promise<number> {
  let updatedCount = 0;

  for (const novel of novels) {
    const logStart = Date.now();

    try {
      const data = await fetchArcadiaNovel(novel.site_novel_id);

      if (!data) {
        await handleCrawlError(client, novel, "Failed to fetch/parse");
        continue;
      }

      const hasUpdate = data.totalEpisodes > (novel.total_episodes ?? 0);

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
        await notifyUsers(client, novel, data.totalEpisodes);
        updatedCount++;
      }

      await logCrawl(client, novel, "success", hasUpdate ? data.totalEpisodes - (novel.total_episodes ?? 0) : 0, null, Date.now() - logStart);
    } catch (err) {
      await handleCrawlError(client, novel, String(err));
    }

    // Rate limit: 5 seconds between requests (Arcadia is fragile)
    await new Promise((resolve) => setTimeout(resolve, 5000));
  }

  return updatedCount;
}

// deno-lint-ignore no-explicit-any
async function notifyUsers(client: any, novel: any, newEpisodeCount: number) {
  // Get all users who bookmarked this novel
  const { data: bookmarks } = await client
    .from("bookmarks")
    .select("user_id")
    .eq("novel_id", novel.id);

  if (!bookmarks || bookmarks.length === 0) return;

  const notifications = bookmarks.map((b: { user_id: string }) => ({
    user_id: b.user_id,
    type: "new_episode",
    novel_id: novel.id,
    title: "小説の更新があります",
    body: `「${novel.title}」第${newEpisodeCount}話が公開されました`,
  }));

  await client.from("notifications").insert(notifications);
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
async function logCrawl(client: any, novel: any, status: string, episodesFound: number, errorMessage: string | null, durationMs: number) {
  await client.from("crawl_logs").insert({
    novel_id: novel.id,
    site: novel.site,
    status,
    episodes_found: episodesFound,
    error_message: errorMessage,
    duration_ms: durationMs,
  });
}
