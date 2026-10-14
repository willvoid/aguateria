-- Reporte de deudas por año, con Conexión (concepto 2) y Deuda anterior (concepto 3)
-- como columnas propias. La vista reporte_deudas_mensuales queda intacta.
--
-- * Meses: solo Consumo (concepto 1) de los ciclos con ciclos.anio = año pedido; el mes sale de ciclos.inicio.
-- * conexion / deuda_anterior: saldo pendiente total, sin filtrar por año.
-- * deuda_total: saldo pendiente histórico de todos los conceptos y años.

CREATE OR REPLACE FUNCTION public.reporte_deudas(p_anio integer)
RETURNS TABLE (
  id_inmueble         text,
  nombres_y_apellidos text,
  nro_cedula          text,
  nro_celular         text,
  estado_conexion     text,
  deuda_total         double precision,
  conexion            double precision,
  deuda_anterior      double precision,
  enero               double precision,
  febrero             double precision,
  marzo               double precision,
  abril               double precision,
  mayo                double precision,
  junio               double precision,
  julio               double precision,
  agosto              double precision,
  septiembre          double precision,
  octubre             double precision,
  noviembre           double precision,
  diciembre           double precision
)
LANGUAGE sql
STABLE
AS $$
  SELECT
    i.cod_inmueble::text,
    c.razon_social::text,
    c.documento::text,
    c.celular::text,
    i.estado::text,
    COALESCE(sum(cc.saldo), 0::double precision),
    COALESCE(sum(cc.saldo) FILTER (WHERE cc.fk_concepto = 2), 0::double precision),
    COALESCE(sum(cc.saldo) FILTER (WHERE cc.fk_concepto = 3), 0::double precision),
    COALESCE(sum(cc.saldo) FILTER (WHERE cc.fk_concepto = 1 AND ci.anio = p_anio AND EXTRACT(month FROM ci.inicio) = 1),  0::double precision),
    COALESCE(sum(cc.saldo) FILTER (WHERE cc.fk_concepto = 1 AND ci.anio = p_anio AND EXTRACT(month FROM ci.inicio) = 2),  0::double precision),
    COALESCE(sum(cc.saldo) FILTER (WHERE cc.fk_concepto = 1 AND ci.anio = p_anio AND EXTRACT(month FROM ci.inicio) = 3),  0::double precision),
    COALESCE(sum(cc.saldo) FILTER (WHERE cc.fk_concepto = 1 AND ci.anio = p_anio AND EXTRACT(month FROM ci.inicio) = 4),  0::double precision),
    COALESCE(sum(cc.saldo) FILTER (WHERE cc.fk_concepto = 1 AND ci.anio = p_anio AND EXTRACT(month FROM ci.inicio) = 5),  0::double precision),
    COALESCE(sum(cc.saldo) FILTER (WHERE cc.fk_concepto = 1 AND ci.anio = p_anio AND EXTRACT(month FROM ci.inicio) = 6),  0::double precision),
    COALESCE(sum(cc.saldo) FILTER (WHERE cc.fk_concepto = 1 AND ci.anio = p_anio AND EXTRACT(month FROM ci.inicio) = 7),  0::double precision),
    COALESCE(sum(cc.saldo) FILTER (WHERE cc.fk_concepto = 1 AND ci.anio = p_anio AND EXTRACT(month FROM ci.inicio) = 8),  0::double precision),
    COALESCE(sum(cc.saldo) FILTER (WHERE cc.fk_concepto = 1 AND ci.anio = p_anio AND EXTRACT(month FROM ci.inicio) = 9),  0::double precision),
    COALESCE(sum(cc.saldo) FILTER (WHERE cc.fk_concepto = 1 AND ci.anio = p_anio AND EXTRACT(month FROM ci.inicio) = 10), 0::double precision),
    COALESCE(sum(cc.saldo) FILTER (WHERE cc.fk_concepto = 1 AND ci.anio = p_anio AND EXTRACT(month FROM ci.inicio) = 11), 0::double precision),
    COALESCE(sum(cc.saldo) FILTER (WHERE cc.fk_concepto = 1 AND ci.anio = p_anio AND EXTRACT(month FROM ci.inicio) = 12), 0::double precision)
  FROM inmuebles i
    LEFT JOIN clientes c ON i.fk_cliente = c.id_cliente
    LEFT JOIN cuentas_cobrar cc ON i.id = cc.fk_inmueble
    LEFT JOIN ciclos ci ON cc.fk_ciclos = ci.id_ciclos
  GROUP BY i.id, i.cod_inmueble, c.id_cliente, c.razon_social, c.documento, c.celular, i.estado;
$$;
