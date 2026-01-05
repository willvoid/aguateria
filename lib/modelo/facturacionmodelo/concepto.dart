import 'package:myapp/modelo/categoria_servicio.dart';
import 'package:myapp/modelo/facturacionmodelo/iva.dart';
import 'package:myapp/modelo/facturacionmodelo/unidad_medida.dart';

class Concepto {
  int? id;
  String nombre;
  double arancel;
  String descripcion;
  Iva fk_iva;
  UnidadMedida fk_unidad_medida;
  String estado;
  CategoriaServicio fk_servicio;

  Concepto ({
    this.id,
    required this.nombre,
    required this.arancel,
    required this.descripcion,
    required this.fk_iva,
    required this.fk_unidad_medida,
    required this.estado,
    required this.fk_servicio,
  });


  factory Concepto.fromMap(Map<String, dynamic> map) {
    return Concepto(
      id: map['id_concepto'],
      nombre: map['nombre'],
      arancel: map['arancel'],
      descripcion: map['descripcion'],
      fk_iva: Iva.fromMap(map['fk_iva']),
      fk_unidad_medida: UnidadMedida.fromMap(map['fk_unidad_medida']),
      estado: map['estado'],  
      fk_servicio: CategoriaServicio.fromMap(map['fk_servicio']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_concepto': id,
      'nombre': nombre,
      'arancel': arancel,
      'descripcion': descripcion,
      'fk_iva': fk_iva.toMap(),
      'fk_unidad_medida': fk_unidad_medida.toMap(),
      'estado': estado,
      'fk_servicio': fk_servicio.toMap(),
    };
  }
}
