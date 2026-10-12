-- Tipo de factura: seed SIFEN + Ticket
-- Seeds the SIFEN electronic document types (ids 1-8 match the SIFEN codes)
-- and adds "Ticket", an internal-use document that is local (not SIFEN/FacturaSend).
-- Ticket keeps its own nro_secuencial counter per establishment, so it never
-- consumes the electronic invoice numbering.
-- Run in the SQL Editor. Safe to re-run: existing ids are left untouched.

-- 1) SIFEN types with their official codes
INSERT INTO tipo_factura (id_tipo_factura, descripcion)
OVERRIDING SYSTEM VALUE
VALUES
  (1, 'Factura electrónica'),
  (2, 'Factura electrónica de exportación'),
  (3, 'Factura electrónica de importación'),
  (4, 'Autofactura electrónica'),
  (5, 'Nota de crédito electrónica'),
  (6, 'Nota de débito electrónica'),
  (7, 'Nota de remisión electrónica'),
  (8, 'Comprobante de retención electrónico')
ON CONFLICT (id_tipo_factura) DO NOTHING;

-- 2) Move the id sequence past the explicit ids so new rows do not collide
SELECT setval(
  pg_get_serial_sequence('tipo_factura', 'id_tipo_factura'),
  GREATEST((SELECT max(id_tipo_factura) FROM tipo_factura), 8)
);

-- 3) Ticket (id assigned by the sequence; must stay <= 999 because it is
--    printed as the 3-digit middle segment of the document number)
INSERT INTO tipo_factura (descripcion)
SELECT 'Ticket'
WHERE NOT EXISTS (
  SELECT 1 FROM tipo_factura WHERE lower(trim(descripcion)) = 'ticket'
);

-- 4) Verify (manual check, uncomment to run in the SQL Editor)
-- SELECT id_tipo_factura, descripcion
-- FROM tipo_factura
-- ORDER BY id_tipo_factura;
