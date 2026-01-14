import 'package:myapp/modelo/%20tipo_documento.dart';
import 'package:myapp/modelo/usuario/cargo.dart';

class Usuario {
  int? id_usuario;
  String documento;
  String nombre;
  String? correo;
  String usuario;
  String clave;
  Cargo fk_cargo;
  TipoDocumento fk_tipo_doc;
  String? telefono;

  Usuario({
    this.id_usuario,
    required this.documento,
    required this.nombre,
    this.correo,
    required this.usuario,
    required this.clave,
    required this.fk_cargo,
    required this.fk_tipo_doc,
    this.telefono,
  });

  factory Usuario.fromMap(Map<String, dynamic> map) {
    // Verificar que los datos relacionados no sean null
    if (map['fk_cargo'] == null) {
      throw Exception('fk_cargo es null. Verifica las relaciones en Supabase.');
    }
    if (map['fk_tipo_doc'] == null) {
      throw Exception('fk_tipo_doc es null. Verifica las relaciones en Supabase.');
    }

    return Usuario(
      id_usuario: map['id_usuario'],
      documento: map['documento'] ?? '',
      nombre: map['nombre'] ?? '',
      correo: map['correo'],
      usuario: map['usuario'] ?? '',
      clave: map['clave'] ?? '',
      fk_cargo: Cargo.fromMap(map['fk_cargo']),
      fk_tipo_doc: TipoDocumento.fromMap(map['fk_tipo_doc']),
      telefono: map['telefono'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_usuario': id_usuario,
      'documento': documento,
      'nombre': nombre,
      'correo': correo,
      'usuario': usuario,
      'clave': clave,
      'fk_cargo': fk_cargo.toMap(),
      'fk_tipo_doc': fk_tipo_doc.toMap(),
      'telefono': telefono,
    };
  }
}