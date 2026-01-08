import 'package:myapp/modelo/empresa/actividad_economica.dart';
import 'package:myapp/modelo/empresa/dato_empresa.dart';

class ActividadEmpresa {
  int? id;
  DatoEmpresa fk_empresa;
  ActividadEconomica fk_actividad;

  ActividadEmpresa({
    this.id,
    required this.fk_empresa,
    required this.fk_actividad,
  });

  factory ActividadEmpresa.fromMap(Map<String, dynamic> map) {
    return ActividadEmpresa(
      id: map['id'],
      // IMPORTANTE: Aquí Supabase devuelve un Map (Objeto JSON), 
      // por lo que llamamos al fromMap de los modelos hijos.
      fk_empresa: DatoEmpresa.fromMap(map['fk_empresa'] ?? {}),
      fk_actividad: ActividadEconomica.fromMap(map['fk_actividad'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      // Al guardar, usualmente solo necesitamos los IDs, 
      // pero para consistencia del objeto:
      'fk_empresa': fk_empresa.toMap(),
      'fk_actividad': fk_actividad.toMap(),
    };
  }
}