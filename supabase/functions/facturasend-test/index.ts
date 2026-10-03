// PoC aislado: proxy de prueba hacia FacturaSend (SIFEN, Paraguay).
// No integrado al flujo real de facturación. Ver:
// supabase/functions/facturasend-test/deno.json (import map)
// supabase/functions/.env.example (nombres de secrets, sin valores)
import { runFacturaSendProxy } from "../_shared/facturasend.ts";

// Rail de seguridad: esta función NUNCA lee ningún secret para decidir si
// envía un documento real — `resolveDraft` queda hardcodeado a `true`. La
// pantalla de prueba aislada nunca va a poder mandar un documento real a
// SIFEN, pase lo que pase con `FACTURASEND_ENVIAR_ALLOW_SEND` (el secret de
// la función real, `facturasend-enviar-factura`), porque los secrets de
// Supabase son por proyecto, no por función.
Deno.serve((req) =>
  runFacturaSendProxy(req, {
    functionName: "facturasend-test",
    resolveDraft: () => true,
  })
);
