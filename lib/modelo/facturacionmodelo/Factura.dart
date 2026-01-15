import 'package:myapp/modelo/cliente.dart';
import 'package:myapp/modelo/empresa/establecimiento.dart';
import 'package:myapp/modelo/facturacionmodelo/modo_pago.dart';
import 'package:myapp/modelo/facturacionmodelo/moneda.dart';
import 'package:myapp/modelo/facturacionmodelo/tipo_factura.dart';

class Factura {
  int? id_factura;
  Cliente? fk_cliente;
  int? codicion_venta;
  double? total_gravado;
  double? total_exenta;
  double? total_iva;
  double? total_general;
  String? observacion;
  Moneda? fk_monedas;
  Establecimiento? fk_establecimientos;
  ModoPago? fk_modo_pago;
  TipoFactura? fk_tipo_factura;
  int? nro_secuencia;
}
