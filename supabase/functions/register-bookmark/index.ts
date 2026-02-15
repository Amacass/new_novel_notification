import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { corsHeaders } from "../_shared/cors.ts";
import { createUserClient, createServiceClient } from "../_shared/supabase-client.ts";
import { parseNovelUrl } from "../_shared/novel-parser.ts";
import { fetchNarouNovel } from "../_shared/crawlers/narou.ts";
import { fetchHamelnNovel } from "../_shared/crawlers/hameln.ts";
import { fetchArcadiaNovel } from "../_shared/crawlers/arcadia.ts";

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "unauthorized" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const userClient = createUserClient(authHeader);
    const serviceClient = createServiceClient();

    const { data: { user } } = await userClient.auth.getUser();
    if (!user) {
      return new Response(
        JSON.stringify({ error: "unauthorized" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const { url } = await req.json();
    const parsed = parseNovelUrl(url);

    if (!parsed) {
      return new Response(
        JSON.stringify({ error: "unsupported_site", message: "このURLは対応していないサイトです" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // Check if novel already exists
    const { data: existingNovel } = await serviceClient
      .from("novels")
      .select()
      .eq("site", parsed.site)
      .eq("site_novel_id", parsed.siteNovelId)
      .maybeSingle();

    let novelId: number;

    if (existingNovel) {
      novelId = existingNovel.id;

      // Refresh metadata if last crawl was > 6 hours ago
      const lastCrawled = existingNovel.last_crawled_at
        ? new Date(existingNovel.last_crawled_at)
        : null;
      const sixHoursAgo = new Date(Date.now() - 6 * 60 * 60 * 1000);

      if (!lastCrawled || lastCrawled < sixHoursAgo) {
        await refreshNovelMetadata(serviceClient, existingNovel);
      }
    } else {
      // Fetch metadata and create novel
      const metadata = await fetchMetadata(parsed.site, parsed.siteNovelId);

      const { data: newNovel, error: insertError } = await serviceClient
        .from("novels")
        .insert({
          site: parsed.site,
          site_novel_id: parsed.siteNovelId,
          url: parsed.normalizedUrl,
          title: metadata?.title ?? "取得中...",
          author_name: metadata?.author ?? null,
          total_episodes: metadata?.totalEpisodes ?? 0,
          last_crawled_at: new Date().toISOString(),
        })
        .select()
        .single();

      if (insertError) throw insertError;
      novelId = newNovel.id;
    }

    // Check if bookmark already exists
    const { data: existingBookmark } = await serviceClient
      .from("bookmarks")
      .select()
      .eq("user_id", user.id)
      .eq("novel_id", novelId)
      .maybeSingle();

    if (existingBookmark) {
      return new Response(
        JSON.stringify({
          error: "already_bookmarked",
          message: "この小説は既にブックマークされています",
          bookmark_id: existingBookmark.id,
        }),
        { status: 409, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // Create bookmark
    const { data: bookmark, error: bookmarkError } = await serviceClient
      .from("bookmarks")
      .insert({
        user_id: user.id,
        novel_id: novelId,
      })
      .select("*, novels(*)")
      .single();

    if (bookmarkError) throw bookmarkError;

    return new Response(
      JSON.stringify({
        bookmark_id: bookmark.id,
        novel: bookmark.novels,
      }),
      { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err) {
    console.error("register-bookmark error:", err);
    return new Response(
      JSON.stringify({ error: "internal_error", message: String(err) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});

interface NovelMetadata {
  title: string;
  author: string;
  totalEpisodes: number;
}

async function fetchMetadata(
  site: string,
  siteNovelId: string,
): Promise<NovelMetadata | null> {
  switch (site) {
    case "narou": {
      const data = await fetchNarouNovel(siteNovelId);
      if (!data) return null;
      return { title: data.title, author: data.writer, totalEpisodes: data.totalEpisodes };
    }
    case "hameln": {
      const data = await fetchHamelnNovel(siteNovelId);
      if (!data) return null;
      return { title: data.title, author: data.author, totalEpisodes: data.totalEpisodes };
    }
    case "arcadia": {
      const data = await fetchArcadiaNovel(siteNovelId);
      if (!data) return null;
      return { title: data.title, author: data.author, totalEpisodes: data.totalEpisodes };
    }
    default:
      return null;
  }
}

// deno-lint-ignore no-explicit-any
async function refreshNovelMetadata(client: any, novel: any) {
  const metadata = await fetchMetadata(novel.site, novel.site_novel_id);
  if (!metadata) return;

  await client
    .from("novels")
    .update({
      title: metadata.title,
      author_name: metadata.author,
      total_episodes: metadata.totalEpisodes,
      last_crawled_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    })
    .eq("id", novel.id);
}
