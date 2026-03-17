import 'package:myapp/modelo/barrio.dart';
import 'package:myapp/modelo/empresa/dato_empresa.dart';

class Establecimiento {
  int? id_establecimiento;
  String codigo_establecimiento;
  String direccion;
  String numero_casa;
  String complemento_direccion_1;
  String? complemento_direccion_2;
  String? telefono;
  String? email;
  String denominacion;
  String estado_establecimiento;
  Barrio fk_barrio;
  DatoEmpresa fk_empresa;

  Establecimiento({
    this.id_establecimiento,
    required this.codigo_establecimiento,
    required this.direccion,
    required this.numero_casa,
    required this.complemento_direccion_1,
    this.complemento_direccion_2,
    this.telefono,
    this.email,
    required this.denominacion,
    required this.estado_establecimiento,
    required this.fk_barrio,
    required this.fk_empresa,
  });

  factory Establecimiento.fromMap(Map<String, dynamic> map) {
    return Establecimiento(
      id_establecimiento: map['id_establecimiento'],
      codigo_establecimiento: map['codigo_establecimiento'] ?? '',
      direccion: map['direccion'] ?? '',
      numero_casa: map['numero_casa'] ?? '',
      complemento_direccion_1: map['complemento_direccion_1'] ?? '',
      complemento_direccion_2: map['complemento_direccion_2'],
      telefono: map['telefono'],
      email: map['email'],
      denominacion: map['denominacion'] ?? '',
      estado_establecimiento: map['estado_establecimiento'] ?? '',
      // En el select de asientos no se hace join anidado de barrio/empresa,
      // así que estos llegan null — se manejan con vacio()
      fk_barrio: map['fk_barrio'] != null
          ? Barrio.fromMap(map['fk_barrio'])
          : Barrio.vacio(),
      fk_empresa: map['fk_empresa'] != null
          ? DatoEmpresa.fromMap(map['fk_empresa'])
          : DatoEmpresa.vacio(),
    );
  }

  // Constructor para cuando el join no trae datos o falla
  factory Establecimiento.vacio() {
    return Establecimiento(
      codigo_establecimiento: '',
      direccion: '',
      numero_casa: '',
      complemento_direccion_1: '',
      denominacion: 'Sin sucursal',
      estado_establecimiento: '',
      fk_barrio: Barrio.vacio(),
      fk_empresa: DatoEmpresa.vacio(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_establecimiento': id_establecimiento,
      'codigo_establecimiento': codigo_establecimiento,
      'direccion': direccion,
      'numero_casa': numero_casa,
      'complemento_direccion_1': complemento_direccion_1,
      'complemento_direccion_2': complemento_direccion_2,
      'telefono': telefono,
      'email': email,
      'denominacion': denominacion,
      'estado_establecimiento': estado_establecimiento,
      'fk_barrio': fk_barrio.toMap(),
      'fk_empresa': fk_empresa.toMap(),
    };
  }
}