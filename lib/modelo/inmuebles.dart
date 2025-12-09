import 'package:myapp/modelo/categoria_servicio.dart';
import 'package:myapp/modelo/cliente.dart';

class Inmuebles {
  int? id;
  String cod_inmueble;
  String estado;
  String direccion;
  Cliente cliente;
  CategoriaServicio categoriaServicio;

  Inmuebles({
    this.id,
    required this.cod_inmueble,
    required this.estado,
    required this.direccion,
    required this.cliente,
    required this.categoriaServicio,
  });

  factory Inmuebles.fromMap(Map<String, dynamic> map) {
    return Inmuebles(
      id: map['id'],
      cod_inmueble: map['cod_inmueble'],
      estado: map['estado'],
      direccion: map['direccion'],
      cliente: Cliente.fromMap(map['fk_cliente']),
      categoriaServicio: CategoriaServicio.fromMap(map['fk_categoria_servicio']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cod_inmueble': cod_inmueble,
      'estado': estado,
      'direccion': direccion,
      'fk_cliente': cliente.toMap(),
      'fk_categoria_servicio': categoriaServicio.toMap(),
    };
  }

}
