import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { corsHeaders } from "../_shared/cors.ts";
import { createServiceClient, createUserClient } from "../_shared/supabase-client.ts";

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return new Response(
      JSON.stringify({ error: "Missing authorization header" }),
      { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }

  const userClient = createUserClient(authHeader);
  const { data: { user }, error: userError } = await userClient.auth.getUser();

  if (userError || !user) {
    return new Response(
      JSON.stringify({ error: "Unauthorized" }),
      { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }

  let token: string;
  let platform: string;

  try {
    const body = await req.json();
    token = body.token;
    platform = body.platform;
    if (!token || !platform) throw new Error("Missing token or platform");
  } catch {
    return new Response(
      JSON.stringify({ error: "Invalid request body. Required: { token, platform }" }),
      { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }

  const serviceClient = createServiceClient();

  const { error } = await serviceClient.from("fcm_tokens").upsert(
    {
      user_id: user.id,
      token,
      platform,
      updated_at: new Date().toISOString(),
    },
    { onConflict: "token" },
  );

  if (error) {
    console.error("FCM token registration error:", error);
    return new Response(
      JSON.stringify({ error: "Failed to register token" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }

  return new Response(
    JSON.stringify({ message: "Token registered successfully" }),
    { headers: { ...corsHeaders, "Content-Type": "application/json" } },
  );
});
