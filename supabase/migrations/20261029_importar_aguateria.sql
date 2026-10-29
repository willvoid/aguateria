-- =====================================================================
-- Importación de datos de aguatería (clientes, inmuebles y deudas)
-- Ejecutar en orden, sección por sección, en el SQL Editor de Supabase.
--
-- Flujo:
--   1. tools/import_aguateria/importar.py genera out/staging.sql con los
--      datos del Excel ya normalizados y validados.
--   2. staging.sql se ejecuta en el SQL Editor: carga las tablas
--      import_aguateria_* (no toca clientes/inmuebles/cuentas_cobrar).
--   3. fn_importar_aguateria(lote) en modo prueba (por defecto) hace todo
--      el trabajo, verifica y DESHACE; devuelve el informe.
--   4. fn_importar_aguateria(lote, true, ...) hace lo mismo y confirma.
--   5. fn_revertir_importacion_aguateria(lote) deshace una importación
--      aplicada mientras sus deudas no tengan facturas o pagos.
--
-- La BD no tiene restricciones únicas en cod_inmueble, documento ni
-- (inmueble, ciclo, concepto): las garantiza esta función.
--
-- La función NO mezcla cargas: si algún cod_inmueble o documento del
-- lote ya existe, aborta. Vaciar los datos anteriores (con respaldo) antes.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1) Tablas de staging. Llevan cédulas y teléfonos: RLS activado y sin
--    políticas, para que no se lean por la API pública.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.import_aguateria_lote (
  id      uuid PRIMARY KEY,
  creado  timestamptz NOT NULL DEFAULT now(),
  archivo text,
  estado  text NOT NULL DEFAULT 'CARGADO'
          CHECK (estado IN ('CARGADO', 'APLICADO', 'REVERTIDO'))
);

CREATE TABLE IF NOT EXISTS public.import_aguateria_ciclos (
  lote uuid NOT NULL REFERENCES public.import_aguateria_lote(id) ON DELETE CASCADE,
  mes  text NOT NULL CHECK (mes ~ '^\d{4}-(0[1-9]|1[0-2])$'),
  PRIMARY KEY (lote, mes)
);

CREATE TABLE IF NOT EXISTS public.import_aguateria_clientes (
  lote           uuid NOT NULL REFERENCES public.import_aguateria_lote(id) ON DELETE CASCADE,
  clave          text NOT NULL,
  razon_social   text NOT NULL,
  documento      text NOT NULL,
  tipo_documento text NOT NULL CHECK (tipo_documento IN ('CI', 'RUC', 'SIN_TIPO')),
  celular        text NOT NULL DEFAULT '',
  PRIMARY KEY (lote, clave)
);

CREATE TABLE IF NOT EXISTS public.import_aguateria_inmuebles (
  lote          uuid NOT NULL REFERENCES public.import_aguateria_lote(id) ON DELETE CASCADE,
  cod_inmueble  text NOT NULL,
  estado        text NOT NULL CHECK (estado IN ('CONECTADO', 'DESCONECTADO')),
  tarifa        double precision NOT NULL CHECK (tarifa > 0),
  clave_cliente text,
  PRIMARY KEY (lote, cod_inmueble),
  FOREIGN KEY (lote, clave_cliente) REFERENCES public.import_aguateria_clientes (lote, clave)
);

CREATE TABLE IF NOT EXISTS public.import_aguateria_deudas (
  id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  lote         uuid NOT NULL,
  cod_inmueble text NOT NULL,
  concepto     integer NOT NULL CHECK (concepto IN (1, 2, 3)),
  ciclo        text,
  monto        double precision NOT NULL CHECK (monto > 0),
  saldo        double precision NOT NULL CHECK (saldo > 0 AND saldo <= monto),
  FOREIGN KEY (lote, cod_inmueble) REFERENCES public.import_aguateria_inmuebles (lote, cod_inmueble)
    ON DELETE CASCADE,
  CHECK ((concepto = 1) = (ciclo IS NOT NULL))
);
CREATE UNIQUE INDEX IF NOT EXISTS import_aguateria_deudas_uk
  ON public.import_aguateria_deudas (lote, cod_inmueble, concepto, COALESCE(ciclo, ''));

-- Qué filas creó cada lote: permite deshacerlo.
CREATE TABLE IF NOT EXISTS public.import_aguateria_registro (
  lote  uuid NOT NULL REFERENCES public.import_aguateria_lote(id) ON DELETE CASCADE,
  tabla text NOT NULL,
  pk    bigint NOT NULL,
  PRIMARY KEY (lote, tabla, pk)
);

ALTER TABLE public.import_aguateria_lote      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.import_aguateria_ciclos    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.import_aguateria_clientes  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.import_aguateria_inmuebles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.import_aguateria_deudas    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.import_aguateria_registro  ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------
-- 2) Núcleo: hace el trabajo y verifica. Lanza excepción ante cualquier
--    incongruencia. No se llama directamente: usar fn_importar_aguateria.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_importar_aguateria_core(
  p_lote              uuid,
  p_barrio            bigint,
  p_tipo_operacion    bigint,
  p_tipo_documento_ci bigint,
  p_ciclos            jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
AS $function$
DECLARE
  v_meses    text[] := ARRAY['Enero','Febrero','Marzo','Abril','Mayo','Junio','Julio',
                             'Agosto','Septiembre','Octubre','Noviembre','Diciembre'];
  v_estado   text;
  v_txt      text;
  v_n        bigint;
  v_num      double precision;
  v_id       bigint;
  v_cand     bigint[];
  v_exactos  bigint[];
  v_anio     integer;
  v_mes_num  integer;
  v_inicio   date;
  r          record;
  v_creados  jsonb := '[]'::jsonb;
  v_guarda   bigint;
  v_aviso    jsonb := '[]'::jsonb;
  v_rep_ok   boolean := false;
  v_anio_rep integer := extract(year FROM current_date)::integer;
BEGIN
  -- 0. Lote y parámetros
  SELECT estado INTO v_estado FROM public.import_aguateria_lote WHERE id = p_lote FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'El lote % no existe', p_lote;
  END IF;
  IF v_estado <> 'CARGADO' THEN
    RAISE EXCEPTION 'El lote % está en estado %; solo se importa un lote CARGADO', p_lote, v_estado;
  END IF;
  IF p_barrio IS NULL OR NOT EXISTS (SELECT 1 FROM public.barrios WHERE cod_barrio = p_barrio) THEN
    RAISE EXCEPTION 'Indique un barrio válido (p_barrio = cod_barrio); recibido: %', p_barrio;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.tipo_operacion WHERE id_tipo_operacion = p_tipo_operacion) THEN
    RAISE EXCEPTION 'Tipo de operación % no existe', p_tipo_operacion;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.tipo_documento WHERE cod_tipodoc = p_tipo_documento_ci) THEN
    RAISE EXCEPTION 'Tipo de documento % no existe', p_tipo_documento_ci;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.import_aguateria_inmuebles WHERE lote = p_lote) THEN
    RAISE EXCEPTION 'El lote % no tiene inmuebles', p_lote;
  END IF;

  -- Nadie más escribe mientras dura la carga (el cron o la app crearían duplicados).
  LOCK TABLE public.cuentas_cobrar, public.inmuebles, public.clientes IN SHARE ROW EXCLUSIVE MODE;

  -- 1. No se mezcla con datos existentes
  SELECT string_agg(cod_inmueble, ', ') INTO v_txt FROM (
    SELECT s.cod_inmueble FROM public.import_aguateria_inmuebles s
    JOIN public.inmuebles i ON i.cod_inmueble = s.cod_inmueble
    WHERE s.lote = p_lote ORDER BY 1 LIMIT 10) x;
  IF v_txt IS NOT NULL THEN
    RAISE EXCEPTION 'Ya existen inmuebles con estos códigos (primeros 10): %. Vacíe los datos anteriores antes de importar.', v_txt;
  END IF;
  SELECT string_agg(documento, ', ') INTO v_txt FROM (
    SELECT DISTINCT s.documento FROM public.import_aguateria_clientes s
    JOIN public.clientes c ON c.documento = s.documento
    WHERE s.lote = p_lote AND s.documento <> '0' ORDER BY 1 LIMIT 10) x;
  IF v_txt IS NOT NULL THEN
    RAISE EXCEPTION 'Ya existen clientes con estos documentos (primeros 10): %. Vacíe los datos anteriores antes de importar.', v_txt;
  END IF;

  -- 2. Cada tarifa del lote debe corresponder a una sola categoría
  FOR r IN SELECT DISTINCT tarifa FROM public.import_aguateria_inmuebles WHERE lote = p_lote LOOP
    SELECT count(*) INTO v_n FROM public.categoria_servicio WHERE tarifa_fija = r.tarifa;
    IF v_n <> 1 THEN
      RAISE EXCEPTION 'La tarifa % corresponde a % categorías de servicio (debe ser exactamente 1)', r.tarifa, v_n;
    END IF;
  END LOOP;

  -- 3. Ciclos: uno por mes del Excel, mismo criterio que reporte_deudas (anio + mes de inicio)
  DROP TABLE IF EXISTS tmp_ciclos_imp;
  CREATE TEMP TABLE tmp_ciclos_imp (mes text PRIMARY KEY, id_ciclos bigint NOT NULL) ON COMMIT DROP;

  FOR r IN SELECT mes FROM public.import_aguateria_ciclos WHERE lote = p_lote ORDER BY mes LOOP
    v_anio := split_part(r.mes, '-', 1)::integer;
    v_mes_num := split_part(r.mes, '-', 2)::integer;

    IF p_ciclos ? r.mes THEN
      v_id := (p_ciclos ->> r.mes)::bigint;
      IF NOT EXISTS (SELECT 1 FROM public.ciclos WHERE id_ciclos = v_id) THEN
        RAISE EXCEPTION 'p_ciclos indica el ciclo % para %, pero no existe', v_id, r.mes;
      END IF;
    ELSE
      SELECT array_agg(id_ciclos ORDER BY id_ciclos), array_agg(id_ciclos) FILTER (WHERE ciclo = r.mes)
        INTO v_cand, v_exactos
      FROM public.ciclos
      WHERE anio = v_anio AND extract(month FROM inicio) = v_mes_num;

      IF v_cand IS NULL THEN
        v_inicio := make_date(v_anio, v_mes_num, 1);
        INSERT INTO public.ciclos (ciclo, descripcion, anio, inicio, fin, vencimiento, estado)
        VALUES (r.mes, v_meses[v_mes_num] || ' ' || v_anio, v_anio, v_inicio,
                (v_inicio + interval '1 month - 1 day')::date,
                (v_inicio + interval '1 month - 1 day')::date, 'INACTIVO')
        RETURNING id_ciclos INTO v_id;
        INSERT INTO public.import_aguateria_registro VALUES (p_lote, 'ciclos', v_id);
        v_creados := v_creados || to_jsonb(r.mes);
      ELSIF cardinality(v_cand) = 1 THEN
        v_id := v_cand[1];
      ELSIF cardinality(v_exactos) = 1 THEN
        v_id := v_exactos[1];
      ELSE
        RAISE EXCEPTION 'Hay varios ciclos para % (ids %). Indique cuál usar en p_ciclos, por ejemplo {"%": %}',
          r.mes, v_cand, r.mes, v_cand[1];
      END IF;
    END IF;
    INSERT INTO tmp_ciclos_imp VALUES (r.mes, v_id);
  END LOOP;

  IF EXISTS (SELECT 1 FROM public.import_aguateria_deudas d
             WHERE d.lote = p_lote AND d.ciclo IS NOT NULL
               AND NOT EXISTS (SELECT 1 FROM tmp_ciclos_imp t WHERE t.mes = d.ciclo)) THEN
    RAISE EXCEPTION 'Hay deudas con meses que no figuran en import_aguateria_ciclos';
  END IF;

  -- 4. Clientes
  DROP TABLE IF EXISTS tmp_cli_imp;
  CREATE TEMP TABLE tmp_cli_imp (clave text PRIMARY KEY, id bigint NOT NULL) ON COMMIT DROP;
  FOR r IN SELECT * FROM public.import_aguateria_clientes WHERE lote = p_lote ORDER BY clave LOOP
    INSERT INTO public.clientes (razon_social, documento, celular, es_proveedor_del_estado, nro_casa,
                                 fk_tipo_operacion, estado_cliente, fk_tipo_documento, fk_barrios)
    VALUES (r.razon_social, r.documento, r.celular, false, 0, p_tipo_operacion, 'ACTIVO',
            CASE WHEN r.tipo_documento = 'CI' THEN p_tipo_documento_ci END, p_barrio)
    RETURNING id_cliente INTO v_id;
    INSERT INTO tmp_cli_imp VALUES (r.clave, v_id);
    INSERT INTO public.import_aguateria_registro VALUES (p_lote, 'clientes', v_id);
  END LOOP;

  -- 5. Inmuebles (direccion '' porque el modelo de la app no admite null)
  DROP TABLE IF EXISTS tmp_inm_imp;
  CREATE TEMP TABLE tmp_inm_imp (cod text PRIMARY KEY, id bigint NOT NULL, tarifa double precision NOT NULL,
                                 estado text NOT NULL) ON COMMIT DROP;
  FOR r IN SELECT i.*, c.id AS id_cliente
           FROM public.import_aguateria_inmuebles i
           LEFT JOIN tmp_cli_imp c ON c.clave = i.clave_cliente
           WHERE i.lote = p_lote ORDER BY i.cod_inmueble LOOP
    INSERT INTO public.inmuebles (cod_inmueble, estado, direccion, fk_cliente, fk_categoria_servicio)
    VALUES (r.cod_inmueble, r.estado, '', r.id_cliente,
            (SELECT id FROM public.categoria_servicio WHERE tarifa_fija = r.tarifa))
    RETURNING id INTO v_id;
    INSERT INTO tmp_inm_imp VALUES (r.cod_inmueble, v_id, r.tarifa, r.estado);
    INSERT INTO public.import_aguateria_registro VALUES (p_lote, 'inmuebles', v_id);
  END LOOP;

  -- 6. Deudas del Excel. El trigger tr_deuda_cambio_estado normaliza el estado.
  WITH ins AS (
    INSERT INTO public.cuentas_cobrar (fk_concepto, descripcion, monto, estado, fk_ciclos,
                                       fk_inmueble, saldo, pagado)
    SELECT d.concepto,
           CASE d.concepto WHEN 1 THEN 'Consumo mes: ' || c.descripcion
                           WHEN 2 THEN 'Conexión' ELSE 'Deuda anterior' END,
           d.monto,
           CASE WHEN d.saldo >= d.monto THEN 'PENDIENTE' ELSE 'PAGO_PARCIAL' END,
           t.id_ciclos, i.id, d.saldo, d.monto - d.saldo
    FROM public.import_aguateria_deudas d
    JOIN tmp_inm_imp i ON i.cod = d.cod_inmueble
    LEFT JOIN tmp_ciclos_imp t ON t.mes = d.ciclo
    LEFT JOIN public.ciclos c ON c.id_ciclos = t.id_ciclos
    WHERE d.lote = p_lote
    RETURNING id_deuda)
  INSERT INTO public.import_aguateria_registro SELECT p_lote, 'cuentas_cobrar', id_deuda FROM ins;

  -- 7. Protección contra el cron: en el ciclo ACTIVO, el inmueble conectado
  --    sin cargo en el Excel queda con su Consumo PAGADO. Si no, el cron
  --    (fn_generar_deudas_ciclos_vencidos) le generaría un cargo nuevo al vencer.
  WITH ins AS (
    INSERT INTO public.cuentas_cobrar (fk_concepto, descripcion, monto, estado, fk_ciclos,
                                       fk_inmueble, saldo, pagado)
    SELECT 1, 'Consumo mes: ' || c.descripcion, i.tarifa, 'PAGADO', c.id_ciclos, i.id, 0, i.tarifa
    FROM tmp_ciclos_imp t
    JOIN public.ciclos c ON c.id_ciclos = t.id_ciclos AND c.estado = 'ACTIVO'
    CROSS JOIN tmp_inm_imp i
    WHERE i.estado = 'CONECTADO'
      AND NOT EXISTS (SELECT 1 FROM public.cuentas_cobrar x
                      WHERE x.fk_inmueble = i.id AND x.fk_ciclos = c.id_ciclos AND x.fk_concepto = 1)
    RETURNING id_deuda)
  INSERT INTO public.import_aguateria_registro SELECT p_lote, 'cuentas_cobrar', id_deuda FROM ins;
  GET DIAGNOSTICS v_guarda = ROW_COUNT;

  -- ===================== VERIFICACIONES =====================
  -- A. saldo = monto - pagado, saldo >= 0 y estado coherente con el saldo
  SELECT count(*), string_agg(id_deuda::text, ', ') INTO v_n, v_txt FROM (
    SELECT cc.id_deuda FROM public.cuentas_cobrar cc
    JOIN public.import_aguateria_registro g
      ON g.lote = p_lote AND g.tabla = 'cuentas_cobrar' AND g.pk = cc.id_deuda
    WHERE abs(cc.saldo - (cc.monto - cc.pagado)) > 0.001
       OR cc.saldo < 0 OR cc.pagado < 0
       OR (cc.saldo = 0 AND cc.estado <> 'PAGADO')
       OR (cc.saldo > 0 AND cc.saldo < cc.monto AND cc.estado <> 'PAGO_PARCIAL')
       OR (cc.saldo >= cc.monto AND cc.estado <> 'PENDIENTE')
    ORDER BY 1 LIMIT 10) x;
  IF v_n > 0 THEN
    RAISE EXCEPTION 'Deudas con saldo/estado incoherente (ids, máx. 10): %', v_txt;
  END IF;

  -- B. Una sola fila de Consumo por (inmueble, ciclo); una de Conexión y una de Deuda anterior por inmueble
  SELECT count(*), string_agg(cod, ', ') INTO v_n, v_txt FROM (
    SELECT i.cod FROM tmp_inm_imp i
    JOIN public.cuentas_cobrar cc ON cc.fk_inmueble = i.id AND cc.fk_concepto IN (1, 2, 3)
    GROUP BY i.cod, cc.fk_concepto, cc.fk_ciclos
    HAVING count(*) > 1 ORDER BY 1 LIMIT 10) x;
  IF v_n > 0 THEN
    RAISE EXCEPTION 'Deudas duplicadas por inmueble/concepto/ciclo en los inmuebles (máx. 10): %', v_txt;
  END IF;

  -- C. cod_inmueble sin duplicados en toda la tabla
  SELECT string_agg(cod_inmueble, ', ') INTO v_txt FROM (
    SELECT cod_inmueble FROM public.inmuebles
    GROUP BY cod_inmueble HAVING count(*) > 1 ORDER BY 1 LIMIT 10) x;
  IF v_txt IS NOT NULL THEN
    RAISE EXCEPTION 'cod_inmueble duplicado en inmuebles: %', v_txt;
  END IF;

  -- D. Por inmueble, el saldo cargado = el saldo del Excel
  DROP TABLE IF EXISTS tmp_esp_imp;
  CREATE TEMP TABLE tmp_esp_imp ON COMMIT DROP AS
    SELECT i.cod, i.id,
           COALESCE(sum(d.saldo), 0)::double precision AS total,
           COALESCE(sum(d.saldo) FILTER (WHERE d.concepto = 2), 0)::double precision AS conexion,
           COALESCE(sum(d.saldo) FILTER (WHERE d.concepto = 3), 0)::double precision AS anterior
    FROM tmp_inm_imp i
    LEFT JOIN public.import_aguateria_deudas d ON d.lote = p_lote AND d.cod_inmueble = i.cod
    GROUP BY i.cod, i.id;

  SELECT count(*), string_agg(cod, ', ') INTO v_n, v_txt FROM (
    SELECT e.cod FROM tmp_esp_imp e
    LEFT JOIN (SELECT fk_inmueble, sum(saldo) AS s FROM public.cuentas_cobrar
               WHERE fk_concepto IN (1, 2, 3) GROUP BY 1) cc ON cc.fk_inmueble = e.id
    WHERE abs(COALESCE(cc.s, 0) - e.total) > 0.5
    ORDER BY 1 LIMIT 10) x;
  IF v_n > 0 THEN
    RAISE EXCEPTION 'El saldo cargado difiere del Excel en estos inmuebles (máx. 10): %', v_txt;
  END IF;

  -- E. Control cruzado con el reporte de deudas del año en curso (si está instalado)
  IF to_regprocedure('public.reporte_deudas(integer)') IS NOT NULL THEN
    EXECUTE format($q$
      SELECT count(*), string_agg(cod, ', ') FROM (
        SELECT e.cod
        FROM tmp_esp_imp e
        LEFT JOIN public.reporte_deudas(%1$s) r ON r.id_inmueble = e.cod
        WHERE r.id_inmueble IS NULL
           OR abs(r.deuda_total - e.total) > 0.5
           OR abs(r.conexion - e.conexion) > 0.5
           OR abs(r.deuda_anterior - e.anterior) > 0.5
        ORDER BY 1 LIMIT 10) x$q$, v_anio_rep) INTO v_n, v_txt;
    IF v_n > 0 THEN
      RAISE EXCEPTION 'reporte_deudas(%) no coincide con el Excel en estos inmuebles (máx. 10): %', v_anio_rep, v_txt;
    END IF;

    -- el Consumo por mes del año del reporte también debe coincidir
    EXECUTE format($q$
      SELECT COALESCE(sum(r.enero + r.febrero + r.marzo + r.abril + r.mayo + r.junio + r.julio
                          + r.agosto + r.septiembre + r.octubre + r.noviembre + r.diciembre), 0)
      FROM public.reporte_deudas(%1$s) r JOIN tmp_esp_imp e ON e.cod = r.id_inmueble$q$, v_anio_rep)
      INTO v_num;
    IF abs(v_num - COALESCE((SELECT sum(d.saldo) FROM public.import_aguateria_deudas d
                           WHERE d.lote = p_lote AND d.concepto = 1
                             AND d.ciclo LIKE v_anio_rep::text || '-%'), 0)) > 0.5 THEN
      RAISE EXCEPTION 'El Consumo del año % en reporte_deudas (%) no coincide con el Excel', v_anio_rep, v_num;
    END IF;
    v_rep_ok := true;
  ELSE
    v_aviso := v_aviso || to_jsonb('reporte_deudas(integer) no está instalada: sin control cruzado con el reporte'::text);
  END IF;

  -- Avisos (no abortan)
  SELECT string_agg(c.ciclo, ', ') INTO v_txt
  FROM public.ciclos c
  WHERE c.estado = 'ACTIVO' AND c.vencimiento <= current_date
    AND c.id_ciclos NOT IN (SELECT id_ciclos FROM tmp_ciclos_imp);
  IF v_txt IS NOT NULL THEN
    v_aviso := v_aviso || to_jsonb('Ciclos ACTIVOS ya vencidos fuera del Excel (el cron los facturará): ' || v_txt);
  END IF;
  IF to_regclass('cron.job') IS NOT NULL THEN
    EXECUTE $q$SELECT count(*) FROM cron.job WHERE active AND command ILIKE '%fn_generar_deudas_ciclos_vencidos%'$q$
      INTO v_n;
    IF v_n > 0 THEN
      v_aviso := v_aviso || to_jsonb('El cron de deudas está activo: pausarlo durante la carga (SELECT cron.alter_job(<jobid>, active := false))'::text);
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'clientes',        (SELECT count(*) FROM tmp_cli_imp),
    'inmuebles',       (SELECT count(*) FROM tmp_inm_imp),
    'cuentas_cobrar',  (SELECT count(*) FROM public.import_aguateria_registro
                        WHERE lote = p_lote AND tabla = 'cuentas_cobrar'),
    'cuentas_pagadas_ciclo_activo', v_guarda,
    'ciclos',          (SELECT jsonb_object_agg(mes, id_ciclos) FROM tmp_ciclos_imp),
    'ciclos_creados',  v_creados,
    'saldo_total',     (SELECT COALESCE(sum(total), 0) FROM tmp_esp_imp),
    'saldo_conexion',  (SELECT COALESCE(sum(conexion), 0) FROM tmp_esp_imp),
    'saldo_deuda_anterior', (SELECT COALESCE(sum(anterior), 0) FROM tmp_esp_imp),
    'verificado_con_reporte_deudas', v_rep_ok,
    'advertencias',    v_aviso);
END;
$function$;

-- ---------------------------------------------------------------------
-- 3) Punto de entrada. Por defecto es una PRUEBA: hace todo, verifica y
--    deshace; devuelve el informe. Con p_aplicar = true confirma.
--
--    SELECT public.fn_importar_aguateria('<lote>', false, <cod_barrio>);
--    SELECT public.fn_importar_aguateria('<lote>', true,  <cod_barrio>);
--
--    p_ciclos fija el ciclo de un mes cuando hay varios candidatos
--    (por ejemplo ciclos de prueba): '{"2026-02": 3}'::jsonb
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_importar_aguateria(
  p_lote              uuid,
  p_aplicar           boolean DEFAULT false,
  p_barrio            bigint  DEFAULT NULL,
  p_tipo_operacion    bigint  DEFAULT 1,
  p_tipo_documento_ci bigint  DEFAULT 1,
  p_ciclos            jsonb   DEFAULT '{}'::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
AS $function$
DECLARE
  v_rep jsonb;
BEGIN
  BEGIN
    v_rep := public.fn_importar_aguateria_core(p_lote, p_barrio, p_tipo_operacion,
                                               p_tipo_documento_ci, p_ciclos);
    v_rep := v_rep || jsonb_build_object('aplicado', p_aplicar);
    IF p_aplicar THEN
      UPDATE public.import_aguateria_lote SET estado = 'APLICADO' WHERE id = p_lote;
      RETURN v_rep;
    END IF;
    -- Prueba: este error deshace todo lo hecho dentro del bloque.
    RAISE EXCEPTION USING ERRCODE = 'AG001', MESSAGE = 'prueba de importación';
  EXCEPTION WHEN SQLSTATE 'AG001' THEN
    RETURN v_rep;
  END;
END;
$function$;

-- ---------------------------------------------------------------------
-- 4) Deshacer una importación aplicada. Se niega si alguna deuda
--    importada ya tiene facturas o pagos.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_revertir_importacion_aguateria(p_lote uuid)
RETURNS jsonb
LANGUAGE plpgsql
AS $function$
DECLARE
  v_estado text;
  v_n      bigint;
  v_cc     bigint;
  v_inm    bigint;
  v_cli    bigint;
  v_cic    bigint;
BEGIN
  SELECT estado INTO v_estado FROM public.import_aguateria_lote WHERE id = p_lote FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'El lote % no existe', p_lote;
  END IF;
  IF v_estado <> 'APLICADO' THEN
    RAISE EXCEPTION 'El lote % está en estado %; solo se revierte un lote APLICADO', p_lote, v_estado;
  END IF;

  LOCK TABLE public.cuentas_cobrar, public.inmuebles, public.clientes IN SHARE ROW EXCLUSIVE MODE;

  SELECT count(*) INTO v_n FROM public.detalle_factura df
  WHERE df.fk_deudas IN (SELECT pk FROM public.import_aguateria_registro
                         WHERE lote = p_lote AND tabla = 'cuentas_cobrar');
  IF v_n > 0 THEN
    RAISE EXCEPTION 'No se puede revertir: % detalles de factura referencian deudas importadas', v_n;
  END IF;
  IF to_regclass('public.pago_detalle_deuda') IS NOT NULL THEN
    EXECUTE $q$SELECT count(*) FROM public.pago_detalle_deuda
                WHERE fk_deuda IN (SELECT pk FROM public.import_aguateria_registro
                                   WHERE lote = $1 AND tabla = 'cuentas_cobrar')$q$
      USING p_lote INTO v_n;
    IF v_n > 0 THEN
      RAISE EXCEPTION 'No se puede revertir: % pagos referencian deudas importadas', v_n;
    END IF;
  END IF;

  DELETE FROM public.cuentas_cobrar
  WHERE id_deuda IN (SELECT pk FROM public.import_aguateria_registro
                     WHERE lote = p_lote AND tabla = 'cuentas_cobrar');
  GET DIAGNOSTICS v_cc = ROW_COUNT;
  DELETE FROM public.inmuebles
  WHERE id IN (SELECT pk FROM public.import_aguateria_registro
               WHERE lote = p_lote AND tabla = 'inmuebles');
  GET DIAGNOSTICS v_inm = ROW_COUNT;
  DELETE FROM public.clientes
  WHERE id_cliente IN (SELECT pk FROM public.import_aguateria_registro
                       WHERE lote = p_lote AND tabla = 'clientes');
  GET DIAGNOSTICS v_cli = ROW_COUNT;
  DELETE FROM public.ciclos
  WHERE id_ciclos IN (SELECT pk FROM public.import_aguateria_registro
                      WHERE lote = p_lote AND tabla = 'ciclos');
  GET DIAGNOSTICS v_cic = ROW_COUNT;

  UPDATE public.import_aguateria_lote SET estado = 'REVERTIDO' WHERE id = p_lote;
  RETURN jsonb_build_object('cuentas_cobrar', v_cc, 'inmuebles', v_inm,
                            'clientes', v_cli, 'ciclos', v_cic);
END;
$function$;

-- ---------------------------------------------------------------------
-- 5) Solo el rol de servicio / SQL Editor puede ejecutarlas (por la API
--    pública, anon y authenticated podrían cargar o borrar datos).
-- ---------------------------------------------------------------------
DO $$
DECLARE
  v_rol text;
BEGIN
  FOREACH v_rol IN ARRAY ARRAY['anon', 'authenticated'] LOOP
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = v_rol) THEN
      EXECUTE format('REVOKE ALL ON FUNCTION public.fn_importar_aguateria_core(uuid, bigint, bigint, bigint, jsonb) FROM %I', v_rol);
      EXECUTE format('REVOKE ALL ON FUNCTION public.fn_importar_aguateria(uuid, boolean, bigint, bigint, bigint, jsonb) FROM %I', v_rol);
      EXECUTE format('REVOKE ALL ON FUNCTION public.fn_revertir_importacion_aguateria(uuid) FROM %I', v_rol);
      EXECUTE format('REVOKE ALL ON TABLE public.import_aguateria_lote, public.import_aguateria_ciclos, public.import_aguateria_clientes, public.import_aguateria_inmuebles, public.import_aguateria_deudas, public.import_aguateria_registro FROM %I', v_rol);
    END IF;
  END LOOP;
END $$;
REVOKE ALL ON FUNCTION public.fn_importar_aguateria_core(uuid, bigint, bigint, bigint, jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_importar_aguateria(uuid, boolean, bigint, bigint, bigint, jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_revertir_importacion_aguateria(uuid) FROM PUBLIC;
