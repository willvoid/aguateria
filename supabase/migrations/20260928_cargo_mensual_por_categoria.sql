-- =====================================================================
-- Migración: Cargo mensual por categoría de inmueble
-- Ejecutar en orden, sección por sección, en el SQL Editor de Supabase.
--
-- Contexto: fn_generar_deudas_ciclos_vencidos generaba todos los cargos
-- mensuales bajo un fk_concepto=1 fijo, sin importar la categoria_servicio
-- del inmueble. Esta migración crea un concepto por categoría (usando su
-- tarifa_fija) y actualiza la función para usarlo. La definición vigente
-- de la función vive en supabase/functions/fn_generar_deudas_ciclos_vencidos.sql
-- =====================================================================

-- 1) Limpiar job huérfano que falla a diario (función que ya no existe)
SELECT cron.unschedule(1);

-- 2) Ver IDs disponibles de iva y unidades_medida para elegir los correctos
--    antes de correr el backfill del paso 3.
SELECT * FROM public.iva;
SELECT * FROM public.unidades_medida;

-- 3) Backfill: crear un concepto por cada categoría de servicio que
--    todavía no tenga uno asociado (arancel = tarifa_fija de la categoría).
--    Reemplazar <ID_IVA> y <ID_UNIDAD_MEDIDA> por los valores reales
--    obtenidos en el paso 2 (usar el IVA/unidad que corresponda a un
--    cargo fijo mensual, por ejemplo "exenta" o "10%" según tu operativa).
INSERT INTO public.conceptos (nombre, arancel, descripcion, fk_iva, fk_unidad_medida, estado, fk_servicio)
SELECT
  'Cargo mensual ' || cs.nombre,
  cs.tarifa_fija,
  'Tarifa fija mensual - ' || cs.nombre,
  <ID_IVA>,
  <ID_UNIDAD_MEDIDA>,
  'ACTIVO',
  cs.id
FROM public.categoria_servicio cs
WHERE NOT EXISTS (
  SELECT 1 FROM public.conceptos c
  WHERE c.fk_servicio = cs.id AND c.estado = 'ACTIVO'
);

-- Verificar que todas las categorías quedaron con concepto asociado:
SELECT cs.id, cs.nombre, cs.tarifa_fija, c.id_concepto, c.arancel
FROM public.categoria_servicio cs
LEFT JOIN public.conceptos c ON c.fk_servicio = cs.id AND c.estado = 'ACTIVO';

-- 4) Reemplazar la función para que use el concepto de cada categoría
--    en lugar del ID fijo 1. Ver el cuerpo completo y comentado en
--    supabase/functions/fn_generar_deudas_ciclos_vencidos.sql
CREATE OR REPLACE FUNCTION public.fn_generar_deudas_ciclos_vencidos()
RETURNS void
LANGUAGE plpgsql
AS $function$
DECLARE
    v_ciclo record;
    v_inmueble record;
BEGIN
    FOR v_ciclo IN
        SELECT id_ciclos, descripcion, inicio
        FROM public.ciclos
        WHERE vencimiento <= CURRENT_DATE
          AND estado = 'ACTIVO'
    LOOP
        RAISE NOTICE 'Procesando ciclo: %', v_ciclo.descripcion;

        FOR v_inmueble IN
            SELECT
                i.id AS inmueble_id,
                c.id_concepto AS concepto_id,
                c.arancel AS monto
            FROM public.inmuebles i
            JOIN public.categoria_servicio cs ON i.fk_categoria_servicio = cs.id
            JOIN public.conceptos c ON c.fk_servicio = cs.id AND c.estado = 'ACTIVO'
            WHERE i.estado = 'CONECTADO'
              AND NOT EXISTS (
                  SELECT 1 FROM public.cuentas_cobrar cc
                  WHERE cc.fk_inmueble = i.id
                    AND cc.fk_ciclos = v_ciclo.id_ciclos
                    AND cc.fk_concepto = c.id_concepto
              )
        LOOP
            INSERT INTO public.cuentas_cobrar (
                fk_concepto,
                descripcion,
                monto,
                estado,
                fk_ciclos,
                fk_inmueble,
                saldo,
                pagado
            ) VALUES (
                v_inmueble.concepto_id,
                'Consumo mes: ' || v_ciclo.descripcion,
                v_inmueble.monto,
                'PENDIENTE',
                v_ciclo.id_ciclos,
                v_inmueble.inmueble_id,
                v_inmueble.monto,
                0
            );
        END LOOP;

        UPDATE public.ciclos
        SET estado = 'INACTIVO'
        WHERE id_ciclos = v_ciclo.id_ciclos;

        UPDATE public.ciclos
        SET estado = 'ACTIVO'
        WHERE id_ciclos = (
            SELECT id_ciclos
            FROM public.ciclos
            WHERE inicio > v_ciclo.inicio
              AND estado NOT IN ('ACTIVO', 'INACTIVO')
            ORDER BY inicio ASC
            LIMIT 1
        );

        RAISE NOTICE 'Ciclo % finalizado. Siguiente ciclo activado.', v_ciclo.descripcion;
    END LOOP;
END;
$function$;

-- 5) Verificación end-to-end (opcional, recomendado en un ciclo de prueba):
--    a) Forzar un ciclo de prueba con vencimiento = CURRENT_DATE y estado = 'ACTIVO'
--    b) Ejecutar manualmente:
--       SELECT public.fn_generar_deudas_ciclos_vencidos();
--    c) Revisar cuentas_cobrar: debe haber una fila por inmueble CONECTADO,
--       con fk_concepto correspondiente a su categoría y monto = tarifa_fija.
--    d) Re-ejecutar sobre el mismo ciclo y confirmar que NO se duplica.
--    e) Confirmar rotación de ciclos (INACTIVO -> siguiente ACTIVO).

-- 6) Confirmar que el job programado (jobid=2) sigue corriendo sin errores:
SELECT * FROM cron.job_run_details
WHERE jobid = 2
ORDER BY start_time DESC
LIMIT 5;
