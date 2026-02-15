export interface HamelnNovelData {
  title: string;
  author: string;
  totalEpisodes: number;
  latestEpisodeId: string;
  latestEpisodeTitle: string;
}

/**
 * ハーメルンの目次ページをスクレイピングして小説メタデータを取得する
 */
export async function fetchHamelnNovel(
  novelId: string,
): Promise<HamelnNovelData | null> {
  const url = `https://syosetu.org/novel/${novelId}/`;

  try {
    const response = await fetch(url, {
      headers: {
        "User-Agent":
          "NovelNotificationApp/1.0 (Web Novel Update Checker)",
        Accept: "text/html",
      },
    });

    if (!response.ok) {
      console.error(`Hameln fetch failed: ${response.status} for ${novelId}`);
      return null;
    }

    const html = await response.text();
    return parseHamelnToc(html);
  } catch (err) {
    console.error(`Hameln fetch error for ${novelId}: ${err}`);
    return null;
  }
}

function parseHamelnToc(html: string): HamelnNovelData | null {
  // Extract title
  const titleMatch = html.match(
    /<span style="font-size:120%"><b>(.+?)<\/b><\/span>/,
  );
  const title = titleMatch
    ? decodeHtmlEntities(titleMatch[1])
    : "不明なタイトル";

  // Extract author
  const authorMatch = html.match(/作者：<a[^>]*>(.+?)<\/a>/);
  const author = authorMatch
    ? decodeHtmlEntities(authorMatch[1])
    : "不明な作者";

  // Extract episode links
  // Hameln TOC uses patterns like: <a href="/novel/{id}/{num}.html">title</a>
  const episodeRegex =
    /<a\s+href="\/novel\/\d+\/(\d+)\.html"[^>]*>(.+?)<\/a>/g;
  const episodes: { id: string; title: string }[] = [];
  let match;

  while ((match = episodeRegex.exec(html)) !== null) {
    episodes.push({
      id: match[1],
      title: decodeHtmlEntities(match[2]),
    });
  }

  if (episodes.length === 0) return null;

  const latest = episodes[episodes.length - 1];

  return {
    title,
    author,
    totalEpisodes: episodes.length,
    latestEpisodeId: latest.id,
    latestEpisodeTitle: latest.title,
  };
}

function decodeHtmlEntities(str: string): string {
  return str
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/<[^>]+>/g, ""); // Strip remaining HTML tags
}
