import 'package:myapp/modelo/%20tipo_documento.dart';
import 'package:myapp/modelo/barrio.dart';
import 'package:myapp/modelo/tipo_operacion.dart';

class Cliente {
  int? idCliente;
  String razonSocial;
  String? nombreFantasia;
  String documento;
  String? telefono;
  String celular;
  String? direccion;
  bool es_proveedor_del_estado;
  String? email;
  int nroCasa;
  TipoOperacion tipoOperacion;
  String estado;
  TipoDocumento tipoDocumento;
  Barrio barrio;

  Cliente({
    this.idCliente,
    required this.razonSocial,
    this.nombreFantasia,
    required this.documento,
    this.telefono,
    required this.celular,
    this.direccion,
    required this.es_proveedor_del_estado,
    this.email,
    required this.nroCasa,
    required this.tipoOperacion,
    required this.estado,
    required this.tipoDocumento,
    required this.barrio,
  });

  factory Cliente.fromMap(Map<String, dynamic> map) {
    return Cliente(
      idCliente: map['id_cliente'],
      razonSocial: map['razon_social'],
      nombreFantasia: map['nombre_fantasia'],
      documento: map['documento'],
      telefono: map['telefono'],
      celular: map['celular'],
      direccion: map['direccion'],
      es_proveedor_del_estado: map['es_proveedor_del_estado'],
      email: map['email'],
      nroCasa: map['nro_casa'],
      tipoOperacion: TipoOperacion.fromMap(map['tipo_operacion']),
      estado: map['estado'],
      tipoDocumento: TipoDocumento.fromMap(map['tipo_documento']),
      barrio: Barrio.fromMap(map['barrio']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_cliente': idCliente,
      'razon_social': razonSocial,
      'nombre_fantasia': nombreFantasia,
      'documento': documento,
      'telefono': telefono,
      'celular': celular,
      'direccion': direccion,
      'es_proveedor_del_estado': es_proveedor_del_estado,
      'email': email,
      'nro_casa': nroCasa,
      'tipo_operacion': tipoOperacion.toMap(),
      'estado': estado,
      'barrio': barrio.toMap(),
      'fk_tipo_operacion': tipoOperacion.toMap(),
      'id_tipo_documento': tipoDocumento.toMap(),
      'fk_barrio': barrio.toMap(),
    };
  }
}
