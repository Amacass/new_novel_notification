import {
  encode as base64UrlEncode,
} from "https://deno.land/std@0.168.0/encoding/base64url.ts";

// deno-lint-ignore no-explicit-any
type SupabaseClient = any;

interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
}

/**
 * FCM HTTP v1 API でプッシュ通知を送信する
 */
export async function sendFcmNotifications(
  client: SupabaseClient,
  userIds: string[],
  notification: { title: string; body: string },
  data?: Record<string, string>,
): Promise<void> {
  if (userIds.length === 0) return;

  // Get FCM tokens for target users
  const { data: tokens, error } = await client
    .from("fcm_tokens")
    .select("id, user_id, token")
    .in("user_id", userIds);

  if (error) {
    console.error("Failed to fetch FCM tokens:", error);
    return;
  }

  if (!tokens || tokens.length === 0) return;

  // Get service account
  const serviceAccountJson = Deno.env.get("FCM_SERVICE_ACCOUNT");
  if (!serviceAccountJson) {
    console.warn("FCM_SERVICE_ACCOUNT not set, skipping push notifications");
    return;
  }

  let serviceAccount: ServiceAccount;
  try {
    serviceAccount = JSON.parse(serviceAccountJson);
  } catch {
    console.error("Failed to parse FCM_SERVICE_ACCOUNT JSON");
    return;
  }

  // Get OAuth2 access token
  const accessToken = await getAccessToken(serviceAccount);
  if (!accessToken) return;

  const invalidTokenIds: number[] = [];

  // Send to each token
  for (const { id, token } of tokens) {
    try {
      const response = await fetch(
        `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`,
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${accessToken}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            message: {
              token,
              notification,
              data: data ?? {},
            },
          }),
        },
      );

      if (!response.ok) {
        const body = await response.text();
        console.error(`FCM send failed for token ${id}: ${response.status} ${body}`);

        // Remove unregistered/invalid tokens
        if (
          response.status === 404 ||
          body.includes("UNREGISTERED") ||
          body.includes("INVALID_ARGUMENT")
        ) {
          invalidTokenIds.push(id);
        }
      }
    } catch (err) {
      console.error(`FCM send error for token ${id}: ${err}`);
    }
  }

  // Clean up invalid tokens
  if (invalidTokenIds.length > 0) {
    await client
      .from("fcm_tokens")
      .delete()
      .in("id", invalidTokenIds);
    console.log(`Removed ${invalidTokenIds.length} invalid FCM tokens`);
  }
}

/**
 * Google OAuth2 アクセストークンをJWTで取得する
 */
async function getAccessToken(
  sa: ServiceAccount,
): Promise<string | null> {
  try {
    const now = Math.floor(Date.now() / 1000);

    const header = { alg: "RS256", typ: "JWT" };
    const payload = {
      iss: sa.client_email,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: "https://oauth2.googleapis.com/token",
      iat: now,
      exp: now + 3600,
    };

    const encodedHeader = base64UrlEncode(
      new TextEncoder().encode(JSON.stringify(header)).buffer as ArrayBuffer,
    );
    const encodedPayload = base64UrlEncode(
      new TextEncoder().encode(JSON.stringify(payload)).buffer as ArrayBuffer,
    );

    const signingInput = `${encodedHeader}.${encodedPayload}`;

    // Import private key and sign
    const pemContents = sa.private_key
      .replace(/-----BEGIN PRIVATE KEY-----/, "")
      .replace(/-----END PRIVATE KEY-----/, "")
      .replace(/\n/g, "");

    const binaryKey = Uint8Array.from(atob(pemContents), (c) =>
      c.charCodeAt(0));

    const cryptoKey = await crypto.subtle.importKey(
      "pkcs8",
      binaryKey,
      { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
      false,
      ["sign"],
    );

    const signature = await crypto.subtle.sign(
      "RSASSA-PKCS1-v1_5",
      cryptoKey,
      new TextEncoder().encode(signingInput),
    );

    const encodedSignature = base64UrlEncode(signature);
    const jwt = `${signingInput}.${encodedSignature}`;

    // Exchange JWT for access token
    const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
        assertion: jwt,
      }),
    });

    if (!tokenResponse.ok) {
      const body = await tokenResponse.text();
      console.error(`OAuth2 token exchange failed: ${tokenResponse.status} ${body}`);
      return null;
    }

    const tokenData = await tokenResponse.json();
    return tokenData.access_token;
  } catch (err) {
    console.error(`Failed to get OAuth2 access token: ${err}`);
    return null;
  }
}
