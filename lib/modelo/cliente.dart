import 'package:myapp/modelo/%20tipo_documento.dart';
import 'package:myapp/modelo/barrio.dart';
import 'package:myapp/modelo/empresa/tipo_contribuyente.dart';
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
  TipoDocumento? tipoDocumento;
  Barrio barrio;
  TipoContribuyente? tipo_contribuyente;

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
    this.tipoDocumento,
    required this.barrio,
    this.tipo_contribuyente,
  });

  factory Cliente.fromMap(Map<String, dynamic> map) {
  return Cliente(
    idCliente: map['id_cliente'],
    razonSocial: map['razon_social'] ?? '',
    nombreFantasia: map['nombre_fantasia'],
    documento: map['documento'] ?? '',
    telefono: map['telefono'],
    celular: map['celular'] ?? '',
    direccion: map['direccion'],
    es_proveedor_del_estado: map['es_proveedor_del_estado'] ?? false,
    email: map['email'],
    nroCasa: map['nro_casa'] ?? 0,
    tipoOperacion: map['tipo_operacion'] != null
        ? TipoOperacion.fromMap(map['tipo_operacion'])
        : TipoOperacion.vacio(), // ← necesitás este factory
    estado: map['estado_cliente'] ?? map['estado'] ?? '',
    tipoDocumento: map['tipo_documento'] != null
        ? TipoDocumento.fromMap(map['tipo_documento'])
        : null,
    barrio: map['barrios'] != null
        ? Barrio.fromMap(map['barrios'])
        : (map['barrio'] != null
            ? Barrio.fromMap(map['barrio'])
            : Barrio.vacio()), // ← necesitás este factory
    tipo_contribuyente: map['tipo_contribuyente'] != null
        ? TipoContribuyente.fromMap(map['tipo_contribuyente'])
        : null,
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
      'estado_cliente': estado,
      'tipo_documento': tipoDocumento?.toMap(),
      'barrio': barrio.toMap(),
      // Solo incluir si no es null
      'tipo_contribuyente': tipo_contribuyente?.toMap(),
    };
  }

  Map<String, dynamic> toJson() {
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
      'fk_tipo_operacion': tipoOperacion.id_tipo_operacion,
      'estado_cliente': estado,
      'fk_tipo_documento': tipoDocumento?.cod_tipo_documento,
      'fk_barrios': barrio.cod_barrio,
      // Solo incluir el ID si no es null
      'tipo_contribuyente': tipo_contribuyente?.id_tipo_contribuyente,
    };
  }

  // Método auxiliar para obtener el nombre completo del cliente
  String get nombreCompleto => nombreFantasia ?? razonSocial;

  // Método auxiliar para verificar si tiene tipo contribuyente
  bool get tieneContribuyente => tipo_contribuyente != null;

  @override
  String toString() {
    return 'Cliente{id: $idCliente, razonSocial: $razonSocial, documento: $documento, estado: $estado}';
  }
}