export interface ArcadiaNovelData {
  title: string;
  author: string;
  totalEpisodes: number;
  latestEpisodeId: string;
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
          "NovelNotificationApp/1.0 (Web Novel Update Checker)",
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
  // Extract title from page
  const titleMatch = html.match(/<title>(.+?)<\/title>/i);
  const title = titleMatch
    ? decodeHtmlEntities(titleMatch[1]).replace(/ - Arcadia.*$/, "").trim()
    : "不明なタイトル";

  // Extract author - Arcadia BBS format varies
  const authorMatch = html.match(
    /投稿者[：:][\s]*(?:<[^>]+>)*\s*([^<\n]+)/,
  );
  const author = authorMatch
    ? decodeHtmlEntities(authorMatch[1]).trim()
    : "不明な作者";

  // Count episodes/posts - look for numbered sections
  // Arcadia uses various patterns depending on the story format
  const partRegex = /No\.(\d+)/g;
  const partNumbers: number[] = [];
  let match;

  while ((match = partRegex.exec(html)) !== null) {
    partNumbers.push(parseInt(match[1]));
  }

  const totalEpisodes = partNumbers.length > 0
    ? Math.max(...partNumbers)
    : 1;
  const latestId = totalEpisodes.toString();

  return {
    title,
    author,
    totalEpisodes,
    latestEpisodeId: latestId,
  };
}

function decodeHtmlEntities(str: string): string {
  return str
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/<[^>]+>/g, "");
}
