-- Concepto: permite_cuotas
-- Marks the concepts that can be paid in free-amount installments (abonos),
-- the way "Conexion" has always worked. Run section by section in the SQL Editor.

-- 1) Add the column
ALTER TABLE conceptos
  ADD COLUMN IF NOT EXISTS permite_cuotas boolean NOT NULL DEFAULT false;

-- 2) Preserve current behaviour: Conexion (2) and Deuda anterior (3)
UPDATE conceptos
SET permite_cuotas = true
WHERE id_concepto IN (2, 3);

-- 3) Verify (manual check, uncomment to run in the SQL Editor)
-- SELECT id_concepto, nombre, permite_cuotas
-- FROM conceptos
-- ORDER BY id_concepto;
