export interface ParsedNovel {
  site: "narou" | "hameln" | "arcadia";
  siteNovelId: string;
  normalizedUrl: string;
}

export function parseNovelUrl(url: string): ParsedNovel | null {
  try {
    const uri = new URL(url);

    // 小説家になろう
    if (uri.hostname === "ncode.syosetu.com") {
      const match = uri.pathname.match(/\/([nN]\d+[a-zA-Z]+)/);
      if (match) {
        const ncode = match[1].toLowerCase();
        return {
          site: "narou",
          siteNovelId: ncode,
          normalizedUrl: `https://ncode.syosetu.com/${ncode}/`,
        };
      }
    }

    // ハーメルン
    if (uri.hostname === "syosetu.org") {
      const match = uri.pathname.match(/\/novel\/(\d+)/);
      if (match) {
        return {
          site: "hameln",
          siteNovelId: match[1],
          normalizedUrl: `https://syosetu.org/novel/${match[1]}/`,
        };
      }
    }

    // Arcadia
    if (uri.hostname === "www.mai-net.net") {
      const all = uri.searchParams.get("all");
      const cate = uri.searchParams.get("cate");
      if (all && cate) {
        return {
          site: "arcadia",
          siteNovelId: `${cate}_${all}`,
          normalizedUrl: `http://www.mai-net.net/bbs/sst/sst.php?act=dump&cate=${cate}&all=${all}`,
        };
      }
    }
  } catch {
    // Invalid URL
  }

  return null;
}
