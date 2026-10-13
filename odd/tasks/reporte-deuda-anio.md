# reporte-deuda-anio

Objective: the debt report shows separate "Conexión" and "Deuda anterior" columns and has a year selector.
Plan: `C:\Users\Windows 11\.claude\plans\quiero-que-en-el-replicated-crystal.md`

## Decisions
- Concepts by ID: 1 Consumo, 2 Conexión, 3 Deuda anterior.
- Month columns = concept 1 only, filtered by year of `ciclos.vencimiento`.
- Conexión / Deuda anterior = total pending `saldo`, not year-filtered.
- `deuda_total` = historical total, unchanged.
- Default year = current year; list from `ciclos.vencimiento` years (+ current year).
- Old view `reporte_deudas_mensuales` stays untouched; new RPC `reporte_deudas(p_anio int)`.

## Tasks
- [x] T1 Migration `supabase/migrations/20261013_reporte_deudas_por_anio.sql` (RPC) — route: inline (single mechanical file)
- [x] T2 `ReporteMensual` gets `conexion` and `deuda_anterior` + `test/reporte_model_test.dart` (RED first) — route: inline
- [x] T3 `pantalla_reporte.dart`: year dropdown, rpc call, 2 new columns in screen table and PDF (8 fixed columns), year in PDF title — route: delegated writer (screen + PDF layout)

## Delivery
Branch `feat/reporte-deuda-anio`; one work-unit commit per task group; no push/PR without user.

## Evidence
- `flutter test test/reporte_model_test.dart`: RED observed first, then 2 passed.
- `flutter analyze lib/reportes`: 4 pre-existing infos, 0 errors.
- Pending (needs the user): run the migration in the Supabase SQL Editor and check visually with `flutter run`.
