import type { ModerationInput, ModerationProvider, ModerationResult } from "./provider.ts";

const MODEL = "gemma-4-31b-it";
const API_BASE = "https://generativelanguage.googleapis.com/v1beta/models";

const RESPONSE_SCHEMA = {
  type: "object",
  properties: {
    allow:     { type: "boolean" },
    reason:    { type: "string",  nullable: true },
    work_kind: { type: "string",  nullable: true },
  },
  required: ["allow"],
};

function buildPrompt(input: ModerationInput): string {
  return `You are a content moderator for a Japanese novel review site.
Decide if the following review is appropriate. Output JSON only.

Rules:
- allow=false if: R18/explicit sexual content, advertisement/spam/external links, harassment/hate/anti-author attacks, or completely unrelated to the novel
- reason: "r18" | "ad" | "harassment" | "off_topic" | "other" (null when allow=true)
- work_kind: "original" if first-work, "derivative" if fan-fiction (null if unknown)

Novel: ${input.novelTitle || "（不明）"}
Synopsis: ${(input.synopsis || "").slice(0, 200) || "（なし）"}
Headline: ${input.heading}
Review: ${input.body.slice(0, 800)}`;
}

function extractJson(text: string): unknown {
  // responseSchema でも末尾に ``` が付くことがある
  const cleaned = text.trim().replace(/^```[a-z]*\n?/i, "").replace(/\n?```$/, "").trim();
  // JSON オブジェクトを正規表現で抽出
  const m = cleaned.match(/\{[\s\S]*\}/);
  if (!m) throw new Error(`No JSON object found in: ${cleaned.slice(0, 100)}`);
  return JSON.parse(m[0]);
}

export class GemmaModerationProvider implements ModerationProvider {
  private apiKey: string;

  constructor(apiKey: string) {
    this.apiKey = apiKey;
  }

  async classify(input: ModerationInput): Promise<ModerationResult> {
    const url = `${API_BASE}/${MODEL}:generateContent?key=${this.apiKey}`;

    const resp = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [{ role: "user", parts: [{ text: buildPrompt(input) }] }],
        generationConfig: {
          responseMimeType: "application/json",
          responseSchema: RESPONSE_SCHEMA,
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
      const parsed = extractJson(text) as Record<string, unknown>;
      const allow = parsed.allow === true;
      return {
        allow,
        reason: allow ? null : ((parsed.reason as string) ?? "other"),
        workKind: (parsed.work_kind as string | null) ?? null,
      };
    } catch (e) {
      console.error("Failed to parse Gemma response:", text, e);
      throw new Error(`Failed to parse moderation response: ${text.slice(0, 100)}`);
    }
  }
}
