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
- [x] T3 `preflight.sql` run on DEV (schema, catalogs, ciclos, trigger). PROD: only `pago_detalle_deuda` missing and `detalle_factura.fk_deudas` unused (0); rest pending
- [x] T4 Decisions closed in `decisiones.csv` (302-306, Lavadero, col E colours); real Excel parses with 0 blocking problems
- [x] T5 Migration `supabase/migrations/20261029_importar_aguateria.sql`: staging tables + `fn_importar_aguateria(lote, aplicar, barrio, ...)` with dry-run, invariants and `fn_revertir_importacion_aguateria` — tested on local Postgres with a replica of the DEV schema (`tools/import_aguateria/test_sql/run_tests.sh`)
- [x] T6 Staging generator (`importar.py` writes `out/staging.sql` only when there are no blocking problems)
- [x] T7 DEV run DONE (2026-10-30): wiped, migration + 6 `staging_N.sql`, dry-run, apply `fn_importar_aguateria('f3813a1b-0aa4-46b6-9624-34e43bca1f29', true, 447, 1, 1, '{"2026-02": 3}')`. Result 359 clientes, 381 inmuebles, 1485 cuentas_cobrar, saldo 94.649.000 (Conexión 44.304.000, Deuda anterior 17.505.000). Cron job 2 re-enabled by the user. A May-doubled report seen in the app came from an old APK build. Still open in DEV: confirm which `reporte_deudas` version is deployed (the DB function groups by vencimiento unless `20261013_reporte_deudas_por_anio.sql` is run), and delete staging with `DELETE FROM import_aguateria_lote` when satisfied (this removes the revert option)
- [ ] T8 PROD: run `preflight.sql` + `pg_get_functiondef('public.reporte_deudas(integer)'::regprocedure)` there; decide which report version stays; backup, wipe old data, same steps as DEV

## Evidence
- `python3 -m unittest test_importar` (in `tools/import_aguateria`): 19 passed.
- Real Excel: 376 inmuebles read (5 skipped by duplicated code), 354 clientes, 1321 deudas, 113 blocking problems (102 DEUDA without concept, 6 months above tarifa, 5 duplicated codes).
- `tools/import_aguateria/test_sql/run_tests.sh` (Postgres 16 + dev schema replica, synthetic fixture): all ok — dry-run leaves no rows, apply, reporte_deudas matches, cron does not duplicate the active ciclo, no double apply, revert refused when invoiced, revert OK.
- Real Excel (copy with 302-306 renamed, test decisions): 381 inmuebles, 359 clientes, 1473 cuentas_cobrar; reporte_deudas(2026) totals equal the Excel; simulated cron added 0 rows (and 37 without the guard rows).
- Real Excel, final decisions: 0 blocking, 68 warnings; 381 inmuebles, 359 clientes, 1485 cuentas_cobrar (incl. 37 PAGADO guard rows). Totals: Consumo 32.840.000, Conexión 44.304.000, Deuda anterior 17.505.000, total 94.649.000 — same as an independent script and as `reporte_deudas(2026)`; cron simulation added 0 rows; revert OK. 30 python tests + `run_tests.sh` pass.

## Findings to remember
- The Excel `TOTAL A PAGAR` is `=SUM(F:Q)` in 304 rows (misses sep/oct 2026): never use it as a control.
- DB has no unique constraints (cod_inmueble, documento, inmueble+ciclo+concepto): `fn_importar_aguateria` enforces them. Trigger `tr_deuda_cambio_estado` normalises estado from saldo.
- DEV `reporte_deudas` groups by year AND month of `ciclos.vencimiento`; the repo file `20261013` groups by `ciclos.anio` and month of `inicio`. DEV ciclos have shifted vencimientos (Dec 2025 vence 2026-01-01, Jan 2026 vence 02-14...), so DEV shows Consumo in Jan..May shifted (Ene 975.000, Feb 1.075.000, Mar 1.175.000, Abr 1.300.000, May 3.270.000); totals are right. The import check sums all years so it does not depend on this.
- DEV ciclos 10, 11, 12 are tests and are never used; Feb 2026 needs `p_ciclos '{"2026-02": 3}'` (two candidates).
- Cron job 2 runs daily 01:00 UTC; the ACTIVO ciclo (Oct 2026) vence 31/10. Pause it during the load.
- 37 connected inmuebles have October blank: loaded as PAGADO so the cron does not charge them. Confirm with the user.
- Warnings left: docs ambiguous rows 130 and 367 (loaded as documento 0), 3 repeated documents with different names (1034492, 7208444, 5498680), 12 dubious celulares, nov/dic 2026 advance payments in `adelantos.csv`.
- Excel and `out/` stay out of git; the user generates them locally with `python tools\import_aguateria\importar.py "<xlsx>" --partes-kb 40` (attachments from the cloud session did not reach them).
