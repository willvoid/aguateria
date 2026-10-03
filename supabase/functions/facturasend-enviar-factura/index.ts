// Edge Function real: envía a FacturaSend una factura ya creada en el flujo
// normal de facturación. Separada de `facturasend-test` (y con su propio
// secret, `FACTURASEND_ENVIAR_ALLOW_SEND`) para que activar el envío real
// acá nunca convierta la pantalla de prueba aislada en una herramienta de
// envío real sin querer — ver `supabase/functions/_shared/facturasend.ts`.
import { runFacturaSendProxy } from "../_shared/facturasend.ts";

interface EnviarFacturaBody {
  idFactura?: unknown;
}

Deno.serve((req) =>
  runFacturaSendProxy(req, {
    functionName: "facturasend-enviar-factura",
    // Borrador salvo que el secret esté EXACTAMENTE en "true". Default
    // (secret ausente o cualquier otro valor) = borrador.
    resolveDraft: () => Deno.env.get("FACTURASEND_ENVIAR_ALLOW_SEND") !== "true",
    validateBody: (b) => {
      const idFactura = (b as EnviarFacturaBody).idFactura;
      return Number.isInteger(idFactura) && (idFactura as number) > 0
        ? null
        : "Falta 'idFactura' válido";
    },
    logExtra: (ctx) => ({ idFactura: ctx.body.idFactura }),
  })
);
