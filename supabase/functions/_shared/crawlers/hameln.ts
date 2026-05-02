export interface EpisodeInfo {
  siteEpisodeId: string;
  episodeNumber: number;
  title?: string;
}

export interface HamelnNovelData {
  title: string;
  author: string;
  totalEpisodes: number;
  latestEpisodeId: string;
  latestEpisodeTitle: string;
  episodes: EpisodeInfo[];
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
    episodes: episodes.map((ep, idx) => ({
      siteEpisodeId: ep.id,
      episodeNumber: idx + 1,
      title: ep.title,
    })),
  };
}

/**
 * ハーメルンの作者マイページから作品一覧を取得する
 */
export async function fetchHamelnNovelsByAuthor(
  authorId: string,
): Promise<{ novelId: string; title: string }[]> {
  const url = `https://syosetu.org/user/${authorId}/`;

  try {
    const response = await fetch(url, {
      headers: {
        "User-Agent":
          "NovelNotificationApp/1.0 (Web Novel Update Checker)",
        Accept: "text/html",
      },
    });

    if (!response.ok) {
      console.error(`Hameln author page fetch failed: ${response.status} for ${authorId}`);
      return [];
    }

    const html = await response.text();

    // Extract novel links: <a href="/novel/{id}/">title</a>
    const novelRegex = /<a\s+href="\/novel\/(\d+)\/"[^>]*>(.+?)<\/a>/g;
    const novels: { novelId: string; title: string }[] = [];
    let match;

    while ((match = novelRegex.exec(html)) !== null) {
      novels.push({
        novelId: match[1],
        title: decodeHtmlEntities(match[2]),
      });
    }

    return novels;
  } catch (err) {
    console.error(`Hameln author page error for ${authorId}: ${err}`);
    return [];
  }
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
