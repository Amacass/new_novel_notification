export interface NarouNovelData {
  title: string;
  writer: string;
  totalEpisodes: number;
  lastUpdated: string;
}

/**
 * なろうAPIから小説メタデータを取得する
 * API: https://dev.syosetu.com/man/api/
 */
export async function fetchNarouNovel(
  ncode: string,
): Promise<NarouNovelData | null> {
  const url = new URL("https://api.syosetu.com/novelapi/api/");
  url.searchParams.set("ncode", ncode);
  url.searchParams.set("of", "t-w-ga-nu");
  url.searchParams.set("out", "json");
  url.searchParams.set("lim", "1");

  const response = await fetch(url.toString());
  if (!response.ok) return null;

  const data = await response.json();

  // First element is allcount metadata, second is the novel data
  if (!Array.isArray(data) || data.length < 2) return null;

  const novel = data[1];
  return {
    title: novel.title,
    writer: novel.writer,
    totalEpisodes: novel.general_all_no,
    lastUpdated: novel.novelupdated_at,
  };
}

/**
 * なろうAPIで複数小説を一括取得する (最大20件)
 */
export async function fetchNarouNovels(
  ncodes: string[],
): Promise<Map<string, NarouNovelData>> {
  const results = new Map<string, NarouNovelData>();

  // API allows max 20 ncodes per request
  const batchSize = 20;
  for (let i = 0; i < ncodes.length; i += batchSize) {
    const batch = ncodes.slice(i, i + batchSize);
    const url = new URL("https://api.syosetu.com/novelapi/api/");
    url.searchParams.set("ncode", batch.join("-"));
    url.searchParams.set("of", "n-t-w-ga-nu");
    url.searchParams.set("out", "json");
    url.searchParams.set("lim", String(batch.length));

    try {
      const response = await fetch(url.toString());
      if (!response.ok) continue;

      const data = await response.json();
      if (!Array.isArray(data)) continue;

      // Skip first element (allcount metadata)
      for (let j = 1; j < data.length; j++) {
        const novel = data[j];
        const ncode = String(novel.ncode).toLowerCase();
        results.set(ncode, {
          title: novel.title,
          writer: novel.writer,
          totalEpisodes: novel.general_all_no,
          lastUpdated: novel.novelupdated_at,
        });
      }
    } catch (err) {
      console.error(`Narou API batch error: ${err}`);
    }

    // Rate limiting: 1 second between batches
    if (i + batchSize < ncodes.length) {
      await new Promise((resolve) => setTimeout(resolve, 1000));
    }
  }

  return results;
}

/**
 * なろうAPIで特定作者の小説一覧を取得する
 */
export async function fetchNarouNovelsByAuthor(
  userId: string,
  // deno-lint-ignore no-explicit-any
): Promise<any[]> {
  const url = new URL("https://api.syosetu.com/novelapi/api/");
  url.searchParams.set("userid", userId);
  url.searchParams.set("of", "n-t-w-ga");
  url.searchParams.set("out", "json");
  url.searchParams.set("lim", "100");
  url.searchParams.set("order", "new");

  try {
    const response = await fetch(url.toString());
    if (!response.ok) return [];

    const data = await response.json();
    if (!Array.isArray(data) || data.length < 2) return [];

    // Skip first element (allcount metadata)
    return data.slice(1);
  } catch (err) {
    console.error(`Narou author API error: ${err}`);
    return [];
  }
}
