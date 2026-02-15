import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { corsHeaders } from "../_shared/cors.ts";
import { createServiceClient } from "../_shared/supabase-client.ts";
import { fetchNarouNovelsByAuthor } from "../_shared/crawlers/narou.ts";

/**
 * お気に入り作者の新作チェック
 * pg_cronで12時間ごとに実行
 */
serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const startTime = Date.now();

  try {
    const client = createServiceClient();

    // Get all favorite authors with their associated site info
    const { data: favoriteAuthors, error } = await client
      .from("favorite_authors")
      .select("*, authors(*)")
      .not("authors", "is", null);

    if (error) throw error;
    if (!favoriteAuthors || favoriteAuthors.length === 0) {
      return new Response(
        JSON.stringify({ message: "No favorite authors to check", processed: 0 }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // Group by author to avoid duplicate checks
    // deno-lint-ignore no-explicit-any
    const authorMap = new Map<number, any>();
    for (const fa of favoriteAuthors) {
      if (!authorMap.has(fa.author_id)) {
        authorMap.set(fa.author_id, {
          author: fa.authors,
          userIds: [fa.user_id],
        });
      } else {
        authorMap.get(fa.author_id)!.userIds.push(fa.user_id);
      }
    }

    let newNovelsFound = 0;

    for (const [, { author, userIds }] of authorMap) {
      try {
        // Currently only narou supports author-based search
        if (author.site !== "narou") continue;

        const novels = await fetchNarouNovelsByAuthor(author.site_author_id);
        if (!novels || novels.length === 0) continue;

        // Check which novels are already registered
        const siteNovelIds = novels.map((n: { ncode: string }) => n.ncode.toLowerCase());
        const { data: existingNovels } = await client
          .from("novels")
          .select("site_novel_id")
          .eq("site", "narou")
          .in("site_novel_id", siteNovelIds);

        const existingSet = new Set(
          existingNovels?.map((n) => n.site_novel_id) ?? [],
        );

        // Find new novels
        const newNovels = novels.filter(
          (n: { ncode: string }) => !existingSet.has(n.ncode.toLowerCase()),
        );

        for (const novel of newNovels) {
          // Register the new novel
          const { data: insertedNovel } = await client
            .from("novels")
            .insert({
              site: "narou",
              site_novel_id: novel.ncode.toLowerCase(),
              url: `https://ncode.syosetu.com/${novel.ncode.toLowerCase()}/`,
              title: novel.title,
              author_name: novel.writer,
              total_episodes: novel.general_all_no ?? 0,
              last_crawled_at: new Date().toISOString(),
            })
            .select()
            .single();

          if (!insertedNovel) continue;

          // Notify all users who follow this author
          const notifications = userIds.map((userId: string) => ({
            user_id: userId,
            type: "new_novel_by_author",
            novel_id: insertedNovel.id,
            title: "お気に入り作者の新作",
            body: `${author.name}さんの新作「${novel.title}」が公開されました`,
          }));

          await client.from("notifications").insert(notifications);
          newNovelsFound++;
        }

        // Rate limit between authors
        await new Promise((resolve) => setTimeout(resolve, 2000));
      } catch (err) {
        console.error(`Error checking author ${author.name}: ${err}`);
      }
    }

    const duration = Date.now() - startTime;

    return new Response(
      JSON.stringify({
        message: "Author check completed",
        authors_checked: authorMap.size,
        new_novels_found: newNovelsFound,
        duration_ms: duration,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err) {
    console.error("check-new-novels error:", err);
    return new Response(
      JSON.stringify({ error: "internal_error", message: String(err) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
