-- Tipo de factura: Ticket
-- Internal-use ticket (no fiscal value). It is a local document type, not a
-- SIFEN/FacturaSend one, so it keeps its own nro_secuencial counter per
-- establishment and never consumes the electronic invoice numbering.
-- Run in the SQL Editor.

-- 1) Add the type once (the id is assigned by the table; it must stay <= 999
--    because it is printed as the 3-digit middle segment of the number)
INSERT INTO tipo_factura (descripcion)
SELECT 'Ticket'
WHERE NOT EXISTS (
  SELECT 1 FROM tipo_factura WHERE lower(trim(descripcion)) = 'ticket'
);

-- 2) Verify (manual check, uncomment to run in the SQL Editor)
-- SELECT id_tipo_factura, descripcion
-- FROM tipo_factura
-- ORDER BY id_tipo_factura;
