class ActividadEconomica {
  int? id_actividad_economica;
  int codigo_actividad;
  String descripcion_actividad;
  bool es_principal;

  ActividadEconomica({
    this.id_actividad_economica,
    required this.codigo_actividad,
    required this.descripcion_actividad,
    required this.es_principal,
  });

  factory ActividadEconomica.fromMap(Map<String, dynamic> map) {
    return ActividadEconomica(
      id_actividad_economica: map['id_actividad_economica'],
      codigo_actividad: map['codigo_actividad'],
      descripcion_actividad: map['descripcion_actividad_economica'],
      es_principal: map['es_principal'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_actividad_economica': id_actividad_economica, 
      'codigo_actividad': codigo_actividad,
      'descripcion_actividad_economica': descripcion_actividad,
      'es_principal': es_principal,
    };
  }

}
