# importar-datos-aguateria

Objective: load `DATOS DE AGUATERÍA ACTUAL 2510.xlsx` (corte 25/10/2026) into Supabase without inconsistencies. Excel wins over old data, with backup first.

## Decisions
- Concepts by ID: 1 Consumo, 2 Conexión, 3 Deuda anterior (same as `reporte_deudas`).
- Col E with two amounts: first = Deuda anterior, second = Conexión. One amount: manual review (`revision_E.csv`).
- Sep-2025 above the tarifa: tarifa stays in Consumo, the rest goes to Deuda anterior.
- RUC (`4125450-3`, `4.237.043-4` -> `4237043-4`) and no document (`'0'`): `tipo_documento` null.
- `USUARIO CORTADO`, `TAPONADO`, `CONEXIÓN CORTADA` -> inmueble DESCONECTADO.
- Celular: digits only, no hyphen, always in `celular`; `telefono` empty.
- Codes 302-306 are duplicated in the Excel: the user fixes them there.
- Personal data (xlsx, `out/`) is never committed.

## Tasks
- [x] T1 `tools/import_aguateria/importar.py` + `test_importar.py` (offline parse, reports, totals) — route: inline
- [x] T2 `tools/import_aguateria/preflight.sql` (read-only checks on schema, catalogs, ciclos, cron) — route: inline
- [ ] T3 User runs `preflight.sql` on TEST and PROD and shares the results
- [ ] T4 User fixes codes 302-306 and decides `revision_E.csv` (102 cases), `MES_MAYOR_TARIFA` (6 cells) and ambiguous documents
- [ ] T5 Migration `supabase/migrations/2026xxxx_importar_aguateria.sql`: staging tables + `fn_importar_aguateria(lote, aplicar)` with dry-run and invariants
- [ ] T6 Staging generator (`normalizado.json` -> `staging.sql`)
- [ ] T7 TEST run: backup, pause cron, dry-run, apply, compare with `reporte_deudas(2026)`
- [ ] T8 PROD run, same steps

## Evidence
- `python3 -m unittest test_importar` (in `tools/import_aguateria`): 19 passed.
- Real Excel: 376 inmuebles read (5 skipped by duplicated code), 354 clientes, 1321 deudas, 113 blocking problems (102 DEUDA without concept, 6 months above tarifa, 5 duplicated codes).
