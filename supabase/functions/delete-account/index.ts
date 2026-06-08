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

  const userId = user.id;
  const serviceClient = createServiceClient();

  try {
    // bookmarks の id を先に取得 (bookmark_tags の削除に必要)
    const { data: bookmarks } = await serviceClient
      .from("bookmarks")
      .select("id")
      .eq("user_id", userId);

    if (bookmarks && bookmarks.length > 0) {
      const bookmarkIds = bookmarks.map((b: { id: number }) => b.id);
      await serviceClient.from("bookmark_tags").delete().in("bookmark_id", bookmarkIds);
    }

    // ON DELETE CASCADE が設定されていないテーブルを明示的に削除
    await serviceClient.from("notifications").delete().eq("user_id", userId);
    await serviceClient.from("bookmarks").delete().eq("user_id", userId);
    await serviceClient.from("reviews").delete().eq("user_id", userId);
    await serviceClient.from("favorite_authors").delete().eq("user_id", userId);
    await serviceClient.from("user_tags").delete().eq("user_id", userId);
    await serviceClient.from("fcm_tokens").delete().eq("user_id", userId);
    await serviceClient.from("user_consents").delete().eq("user_id", userId);
    await serviceClient.from("profiles").delete().eq("id", userId);

    // Supabase Auth からユーザーを削除
    const { error: deleteError } = await serviceClient.auth.admin.deleteUser(userId);
    if (deleteError) throw deleteError;

    return new Response(
      JSON.stringify({ message: "Account deleted successfully" }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err) {
    console.error("Account deletion error:", err);
    return new Response(
      JSON.stringify({ error: "Failed to delete account", message: String(err) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
