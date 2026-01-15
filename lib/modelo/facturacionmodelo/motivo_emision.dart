class MotivoEmision {
  int? id_motivos;
  String descripcion;

  MotivoEmision({
    this.id_motivos,
    required this.descripcion,
  });

  factory MotivoEmision.fromMap(Map<String, dynamic> map) {
    return MotivoEmision(
      id_motivos: map['id_motivos'],
      descripcion: map['descripcion'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_motivos': id_motivos,
      'descripcion': descripcion,
    };
  } 

}
