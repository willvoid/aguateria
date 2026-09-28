-- =====================================================================
-- Migración: Cargo mensual "Consumo" según la categoría del inmueble
-- Ejecutar en orden, sección por sección, en el SQL Editor de Supabase.
--
-- Contexto: se creó por error un concepto "Consumo Lavadero" (id=4) para
-- intentar cobrar distinto por categoría desde la facturación manual.
-- No hace falta: fn_generar_deudas_ciclos_vencidos ya usa fk_concepto=1
-- fijo ("Consumo", único para todas las categorías) con monto tomado de
-- categoria_servicio.tarifa_fija, que ya varía por categoría. El fix real
-- fue en la UI de facturación manual (detallefacturawidget.dart), que
-- ahora también lee tarifa_fija de la categoría del inmueble en vez del
-- arancel fijo del concepto. La función SQL no se modifica.
-- =====================================================================

-- 1) Limpiar job huérfano que fallaba a diario (función que ya no existe)
--    (ya ejecutado)
SELECT cron.unschedule(1);

-- 2) Confirmar que el concepto "Consumo Lavadero" (id=4) no se usó
--    todavía en ninguna factura/deuda real antes de desactivarlo.
SELECT * FROM public.cuentas_cobrar WHERE fk_concepto = 4;
SELECT * FROM public.detalle_factura WHERE fk_concepto = 4;

-- 3) Si ambas consultas anteriores no devuelven filas, desactivar el
--    concepto duplicado (no se elimina, para no romper FKs si algo
--    llegara a referenciarlo).
UPDATE public.conceptos SET estado = 'INACTIVO' WHERE id_concepto = 4;

-- 4) Confirmar que el job programado (jobid=2) sigue corriendo sin errores:
SELECT * FROM cron.job_run_details
WHERE jobid = 2
ORDER BY start_time DESC
LIMIT 5;
