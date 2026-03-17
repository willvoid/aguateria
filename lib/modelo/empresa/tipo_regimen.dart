class TipoRegimen {
  int? id_regimen;
  int codigo_regimen;
  String descripcion;

  TipoRegimen({
    required this.codigo_regimen,
    required this.descripcion,
    this.id_regimen,
  });

  factory TipoRegimen.fromMap(Map<String, dynamic> map) {
    return TipoRegimen(
      id_regimen: map['id_regimen'],
      codigo_regimen: map['codigo_regimen'] ?? 0,
      descripcion: map['descripcion'] ?? '',
    );
  }

  factory TipoRegimen.vacio() {
    return TipoRegimen(codigo_regimen: 0, descripcion: '');
  }

  Map<String, dynamic> toMap() {
    return {
      'id_regimen': id_regimen,
      'codigo_regimen': codigo_regimen,
      'descripcion': descripcion,
    };
  }
}