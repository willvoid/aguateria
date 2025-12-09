class TipoDocumento {
  int cod_tipo_documento;
  String descripcion_tipodoc;

  TipoDocumento({
    required this.cod_tipo_documento,
    required this.descripcion_tipodoc,
  });

  //Map -> Tipo Doc
  factory TipoDocumento.fromMap(Map<String, dynamic> map) {
    return TipoDocumento(
      cod_tipo_documento: map['cod_tipodoc'],
      descripcion_tipodoc: map['descripcion_tipodoc'],
    );
  }

  //Tipo Doc -> Map
  Map<String, dynamic> toMap() {
    return {
      'cod_tipodoc': cod_tipo_documento,
      'descripcion_tipodoc': descripcion_tipodoc,
    };
  }
}
