# kude-factura-electronica-datos

## Objective
Que la factura electrónica impresa (KuDE, térmica y PDF) muestre los datos de una factura real de SIFEN, y corregir el desfase de líneas en la liquidación del IVA. El ticket de uso interno (`esInterno`) NO cambia.

## Scope
- Solo documentos no internos (`!t.esInterno`). El ticket queda idéntico.
- Archivos: `lib/service/ticket_printer_service.dart` (TicketData, obtenerTicket, PDF), `lib/service/thermal_printer_service.dart` (ESC/POS), util nuevo de número a letras + test.

## Tasks
- [x] T1 Util `numero a letras` (guaraníes) con test unitario (RED/GREEN). Ruta: delegada (writer único)
- [x] T2 `TicketData`/`obtenerTicket`: leer condición de venta, moneda, actividad económica, email, fin de vigencia, IVA por ítem; todo defensivo (si la RPC no lo trae, se omite la línea). Ruta: delegada
- [x] T3 Térmica: layout KuDE completo si `!esInterno` + corregir desfase de líneas en `par`/TOTAL. Ruta: delegada
- [x] T4 PDF (`_buildContenido`): mismos campos y leyendas si `!esInterno`. Ruta: delegada
- [x] T5 `flutter analyze` sin errores nuevos + `flutter test` del util

## Campos nuevos (solo no-interno)
Condición de venta (contado/crédito), moneda, actividad económica del emisor, teléfono/correo, fin de vigencia del timbrado, tasa de IVA por ítem, total en letras, leyenda "Consulte la validez de este Documento Electrónico con el número de CDC impreso abajo en https://ekuatia.set.gov.py/consultas", leyenda "ESTE DOCUMENTO ES UNA REPRESENTACIÓN GRÁFICA DE UN DOCUMENTO ELECTRÓNICO (XML)".

## Checks
- RED/GREEN solo para el util de letras (función pura, determinista). La impresión no tiene tests: `flutter analyze` + revisión estructural; la prueba física en la impresora la hace el usuario.

## Notes
- Causa del desfase NO confirmada: solo se ve en la foto del usuario. Mitigación conservadora (ancho cols-1) y verificación en impresora real.
- Sin commits hasta que el usuario confirme; el árbol tiene cambios ajenos mezclados.
- Evidencia: T1 RED observado (flutter test: Method not found numeroALetras/guaraniesALetras), GREEN `+36: All tests passed`. T5: `flutter analyze lib/service lib/util` sin issues nuevos en ticket_printer_service/thermal_printer_service/numero_a_letras (los 12 restantes ya existían: pago_deuda_service, factura_rpc_service, payload_builder_helper y un `unnecessary_to_list_in_spreads` previo).
- Desfase térmico: se usa ancho `columnas - 1` en pares/separador/texto envuelto y el TOTAL calcula ancho según tamaño (size>=2 -> mitad). Causa raíz NO confirmada; verificar con impresión física 58 mm. El ticket interno conserva el ancho original (cols-1 solo aplica a !esInterno).
- Claves de la RPC probadas (sin confirmar): ver reporte; si faltan, la línea no se imprime.
- Pendiente: prueba física térmica y revisión visual del PDF (sin tests de layout).
