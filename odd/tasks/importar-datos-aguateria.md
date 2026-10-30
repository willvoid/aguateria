# importar-datos-aguateria

Objective: load `DATOS DE AGUATERÍA ACTUAL 2510.xlsx` (corte 25/10/2026) into Supabase without inconsistencies. Excel wins over old data, with backup first.

## Decisions
- Concepts by ID: 1 Consumo, 2 Conexión, 3 Deuda anterior (same as `reporte_deudas`).
- Col E with two amounts: first = Deuda anterior, second = Conexión. One amount: manual review (`revision_E.csv`).
- Sep-2025 above the tarifa: tarifa stays in Consumo, the rest goes to Deuda anterior.
- RUC (`4125450-3`, `4.237.043-4` -> `4237043-4`) and no document (`'0'`): `tipo_documento` null.
- `USUARIO CORTADO`, `TAPONADO`, `CONEXIÓN CORTADA` -> inmueble DESCONECTADO.
- Celular: digits only, no hyphen, always in `celular`; `telefono` empty.
- Codes 302-306 are duplicated in the Excel (rows 346-350 are other houses): renumbered 338-342 via `fila:N,cod_nuevo` in `decisiones.csv` (the `/1` suffix is taken: `304/1`, `305/1` exist).
- Col E single amount: font colour decides, black = Conexión (2), red = Deuda anterior (3), any other colour blocks. 93 black, 13 red.
- Inmuebles 196, 311, 315 are Lavadero (`tarifa 50000`): Consumo monto is 25.000 before the first month with 50.000 and 50.000 from there.
- Barrio for everyone: IPVU (`cod_barrio` 447).
- The function does not merge with existing data: it aborts if any `cod_inmueble` or documento already exists. DEV is wiped; PROD gets a backup and the same wipe before loading.
- Dev categories: 1 Estandar 25.000, 2 Lavadero 50.000.
- An ACTIVO ciclo (Oct 2026 in dev) gets a PAGADO Consumo for connected inmuebles without a charge in the Excel, otherwise the cron charges them again on due date.
- Personal data (xlsx, `out/`) is never committed.

## Tasks
- [x] T1 `tools/import_aguateria/importar.py` + `test_importar.py` (offline parse, reports, totals) — route: inline
- [x] T2 `tools/import_aguateria/preflight.sql` (read-only checks on schema, catalogs, ciclos, cron) — route: inline
- [ ] T3 User runs `preflight.sql` on TEST and PROD and shares the results
- [x] T4 Decisions closed in `decisiones.csv` (302-306, Lavadero, col E colours); real Excel parses with 0 blocking problems
- [x] T5 Migration `supabase/migrations/20261029_importar_aguateria.sql`: staging tables + `fn_importar_aguateria(lote, aplicar, barrio, ...)` with dry-run, invariants and `fn_revertir_importacion_aguateria` — tested on local Postgres with a replica of the DEV schema (`tools/import_aguateria/test_sql/run_tests.sh`)
- [x] T6 Staging generator (`importar.py` writes `out/staging.sql` only when there are no blocking problems)
- [ ] T7 DEV run: wipe dev data, load staging, dry-run, apply, compare with `reporte_deudas(2026)`
- [ ] T8 PROD: run `preflight.sql` there first (the dump pasted so far is DEV); backup, wipe old data, same steps

## Evidence
- `python3 -m unittest test_importar` (in `tools/import_aguateria`): 19 passed.
- Real Excel: 376 inmuebles read (5 skipped by duplicated code), 354 clientes, 1321 deudas, 113 blocking problems (102 DEUDA without concept, 6 months above tarifa, 5 duplicated codes).
- `tools/import_aguateria/test_sql/run_tests.sh` (Postgres 16 + dev schema replica, synthetic fixture): all ok — dry-run leaves no rows, apply, reporte_deudas matches, cron does not duplicate the active ciclo, no double apply, revert refused when invoiced, revert OK.
- Real Excel (copy with 302-306 renamed, test decisions): 381 inmuebles, 359 clientes, 1473 cuentas_cobrar; reporte_deudas(2026) totals equal the Excel; simulated cron added 0 rows (and 37 without the guard rows).
- Real Excel, final decisions: 0 blocking, 68 warnings; 381 inmuebles, 359 clientes, 1485 cuentas_cobrar (incl. 37 PAGADO guard rows). Totals: Consumo 32.840.000, Conexión 44.304.000, Deuda anterior 17.505.000, total 94.649.000 — same as an independent script and as `reporte_deudas(2026)`; cron simulation added 0 rows; revert OK. 30 python tests + `run_tests.sh` pass.
