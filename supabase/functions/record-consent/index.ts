import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { corsHeaders } from "../_shared/cors.ts";
import { createUserClient, createServiceClient } from "../_shared/supabase-client.ts";

/**
 * ユーザーの法的文書への同意を記録する
 */
serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "unauthorized" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const userClient = createUserClient(authHeader);
    const serviceClient = createServiceClient();

    const { data: { user } } = await userClient.auth.getUser();
    if (!user) {
      return new Response(
        JSON.stringify({ error: "unauthorized" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const { document_type, version } = await req.json();

    if (!document_type || !version) {
      return new Response(
        JSON.stringify({ error: "missing_params", message: "document_type and version are required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // Verify the document exists and is active
    const { data: document, error: docError } = await serviceClient
      .from("legal_documents")
      .select("*")
      .eq("document_type", document_type)
      .eq("version", version)
      .eq("is_active", true)
      .maybeSingle();

    if (docError) throw docError;

    if (!document) {
      return new Response(
        JSON.stringify({ error: "document_not_found", message: "指定された文書が見つかりません" }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // Record consent
    const { error: insertError } = await serviceClient
      .from("user_consents")
      .insert({
        user_id: user.id,
        document_type,
        version,
        consented_at: new Date().toISOString(),
        ip_address: req.headers.get("x-forwarded-for") ?? req.headers.get("cf-connecting-ip") ?? null,
        user_agent: req.headers.get("user-agent") ?? null,
      });

    if (insertError) throw insertError;

    return new Response(
      JSON.stringify({
        success: true,
        document_type,
        version,
        consented_at: new Date().toISOString(),
      }),
      { status: 201, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err) {
    console.error("record-consent error:", err);
    return new Response(
      JSON.stringify({ error: "internal_error", message: String(err) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
