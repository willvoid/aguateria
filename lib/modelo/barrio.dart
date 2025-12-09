class Barrio {
  int cod_barrio;
  String nombre_barrio;

  Barrio({required this.cod_barrio, required this.nombre_barrio});

  factory Barrio.fromMap(Map<String, dynamic> map) {
    return Barrio(
      cod_barrio: map['cod_barrio'],
      nombre_barrio: map['nombre_barrio'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'cod_barrio': cod_barrio,
      'nombre_barrio': nombre_barrio,
    };
  }
}
