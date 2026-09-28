-- =====================================================================
-- Función: public.fn_generar_deudas_ciclos_vencidos
-- Agendada en pg_cron (jobid=2) para correr diariamente.
--
-- Al vencer un ciclo, genera en cuentas_cobrar el cargo mensual de cada
-- inmueble CONECTADO según el concepto asociado a su categoria_servicio
-- (conceptos.fk_servicio -> categoria_servicio.id), evita duplicar el
-- cargo del mismo ciclo, y rota el ciclo activo al siguiente.
--
-- Requiere que cada categoria_servicio tenga un concepto ACTIVO con
-- fk_servicio = categoria_servicio.id (ver supabase/migrations para el
-- backfill inicial).
-- =====================================================================

CREATE OR REPLACE FUNCTION public.fn_generar_deudas_ciclos_vencidos()
RETURNS void
LANGUAGE plpgsql
AS $function$
DECLARE
    v_ciclo record;
    v_inmueble record;
BEGIN
    -- 1. Buscamos ciclos que vencen hoy o antes y que sigan activos
    FOR v_ciclo IN
        SELECT id_ciclos, descripcion, inicio
        FROM public.ciclos
        WHERE vencimiento <= CURRENT_DATE
          AND estado = 'ACTIVO'
    LOOP
        RAISE NOTICE 'Procesando ciclo: %', v_ciclo.descripcion;

        -- 2. Seleccionamos inmuebles activos, con su concepto según categoría,
        --    que NO tengan deuda de este ciclo para ese concepto
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
            -- 3. Insertamos la deuda directamente como PENDIENTE
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

        -- 4. Marcamos el ciclo actual como INACTIVO
        UPDATE public.ciclos
        SET estado = 'INACTIVO'
        WHERE id_ciclos = v_ciclo.id_ciclos;

        -- 5. Activamos el siguiente ciclo cronológico disponible
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
