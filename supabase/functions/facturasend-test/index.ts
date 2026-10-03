// PoC aislado: proxy de prueba hacia FacturaSend (SIFEN, Paraguay).
// No integrado al flujo real de facturación. Ver:
// supabase/functions/facturasend-test/deno.json (import map)
// supabase/functions/.env.example (nombres de secrets, sin valores)
import { createClient } from "@supabase/supabase-js";
import { corsHeaders } from "../_shared/cors.ts";

interface FacturaSendTestBody {
  documento: Record<string, unknown>;
  qr?: boolean;
}

function jsonResponse(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function logResult(userId: string, upstreamStatus: number | null, draft: boolean, ms: number) {
  console.log(JSON.stringify({ userId, upstreamStatus, draft, ms }));
}

Deno.serve(async (req) => {
  // Preflight CORS.
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse(405, { ok: false, error: "Método no permitido" });
  }

  const startedAt = Date.now();

  // 1. Autenticación: requiere un JWT de usuario válido (la anon key sola no alcanza).
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return jsonResponse(401, { ok: false, error: "Falta el header Authorization" });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!supabaseUrl || !supabaseAnonKey) {
    return jsonResponse(500, { ok: false, error: "Configuración de Supabase incompleta" });
  }

  const supabaseClient = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: authHeader } },
  });

  const { data: userData, error: userError } = await supabaseClient.auth.getUser();
  if (userError || !userData?.user) {
    return jsonResponse(401, { ok: false, error: "Usuario no autenticado" });
  }
  const user = userData.user;

  // 2. Secrets de FacturaSend.
  const apiKey = Deno.env.get("FACTURASEND_API_KEY");
  const tenantId = Deno.env.get("FACTURASEND_TENANT_ID");
  const baseUrl = Deno.env.get("FACTURASEND_BASE_URL");
  const allowSend = Deno.env.get("FACTURASEND_ALLOW_SEND") === "true";

  if (!apiKey || !tenantId || !baseUrl) {
    return jsonResponse(500, { ok: false, error: "Faltan secrets de FacturaSend en el servidor" });
  }

  // 3. Body.
  let body: FacturaSendTestBody;
  try {
    body = await req.json();
  } catch {
    return jsonResponse(400, { ok: false, error: "Body inválido: se esperaba JSON" });
  }

  if (!body || typeof body.documento !== "object" || body.documento === null) {
    return jsonResponse(400, { ok: false, error: "Falta el campo 'documento' en el body" });
  }

  // 4. Rail de seguridad: siempre borrador salvo FACTURASEND_ALLOW_SEND=true en el server.
  const draft = !allowSend;

  // 5. Llamada a FacturaSend.
  const qs = new URLSearchParams({ draft: String(draft) });
  if (body.qr === true) qs.set("qr", "true");
  const upstreamUrl = `${baseUrl}/${tenantId}/lote/create?${qs}`;

  let upstreamStatus = 0;
  let facturasend: unknown = null;

  try {
    const upstreamResponse = await fetch(upstreamUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer api_key_${apiKey}`,
      },
      body: JSON.stringify([body.documento]),
    });

    upstreamStatus = upstreamResponse.status;

    try {
      facturasend = await upstreamResponse.json();
    } catch {
      const rawText = await upstreamResponse.text().catch(() => "");
      facturasend = { raw: rawText };
    }
  } catch (err) {
    logResult(user.id, null, draft, Date.now() - startedAt);
    return jsonResponse(502, {
      ok: false,
      error: `No se pudo contactar a FacturaSend: ${err instanceof Error ? err.message : String(err)}`,
    });
  }

  const ms = Date.now() - startedAt;

  // 6. Log sin datos sensibles (nunca la key ni el payload completo).
  logResult(user.id, upstreamStatus, draft, ms);

  // 7. Siempre 200 en este nivel (el error, si lo hay, es de negocio, no del
  // proxy). `ok` refleja si FacturaSend efectivamente aceptó el documento:
  // status 2xx Y (si el body es un objeto JSON) success !== false. Flutter
  // usa esto para pintar la card verde/roja; los detalles siempre quedan
  // disponibles en facturasend.errores.
  const httpOk = upstreamStatus >= 200 && upstreamStatus < 300;
  const businessOk = typeof facturasend === "object" && facturasend !== null &&
    (facturasend as Record<string, unknown>).success !== false;

  return jsonResponse(200, {
    ok: httpOk && businessOk,
    upstreamStatus,
    draft,
    ms,
    facturasend,
  });
});
