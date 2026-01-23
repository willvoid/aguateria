import 'package:myapp/modelo/empresa/establecimiento.dart';
import 'package:myapp/modelo/facturacionmodelo/modo_pago.dart';
import 'package:myapp/modelo/facturacionmodelo/moneda.dart';
import 'package:myapp/modelo/facturacionmodelo/tipo_factura.dart';

class ConfiguracionSistema {
  int? id_config;
  Establecimiento establecimiento_default;
  Moneda moneda_default;
  ModoPago modo_pago_default;
  TipoFactura tipo_factura_default;
  int condicion_venta_default;

  ConfiguracionSistema({
    this.id_config,
    required this.establecimiento_default,
    required this.moneda_default,
    required this.modo_pago_default,
    required this.tipo_factura_default,
    required this.condicion_venta_default,
  });

  factory ConfiguracionSistema.fromMap(Map<String, dynamic> map) {
    return ConfiguracionSistema(
      id_config: map['id_config'],
      establecimiento_default: Establecimiento.fromMap(map['establecimiento_default']),
      moneda_default: Moneda.fromMap(map['moneda_default']),
      modo_pago_default: ModoPago.fromMap(map['modo_pago_default']),
      tipo_factura_default: TipoFactura.fromMap(map['tipo_factura_default']),
      condicion_venta_default: map['condicion_venta_default'],
    );
  }

}
