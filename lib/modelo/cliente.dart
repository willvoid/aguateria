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
  TipoDocumento tipoDocumento;
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
    required this.tipoDocumento,
    required this.barrio,
    this.tipo_contribuyente,
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
      estado: map['estado_cliente'] ?? map['estado'], // Manejar ambos casos
      tipoDocumento: TipoDocumento.fromMap(map['tipo_documento']),
      barrio: Barrio.fromMap(map['barrios'] ?? map['barrio']), // Manejar ambos casos
      // ⚠️ CORRECCIÓN CRÍTICA: Solo llamar fromMap si tipo_contribuyente no es null
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
      'tipo_documento': tipoDocumento.toMap(),
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
      'fk_tipo_documento': tipoDocumento.cod_tipo_documento,
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