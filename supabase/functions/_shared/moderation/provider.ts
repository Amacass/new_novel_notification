export interface ModerationInput {
  heading: string;
  body: string;
  novelTitle: string;
  synopsis: string;
}

export interface ModerationResult {
  allow: boolean;
  reason: "r18" | "ad" | "harassment" | "off_topic" | "other" | null;
  workKind: "original" | "derivative" | null;
}

export interface ModerationProvider {
  classify(input: ModerationInput): Promise<ModerationResult>;
}
