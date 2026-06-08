export interface EpisodeInfo {
  siteEpisodeId: string;
  episodeNumber: number;
  title?: string;
}

export interface ArcadiaNovelData {
  title: string;
  author: string;
  totalEpisodes: number;
  latestEpisodeId: string;
  episodes: EpisodeInfo[];
}

/**
 * ArcadiaのBBSページをスクレイピングして小説メタデータを取得する
 * ※ HTTP only (SSL期限切れ)
 */
export async function fetchArcadiaNovel(
  siteNovelId: string,
): Promise<ArcadiaNovelData | null> {
  // siteNovelId format: "{cate}_{storyId}"
  const parts = siteNovelId.split("_");
  if (parts.length < 2) return null;

  const cate = parts[0];
  const storyId = parts.slice(1).join("_");
  const url =
    `http://www.mai-net.net/bbs/sst/sst.php?act=dump&cate=${cate}&all=${storyId}`;

  try {
    const response = await fetch(url, {
      headers: {
        "User-Agent":
          "NovelmarkApp/1.0 (Web Novel Update Checker)",
        Accept: "text/html",
      },
    });

    if (!response.ok) {
      console.error(
        `Arcadia fetch failed: ${response.status} for ${siteNovelId}`,
      );
      return null;
    }

    const html = await response.text();
    return parseArcadiaPage(html);
  } catch (err) {
    console.error(`Arcadia fetch error for ${siteNovelId}: ${err}`);
    return null;
  }
}

function parseArcadiaPage(html: string): ArcadiaNovelData | null {
  // Extract title from the first entry [0] in the episode table.
  // Row [0] is the index post. It may or may not have <b> wrapping, and
  // may have whitespace / <br> between the <td> and <a> tag.
  const firstEntryMatch = html.match(
    /\[0\]<\/td><td[^>]*>(?:<b>)?(?:\s|<br\s*\/?>)*<a[^>]+>(.+?)<\/a>/i,
  ) ?? html.match(
    // Fallback: no <a> tag – plain text content of the first <td> after [0]
    /\[0\]<\/td><td[^>]*>(?:<b>)?([^<\n]+)/,
  );
  const title = firstEntryMatch
    ? decodeHtmlEntities(firstEntryMatch[1]).trim()
    : "不明なタイトル";

  // Extract author from the Name field in the post body: "Name: すいか◆0ccb92c1 ID:..."
  // Falls back to the bracket notation [作者名] in the episode table rows.
  let author = "不明な作者";
  const nameFieldMatch = html.match(
    /<tt>Name:\s*([^◆<\n]+)/,
  );
  if (nameFieldMatch) {
    author = decodeHtmlEntities(nameFieldMatch[1]).trim();
  } else {
    // Fallback: get author from the first table row's 3rd td: [author_name]
    const authorBracketMatch = html.match(
      /\[0\]<\/td><td[^>]*><b>\s*\n?\s*<a[^>]+>.+?<\/a><\/b><\/td><td[^>]*>\[([^\]]+)\]/,
    );
    if (authorBracketMatch) {
      author = decodeHtmlEntities(authorBracketMatch[1]).trim();
    }
  }

  // Extract episodes - Arcadia uses [number] pattern with optional title link
  // Pattern: [number]</td><td...><b><a href="...">TITLE</a></b></td>
  const episodeRegex = /\[(\d+)\]<\/td><td[^>]*><b>\s*\n?\s*<a[^>]+>(.+?)<\/a>/g;
  const episodes: EpisodeInfo[] = [];
  let match;

  while ((match = episodeRegex.exec(html)) !== null) {
    const num = parseInt(match[1]);
    episodes.push({
      siteEpisodeId: String(num),
      episodeNumber: num,
      title: decodeHtmlEntities(match[2]).trim(),
    });
  }

  // Fallback: count by simple pattern if title extraction failed
  if (episodes.length === 0) {
    const simpleRegex = /\[(\d+)\]<\/td><td/g;
    while ((match = simpleRegex.exec(html)) !== null) {
      const num = parseInt(match[1]);
      episodes.push({
        siteEpisodeId: String(num),
        episodeNumber: num,
      });
    }
  }

  const totalEpisodes = episodes.length > 0
    ? Math.max(...episodes.map((e) => e.episodeNumber))
    : 1;
  const latestId = totalEpisodes.toString();

  return {
    title,
    author,
    totalEpisodes,
    latestEpisodeId: latestId,
    episodes,
  };
}

function decodeHtmlEntities(str: string): string {
  return str
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'")
    .replace(/&#39;/g, "'")
    .replace(/&#(\d+);/g, (_, code) => String.fromCharCode(Number(code)))
    .replace(/&#x([0-9a-fA-F]+);/g, (_, hex) => String.fromCharCode(parseInt(hex, 16)))
    .replace(/<[^>]+>/g, "");
}
