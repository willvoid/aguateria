class CategoriaServicio {
  int? id;
  String nombre;
  double tarifa_fija;
  double m2_min;
  double m2_max;
  String descripcion;

  CategoriaServicio({
    this.id,
    required this.nombre,
    required this.tarifa_fija,
    required this.m2_min,
    required this.m2_max,
    required this.descripcion,
  });

  factory CategoriaServicio.fromMap(Map<String, dynamic> map) {
    return CategoriaServicio(
      id: map['id'],
      nombre: map['nombre'] ?? '',
      tarifa_fija: (map['tarifa_fija'] ?? 0).toDouble(),
      m2_min: (map['m2_min'] ?? 0).toDouble(),
      m2_max: (map['m2_max'] ?? 0).toDouble(),
      descripcion: map['descripcion'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'tarifa_fija': tarifa_fija,
      'm2_min': m2_min,
      'm2_max': m2_max,
      'descripcion': descripcion,
    };
  }

  @override
  String toString() {
    return 'CategoriaServicio{id: $id, nombre: $nombre, tarifa_fija: $tarifa_fija, m2_min: $m2_min, m2_max: $m2_max, descripcion: $descripcion}';
  }

  factory CategoriaServicio.vacio() {
  return CategoriaServicio(
    id: null,
    nombre: '',
    tarifa_fija: 0,
    m2_min: 0,
    m2_max: 0,
    descripcion: '',
  );
}

  CategoriaServicio copyWith({
    int? id,
    String? nombre,
    double? tarifa_fija,
    double? m2_min,
    double? m2_max,
    String? descripcion,
  }) {
    return CategoriaServicio(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      tarifa_fija: tarifa_fija ?? this.tarifa_fija,
      m2_min: m2_min ?? this.m2_min,
      m2_max: m2_max ?? this.m2_max,
      descripcion: descripcion ?? this.descripcion,
    );
  }
}
