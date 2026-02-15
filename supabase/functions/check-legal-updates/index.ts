import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { corsHeaders } from "../_shared/cors.ts";
import { createUserClient, createServiceClient } from "../_shared/supabase-client.ts";

/**
 * ユーザーが未同意の法的文書をチェックする
 * アプリ起動時にフロントエンドから呼び出される
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

    // Get all active legal documents
    const { data: documents, error: docError } = await serviceClient
      .from("legal_documents")
      .select("*")
      .eq("is_active", true)
      .order("effective_date", { ascending: false });

    if (docError) throw docError;
    if (!documents || documents.length === 0) {
      return new Response(
        JSON.stringify({ pending: [], all_consented: true }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // Get user's consent records
    const { data: consents, error: consentError } = await serviceClient
      .from("user_consents")
      .select("*")
      .eq("user_id", user.id);

    if (consentError) throw consentError;

    // Find the latest consent for each document type
    const consentMap = new Map<string, { version: string; consented_at: string }>();
    for (const consent of consents ?? []) {
      const existing = consentMap.get(consent.document_type);
      if (!existing || consent.consented_at > existing.consented_at) {
        consentMap.set(consent.document_type, {
          version: consent.version,
          consented_at: consent.consented_at,
        });
      }
    }

    // Find documents that need consent
    // deno-lint-ignore no-explicit-any
    const pending: any[] = [];
    for (const doc of documents) {
      const consent = consentMap.get(doc.document_type);
      if (!consent || consent.version !== doc.version) {
        pending.push({
          id: doc.id,
          document_type: doc.document_type,
          version: doc.version,
          title: doc.title,
          content_url: doc.content_url,
          effective_date: doc.effective_date,
          previously_consented_version: consent?.version ?? null,
        });
      }
    }

    return new Response(
      JSON.stringify({
        pending,
        all_consented: pending.length === 0,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err) {
    console.error("check-legal-updates error:", err);
    return new Response(
      JSON.stringify({ error: "internal_error", message: String(err) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
