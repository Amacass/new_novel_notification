import type { ModerationInput, ModerationProvider, ModerationResult } from "./provider.ts";

const MODEL = "gemma-4-31b-it";
const API_BASE = "https://generativelanguage.googleapis.com/v1beta/models";

const PROMPT_TEMPLATE = `あなたはWeb小説レビューのモデレーターです。
以下の「見出し」「本文」が、指定された小説の感想・おすすめとして適切か判定してください。

弾く対象:
(1) R18・露骨な性的表現
(2) 広告・宣伝・外部URL誘導・スパム
(3) 誹謗中傷・アンチ・ヘイト・作者や他者への攻撃
(4) その小説の感想から著しく逸脱した無関係な内容

また、小説のタイトル・あらすじから「オリジナル（一次創作）」か「二次創作」かを推定してください。

必ず以下のJSON形式のみで返答してください（説明文は不要）:
{"allow": <true|false>, "reason": <"r18"|"ad"|"harassment"|"off_topic"|"other"|null>, "work_kind": <"original"|"derivative"|null>}

- allow=true の場合 reason は null
- allow=false の場合 reason は必須
- work_kind が不明な場合は null

小説タイトル: {title}
あらすじ（先頭200字）: {synopsis}
見出し: {heading}
本文: {body}`;

export class GemmaModerationProvider implements ModerationProvider {
  private apiKey: string;

  constructor(apiKey: string) {
    this.apiKey = apiKey;
  }

  async classify(input: ModerationInput): Promise<ModerationResult> {
    const prompt = PROMPT_TEMPLATE
      .replace("{title}", input.novelTitle || "（タイトル不明）")
      .replace("{synopsis}", (input.synopsis || "").slice(0, 200) || "（あらすじなし）")
      .replace("{heading}", input.heading)
      .replace("{body}", input.body.slice(0, 1000));

    const url = `${API_BASE}/${MODEL}:generateContent?key=${this.apiKey}`;

    const resp = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [{ parts: [{ text: prompt }] }],
        generationConfig: {
          responseMimeType: "application/json",
          temperature: 0,
          maxOutputTokens: 128,
        },
      }),
    });

    if (!resp.ok) {
      const err = await resp.text();
      throw new Error(`Gemma API error ${resp.status}: ${err.slice(0, 200)}`);
    }

    const data = await resp.json();
    const text: string = data?.candidates?.[0]?.content?.parts?.[0]?.text ?? "";

    try {
      const parsed = JSON.parse(text.trim());
      return {
        allow: parsed.allow === true,
        reason: parsed.allow ? null : (parsed.reason ?? "other"),
        workKind: parsed.work_kind ?? null,
      };
    } catch {
      // パース失敗はフェイルクローズ（pending のまま）
      console.error("Failed to parse Gemma response:", text);
      throw new Error(`Failed to parse moderation response: ${text.slice(0, 100)}`);
    }
  }
}
