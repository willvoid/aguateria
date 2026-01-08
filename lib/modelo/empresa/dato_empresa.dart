import 'package:myapp/modelo/empresa/tipo_contribuyente.dart';
import 'package:myapp/modelo/empresa/tipo_regimen.dart';

class DatoEmpresa {
  int? id_empresa;
  String ruc;
  String razon_social;
  String nombre_fantasia;
  TipoContribuyente fk_contribuyente;
  TipoRegimen fk_regimen;
  String estado;

  DatoEmpresa({
    required this.ruc,
    required this.razon_social,
    required this.nombre_fantasia,
    required this.fk_contribuyente,
    required this.fk_regimen,
    required this.estado,
    this.id_empresa,
  });

  factory DatoEmpresa.fromMap(Map<String, dynamic> map) {
    return DatoEmpresa(
      id_empresa: map['id_empresa'],
      ruc: map['ruc'],
      razon_social: map['razon_social'],
      nombre_fantasia: map['nombre_fantasia'],
      fk_contribuyente: TipoContribuyente.fromMap(map['fk_contribuyente']),
      fk_regimen: TipoRegimen.fromMap(map['fk_regimen']),
      estado: map['estado'],
      );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_empresa': id_empresa,
      'ruc': ruc,   
      'razon_social': razon_social,
      'nombre_fantasia': nombre_fantasia,
      'fk_contribuyente': fk_contribuyente.toMap(),
      'fk_regimen': fk_regimen.toMap(),
      'estado': estado,
    };
  }
}
