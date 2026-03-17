import 'package:myapp/modelo/contabilidad/tipo_cuenta_contable.dart';

class CuentasContables {
  int? id;
  String nombre;
  String? codigo;
  TipoCuentaContable tipoCuenta;
  bool imputable;
  CuentasContables? cuentaPadre;

  CuentasContables({
    this.id,
    required this.nombre,
    this.codigo,
    required this.tipoCuenta,
    required this.imputable,
    this.cuentaPadre,
  });

  factory CuentasContables.fromMap(Map<String, dynamic> map) {
    return CuentasContables(
      id: map['id'],
      nombre: map['nombre'],
      codigo: map['codigo'],
      tipoCuenta: TipoCuentaContable.fromMap(map['fk_tipo_cuenta']),
      imputable: map['imputable'],
      cuentaPadre: map['fk_cuenta_padre'] != null
          ? CuentasContables.fromMap(map['fk_cuenta_padre'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'codigo': codigo,
      'fk_tipo_cuenta': tipoCuenta.toMap(),
      'imputable': imputable,
      'fk_cuenta_padre': cuentaPadre?.toMap(),
    };
  }
}