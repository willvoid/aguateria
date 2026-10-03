// Pipeline compartido del proxy hacia FacturaSend (SIFEN, Paraguay).
//
// Extraído de `facturasend-test` para que esa función y la función real
// (`facturasend-enviar-factura`) no mantengan dos copias de la lógica de
// auth/secrets/fetch/cálculo de `ok` que puedan desincronizarse — ya pasó
// una vez: el bug de `ok: true` hardcodeado sin revisar el body de
// FacturaSend.
//
// Cada función que usa este pipeline pasa su propia política de borrador
// (`resolveDraft`). Ese flag nunca se lee acá desde un secret común, así
// activar el envío real en una función jamás afecta a la otra (los secrets
// de Supabase son por proyecto, no por función).
import { createClient } from "@supabase/supabase-js";
import { corsHeaders } from "./cors.ts";

export interface FacturaSendProxyBody {
  documento: Record<string, unknown>;
  qr?: boolean;
  [key: string]: unknown;
}

export interface RunOptions {
  /** Nombre de la función que invoca el pipeline, solo para logs. */
  functionName: string;
  /** Política de borrador/real de ESTA función. Nunca se comparte entre funciones. */
  resolveDraft: () => boolean;
  /** Validación extra del body además de 'documento'. Devuelve un mensaje de error, o null si es válido. */
  validateBody?: (body: FacturaSendProxyBody) => string | null;
  /** Campos extra a loguear (nunca datos sensibles: ni la key ni el payload completo). */
  logExtra?: (ctx: { body: FacturaSendProxyBody }) => Record<string, unknown>;
}

function jsonResponse(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

// Secrets de FacturaSend. Deliberadamente NO incluye ningún flag de
// "permitir envío real" (ni `FACTURASEND_ALLOW_SEND` ni el nuevo
// `FACTURASEND_ENVIAR_ALLOW_SEND`) — esa decisión es responsabilidad
// exclusiva de `resolveDraft`, que cada función define por su cuenta.
function readFacturaSendConfig() {
  return {
    apiKey: Deno.env.get("FACTURASEND_API_KEY"),
    tenantId: Deno.env.get("FACTURASEND_TENANT_ID"),
    baseUrl: Deno.env.get("FACTURASEND_BASE_URL"),
  };
}

export async function runFacturaSendProxy(
  req: Request,
  opts: RunOptions,
): Promise<Response> {
  const { functionName, resolveDraft, validateBody, logExtra } = opts;

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
  const { apiKey, tenantId, baseUrl } = readFacturaSendConfig();
  if (!apiKey || !tenantId || !baseUrl) {
    return jsonResponse(500, { ok: false, error: "Faltan secrets de FacturaSend en el servidor" });
  }

  // 3. Body.
  let body: FacturaSendProxyBody;
  try {
    body = await req.json();
  } catch {
    return jsonResponse(400, { ok: false, error: "Body inválido: se esperaba JSON" });
  }

  if (!body || typeof body.documento !== "object" || body.documento === null) {
    return jsonResponse(400, { ok: false, error: "Falta el campo 'documento' en el body" });
  }

  if (validateBody) {
    const validationError = validateBody(body);
    if (validationError) {
      return jsonResponse(400, { ok: false, error: validationError });
    }
  }

  // 4. Rail de seguridad: cada función decide su propia política de borrador
  // vía `resolveDraft`, pasada como parámetro — nunca un secret compartido.
  const draft = resolveDraft();

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
    console.log(JSON.stringify({
      functionName,
      userId: user.id,
      upstreamStatus: null,
      draft,
      ms: Date.now() - startedAt,
      ...(logExtra ? logExtra({ body }) : {}),
    }));
    return jsonResponse(502, {
      ok: false,
      error: `No se pudo contactar a FacturaSend: ${err instanceof Error ? err.message : String(err)}`,
    });
  }

  const ms = Date.now() - startedAt;

  // 6. Log sin datos sensibles (nunca la key ni el payload completo).
  console.log(JSON.stringify({
    functionName,
    userId: user.id,
    upstreamStatus,
    draft,
    ms,
    ...(logExtra ? logExtra({ body }) : {}),
  }));

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
}
