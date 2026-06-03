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
  latestUpdatedAt: string | null;
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
          "NovelmarkApp/1.0 (Web Novel Update Checker)",
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
  // Extract title: <span style="font-size:150%" itemprop="name">タイトル</span>
  const titleMatch = html.match(/<span[^>]*itemprop="name"[^>]*>(.+?)<\/span>/);
  const title = titleMatch
    ? decodeHtmlEntities(titleMatch[1])
    : "不明なタイトル";

  // Extract author: 作者：<span itemprop="author">author</span>
  // Note: author name may appear as plain text or wrapped in <a> tag
  const authorMatch = html.match(/itemprop="author"[^>]*>(?:<a[^>]*>)?([^<]+)/);
  const author = authorMatch
    ? decodeHtmlEntities(authorMatch[1].trim())
    : "不明な作者";

  // Extract latest updated date: <time itemprop="dateModified" datetime="YYYY-MM-DDTHH:MMZ">
  // Note: Hameln incorrectly marks JST times with Z suffix — replace Z with +09:00
  const dateModifiedMatch = html.match(/<time\s+itemprop="dateModified"\s+datetime="([^"]+)"/);
  const latestUpdatedAt = dateModifiedMatch
    ? dateModifiedMatch[1].replace(/Z$/, "+09:00")
    : null;

  // Extract episode links: <a href=./N.html style="text-decoration:none;">title</a>
  // Note: href is unquoted relative URL (./1.html, ./2.html, ...)
  const episodeRegex = /<a\s+href=\.\/(\d+)\.html[^>]*>([^<]+)<\/a>/g;
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
    latestUpdatedAt,
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
          "NovelmarkApp/1.0 (Web Novel Update Checker)",
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
    .replace(/&apos;/g, "'")
    .replace(/&#39;/g, "'")
    .replace(/&#(\d+);/g, (_, code) => String.fromCharCode(Number(code)))
    .replace(/&#x([0-9a-fA-F]+);/g, (_, hex) => String.fromCharCode(parseInt(hex, 16)))
    .replace(/<[^>]+>/g, "");
}
