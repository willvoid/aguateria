-- =====================================================================
-- Función: public.fn_generar_deudas_ciclos_vencidos
-- Agendada en pg_cron (jobid=2) para correr diariamente.
--
-- Al vencer un ciclo, genera en cuentas_cobrar el cargo mensual de cada
-- inmueble CONECTADO usando el concepto "Consumo" (fk_concepto=1, único
-- y común a todas las categorías) con monto = tarifa_fija de la
-- categoria_servicio del inmueble. Evita duplicar el cargo del mismo
-- ciclo, y rota el ciclo activo al siguiente.
--
-- El monto ya varía correctamente por categoría porque sale de
-- categoria_servicio.tarifa_fija, no del concepto: no hace falta un
-- concepto distinto por categoría (ver facturación manual en
-- lib/vista/facturacionvista/detallefacturawidget.dart, que sigue el
-- mismo criterio).
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

        -- 2. Seleccionamos inmuebles activos que NO tengan deuda de este ciclo
        FOR v_inmueble IN
            SELECT
                i.id AS inmueble_id,
                cs.tarifa_fija
            FROM public.inmuebles i
            JOIN public.categoria_servicio cs ON i.fk_categoria_servicio = cs.id
            WHERE i.estado = 'CONECTADO'
              AND NOT EXISTS (
                  SELECT 1 FROM public.cuentas_cobrar cc
                  WHERE cc.fk_inmueble = i.id
                    AND cc.fk_ciclos = v_ciclo.id_ciclos
                    AND cc.fk_concepto = 1
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
                1,
                'Consumo mes: ' || v_ciclo.descripcion,
                v_inmueble.tarifa_fija,
                'PENDIENTE',
                v_ciclo.id_ciclos,
                v_inmueble.inmueble_id,
                v_inmueble.tarifa_fija,
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
