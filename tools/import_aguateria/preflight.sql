-- Pre-flight de la importación de aguatería. SOLO LECTURA.
-- Ejecutar sección por sección en el SQL Editor, primero en PRUEBAS y luego en
-- PRODUCCIÓN, y pasar los resultados (el repo no trae el DDL base).

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

-- 7) Deudas ya cobradas desde el sistema (no se pueden pisar con el Excel)
SELECT count(*) AS deudas_con_pago
FROM public.cuentas_cobrar cc
WHERE EXISTS (SELECT 1 FROM public.pago_detalle_deuda p WHERE p.fk_deuda = cc.id_deuda);

-- 8) Cron: el job de deudas (jobid 2) no debe correr a mitad de la carga
SELECT jobid, schedule, command, active FROM cron.job;
SELECT start_time, status, return_message
FROM cron.job_run_details WHERE jobid = 2 ORDER BY start_time DESC LIMIT 5;
