-- Réplica mínima del esquema de DESARROLLO (según el pre-flight) para probar
-- la migración 20261029_importar_aguateria.sql en un Postgres local.
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN CREATE ROLE anon NOLOGIN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN CREATE ROLE authenticated NOLOGIN; END IF;
END $$;

CREATE TABLE barrios (cod_barrio bigint PRIMARY KEY, nombre_barrio text NOT NULL, fk_ciudad bigint);
CREATE TABLE tipo_operacion (id_tipo_operacion bigint PRIMARY KEY, codigo_tipo_op text);
CREATE TABLE tipo_documento (cod_tipodoc bigint PRIMARY KEY, descripcion_tipodoc text);
CREATE TABLE tipo_contribuyente (id_tipo_contribuyente bigint PRIMARY KEY);
CREATE TABLE categoria_servicio (id bigint PRIMARY KEY, nombre text, tarifa_fija double precision,
  m2_min double precision, m2_max double precision, descripcion text);
CREATE TABLE conceptos (id_concepto bigint PRIMARY KEY, nombre text, arancel double precision,
  estado text, permite_cuotas boolean NOT NULL DEFAULT false);
CREATE TABLE consumos (id_consumos bigint PRIMARY KEY);

CREATE TABLE ciclos (
  id_ciclos bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  created_at timestamptz NOT NULL DEFAULT now(),
  inicio date NOT NULL, fin date NOT NULL, vencimiento date NOT NULL,
  anio bigint NOT NULL, descripcion text NOT NULL, ciclo text NOT NULL, estado text NOT NULL);

CREATE TABLE clientes (
  id_cliente bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  created_at timestamptz NOT NULL DEFAULT now(),
  razon_social text NOT NULL, nombre_fantasia text, documento text NOT NULL, telefono text,
  celular text NOT NULL, direccion text, es_proveedor_del_estado boolean NOT NULL, email text,
  nro_casa bigint NOT NULL DEFAULT 0,
  fk_tipo_operacion bigint NOT NULL REFERENCES tipo_operacion(id_tipo_operacion),
  estado_cliente text NOT NULL DEFAULT 'ACTIVO',
  fk_tipo_documento bigint REFERENCES tipo_documento(cod_tipodoc),
  fk_barrios bigint NOT NULL REFERENCES barrios(cod_barrio),
  tipo_contribuyente bigint REFERENCES tipo_contribuyente(id_tipo_contribuyente));

CREATE TABLE inmuebles (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  created_at timestamptz NOT NULL DEFAULT now(),
  cod_inmueble text NOT NULL, estado text NOT NULL, direccion text,
  fk_cliente bigint REFERENCES clientes(id_cliente),
  fk_categoria_servicio bigint NOT NULL REFERENCES categoria_servicio(id));

CREATE TABLE cuentas_cobrar (
  id_deuda bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  created_at timestamptz NOT NULL DEFAULT now(),
  fk_concepto bigint NOT NULL REFERENCES conceptos(id_concepto),
  descripcion text NOT NULL, monto double precision NOT NULL, estado text NOT NULL,
  fk_ciclos bigint REFERENCES ciclos(id_ciclos),
  fk_inmueble bigint NOT NULL REFERENCES inmuebles(id),
  saldo double precision NOT NULL, pagado double precision NOT NULL,
  fk_consumos bigint REFERENCES consumos(id_consumos));

CREATE TABLE detalle_factura (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  fk_deudas bigint REFERENCES cuentas_cobrar(id_deuda));

-- Trigger real de desarrollo
CREATE OR REPLACE FUNCTION public.fn_actualizar_estado_deuda()
 RETURNS trigger LANGUAGE plpgsql AS $function$BEGIN
    IF NEW.estado IN ('EN REVISION') THEN
        RETURN NEW;
    END IF;
    IF NEW.saldo <= 0 THEN
        NEW.estado := 'PAGADO';
        NEW.saldo := 0;
    ELSIF NEW.saldo < NEW.monto THEN
        NEW.estado := 'PAGO_PARCIAL';
    ELSIF TG_OP = 'UPDATE' THEN
        IF NEW.saldo = NEW.monto AND OLD.estado <> 'EN REVISION' THEN
            NEW.estado := 'PENDIENTE';
        END IF;
    END IF;
    RETURN NEW;
END;$function$;
CREATE TRIGGER tr_deuda_cambio_estado BEFORE INSERT OR UPDATE ON cuentas_cobrar
  FOR EACH ROW EXECUTE FUNCTION fn_actualizar_estado_deuda();

-- Catálogos de desarrollo
INSERT INTO barrios VALUES (447, 'IPVU', 2988), (458, 'CENTRO', 2988);
INSERT INTO tipo_operacion VALUES (1, 'B2B');
INSERT INTO tipo_documento VALUES (1, 'Cédula paraguaya');
INSERT INTO categoria_servicio VALUES (1, 'Estandar', 25000, 0, 1000, 'Estandar'),
                                      (2, 'Lavadero', 50000, 1001, 1500, 'Lavadero');
INSERT INTO conceptos VALUES (1, 'Consumo', 25000, 'ACTIVO', true), (2, 'Conexion', 300000, 'ACTIVO', true),
                             (3, 'Deuda anterior', 0, 'ACTIVO', true);

-- Ciclos de desarrollo (incluye los de prueba 10, 11 y 12 y los meses que faltan)
INSERT INTO ciclos (id_ciclos, ciclo, descripcion, anio, inicio, fin, vencimiento, estado)
OVERRIDING SYSTEM VALUE VALUES
 (5,  '2025-12',    'Diciembre 2025',         2025, '2025-12-01', '2025-12-31', '2026-01-01', 'INACTIVO'),
 (1,  '2026-1',     'Enero 2026',             2026, '2026-01-05', '2026-02-04', '2026-02-14', 'INACTIVO'),
 (10, '03',         'Ciclo de Prueba Marzo',  2026, '2026-02-04', '2026-03-06', '2026-03-06', 'INACTIVO'),
 (3,  '2026-2',     'Febrero 2026',           2026, '2026-02-05', '2026-03-01', '2026-03-05', 'INACTIVO'),
 (11, '03/2026',    'MAR 2026 Prueba 2',      2026, '2026-03-01', '2026-03-31', '2026-03-28', 'INACTIVO'),
 (4,  '2026-03',    'Marzo 2026',             2026, '2026-03-04', '2026-04-01', '2026-04-01', 'INACTIVO'),
 (12, 'TEST-04-26', 'Ciclo de prueba 2/4',    2026, '2026-04-02', '2026-04-02', '2026-04-03', 'INACTIVO'),
 (6,  '2026-04',    'Abril 2026',             2026, '2026-04-03', '2026-04-30', '2026-05-02', 'INACTIVO'),
 (8,  '2026 - 05',  'Mayo 2026',              2026, '2026-05-01', '2026-05-31', '2026-05-31', 'INACTIVO'),
 (14, '2026-10',    'octubre 2026',           2026, '2026-10-01', '2026-10-31', '2026-10-31', 'ACTIVO');
SELECT setval(pg_get_serial_sequence('ciclos', 'id_ciclos'), 14);
