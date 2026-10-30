#!/usr/bin/env bash
# Prueba la migración 20261029_importar_aguateria.sql contra un Postgres local con una
# réplica del esquema de desarrollo. Uso (con PGHOST/PGPORT/PGUSER ya definidos):
#   tools/import_aguateria/test_sql/run_tests.sh
set -euo pipefail
cd "$(dirname "$0")/../../.."
DB=aguateria_test_import
L=00000000-0000-0000-0000-000000000001
P="psql -v ON_ERROR_STOP=1 -q -t -A -d $DB"
fallos=0
chequear() {  # descripción, esperado, obtenido
  if [ "$2" == "$3" ]; then echo "ok    $1"; else echo "FALLA $1: esperado [$2] obtenido [$3]"; fallos=$((fallos+1)); fi
}

psql -q -d postgres -c "DROP DATABASE IF EXISTS $DB" -c "CREATE DATABASE $DB" 2>/dev/null
for f in tools/import_aguateria/test_sql/schema_dev.sql \
         supabase/migrations/20261013_reporte_deudas_por_anio.sql \
         supabase/migrations/20261029_importar_aguateria.sql \
         supabase/functions/fn_generar_deudas_ciclos_vencidos.sql \
         tools/import_aguateria/test_sql/fixture_staging.sql; do
  $P -f "$f" >/dev/null 2>&1 || { echo "No se pudo cargar $f"; exit 1; }
done

da_error() {  # sentencia, texto esperado en el mensaje -> imprime ERROR si falla con ese texto
  local salida; salida=$($P -c "$1" 2>&1 || true)
  if grep -q "$2" <<<"$salida"; then echo ERROR; else echo "$salida"; fi
}
contar() { $P -c "SELECT count(*) FROM $1" 2>/dev/null; }
chequear "prueba exige barrio" "ERROR" "$(da_error "SELECT fn_importar_aguateria('$L')" 'Indique un barrio')"

$P -c "SELECT fn_importar_aguateria('$L', false, 447)" >/dev/null 2>&1
chequear "prueba no deja clientes" 0 "$(contar clientes)"

# Un reporte_deudas que agrupa por el AÑO DEL VENCIMIENTO (el diciembre 2025 vence en 2026) no debe
# romper la verificación: el control suma todos los años.
sed 's/ci\.anio = p_anio/EXTRACT(year FROM ci.vencimiento) = p_anio/g' supabase/migrations/20261013_reporte_deudas_por_anio.sql \
  | $P -f - >/dev/null 2>&1
chequear "prueba con reporte agrupado por vencimiento" false \
  "$($P -c "SELECT (fn_importar_aguateria('$L', false, 447)) ->> 'aplicado'" 2>/dev/null)"
$P -f supabase/migrations/20261013_reporte_deudas_por_anio.sql >/dev/null 2>&1
chequear "prueba no deja ciclos nuevos" 10 "$(contar ciclos)"

informe=$($P -c "SELECT fn_importar_aguateria('$L', true, 447, 1, 1, '{\"2026-02\":3}')" 2>/dev/null)
chequear "aplica" true "$(echo "$informe" | python3 -c 'import json,sys;print(str(json.load(sys.stdin)["aplicado"]).lower())')"
chequear "clientes" 3 "$(contar clientes)"
chequear "inmuebles" 4 "$(contar inmuebles)"
chequear "ciclos creados (ago y sep)" 12 "$(contar ciclos)"
# 6 del Excel + 1 PAGADO de octubre (el inmueble 2 es conectado y no tiene cargo en el Excel)
chequear "deudas" 7 "$(contar cuentas_cobrar)"
chequear "inmueble 2 queda con Consumo octubre PAGADO" PAGADO \
  "$($P -c "SELECT cc.estado FROM cuentas_cobrar cc JOIN inmuebles i ON i.id=cc.fk_inmueble WHERE i.cod_inmueble='2'")"
chequear "pago parcial" "PAGO_PARCIAL|30000" \
  "$($P -c "SELECT cc.estado||'|'||cc.pagado::int FROM cuentas_cobrar cc JOIN inmuebles i ON i.id=cc.fk_inmueble WHERE i.cod_inmueble='4/1' AND fk_concepto=1")"
chequear "RUC y sin documento sin tipo_documento" 2 "$($P -c "SELECT count(*) FROM clientes WHERE fk_tipo_documento IS NULL")"
chequear "inmueble cortado sin cliente" 1 "$($P -c "SELECT count(*) FROM inmuebles WHERE estado='DESCONECTADO' AND fk_cliente IS NULL")"
chequear "categoría Lavadero por tarifa" 2 "$($P -c "SELECT fk_categoria_servicio FROM inmuebles WHERE cod_inmueble='4/1'")"
chequear "reporte_deudas coincide (total)" 1420000 "$($P -c "SELECT sum(deuda_total)::int FROM reporte_deudas(2026)")"

antes=$(contar cuentas_cobrar)
$P -c "UPDATE ciclos SET vencimiento = current_date WHERE id_ciclos = 14" -c "SELECT fn_generar_deudas_ciclos_vencidos()" >/dev/null 2>&1
chequear "el cron no duplica el ciclo activo" "$antes" "$(contar cuentas_cobrar)"

chequear "no se aplica dos veces" ERROR \
  "$(da_error "SELECT fn_importar_aguateria('$L', true, 447, 1, 1, '{\"2026-02\":3}')" 'solo se importa un lote CARGADO')"

$P -c "INSERT INTO detalle_factura(fk_deudas) SELECT min(id_deuda) FROM cuentas_cobrar" >/dev/null
chequear "no revierte con deudas facturadas" ERROR \
  "$(da_error "SELECT fn_revertir_importacion_aguateria('$L')" 'No se puede revertir')"
$P -c "DELETE FROM detalle_factura" >/dev/null
$P -c "SELECT fn_revertir_importacion_aguateria('$L')" >/dev/null 2>&1
chequear "revierte: clientes" 0 "$(contar clientes)"
chequear "revierte: deudas" 0 "$(contar cuentas_cobrar)"
chequear "revierte: ciclos" 10 "$(contar ciclos)"

psql -q -d postgres -c "DROP DATABASE $DB" 2>/dev/null
[ "$fallos" -eq 0 ] && echo "TODO OK" || { echo "$fallos fallas"; exit 1; }
