-- Pre-flight de la importación de aguatería. SOLO LECTURA.
-- Ejecutar sección por sección en el SQL Editor, primero en PRUEBAS y luego en
-- PRODUCCIÓN, y pasar los resultados (el repo no trae el DDL base).

-- 0) ¿Existen en este servidor las tablas que usa la app? (los servidores de
--    desarrollo pueden ir por detrás del código)
SELECT n.tabla, to_regclass('public.' || n.tabla) IS NOT NULL AS existe
FROM (VALUES ('clientes'), ('inmuebles'), ('cuentas_cobrar'), ('ciclos'), ('conceptos'),
             ('categoria_servicio'), ('barrios'), ('tipo_operacion'), ('tipo_documento'),
             ('pago_detalle_deuda'), ('detalle_factura'), ('facturas'), ('pagos')) AS n(tabla)
ORDER BY existe, n.tabla;

-- 1) Columnas, NOT NULL y defaults de las tablas que se van a escribir
SELECT table_name, column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name IN ('clientes', 'inmuebles', 'cuentas_cobrar', 'ciclos')
ORDER BY table_name, ordinal_position;

-- 2) Restricciones (únicos, FKs, checks) de esas tablas
SELECT conrelid::regclass AS tabla, conname, pg_get_constraintdef(oid) AS definicion
FROM pg_constraint
WHERE conrelid IN ('public.clientes'::regclass, 'public.inmuebles'::regclass,
                   'public.cuentas_cobrar'::regclass, 'public.ciclos'::regclass)
ORDER BY 1, 2;

-- 3) Triggers sobre esas tablas (pueden recalcular saldo/estado al insertar)
SELECT event_object_table AS tabla, trigger_name, action_timing, event_manipulation, action_statement
FROM information_schema.triggers
WHERE trigger_schema = 'public'
  AND event_object_table IN ('clientes', 'inmuebles', 'cuentas_cobrar', 'ciclos');

-- 4) Catálogos que el Excel no trae y que hay que elegir
SELECT * FROM public.categoria_servicio ORDER BY id;
SELECT * FROM public.barrios ORDER BY 1;
SELECT * FROM public.tipo_operacion ORDER BY 1;
SELECT * FROM public.tipo_documento ORDER BY 1;
SELECT id_concepto, nombre, arancel, estado, permite_cuotas
FROM public.conceptos ORDER BY id_concepto;

-- 5) Ciclos de sep-2025 a oct-2026: ¿existen todos?, estado y vencimiento
SELECT id_ciclos, ciclo, descripcion, anio, inicio, fin, vencimiento, estado
FROM public.ciclos
WHERE inicio >= '2025-09-01' AND inicio < '2026-12-01'
ORDER BY inicio;

-- 6) Datos que ya hay (cuánto se va a reemplazar)
SELECT 'clientes' AS tabla, count(*) FROM public.clientes
UNION ALL SELECT 'inmuebles', count(*) FROM public.inmuebles
UNION ALL SELECT 'cuentas_cobrar', count(*) FROM public.cuentas_cobrar;

SELECT fk_concepto, estado, count(*) AS filas, sum(saldo) AS saldo
FROM public.cuentas_cobrar
GROUP BY 1, 2 ORDER BY 1, 2;

-- 7) Deudas ya cobradas desde el sistema (no se pueden pisar con el Excel).
--    Tolera servidores desactualizados: si una tabla no existe devuelve 'NO EXISTE'
--    en vez de fallar (el código de la app usa pago_detalle_deuda y detalle_factura.fk_deudas).
SELECT t.tabla,
       CASE WHEN to_regclass('public.' || t.tabla) IS NULL THEN 'NO EXISTE'
            ELSE (xpath('/row/n/text()', query_to_xml(t.consulta, false, true, '')))[1]::text
       END AS deudas_con_registros
FROM (VALUES
  ('pago_detalle_deuda',
   'SELECT count(DISTINCT fk_deuda) AS n FROM public.pago_detalle_deuda'),
  ('detalle_factura',
   'SELECT count(DISTINCT fk_deudas) AS n FROM public.detalle_factura WHERE fk_deudas IS NOT NULL')
) AS t(tabla, consulta);

-- 8) Cron: el job de deudas (jobid 2) no debe correr a mitad de la carga
SELECT jobid, schedule, command, active FROM cron.job;
SELECT start_time, status, return_message
FROM cron.job_run_details WHERE jobid = 2 ORDER BY start_time DESC LIMIT 5;
