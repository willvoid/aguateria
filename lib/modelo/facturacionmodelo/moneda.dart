class Moneda {
  int? id_monedas;
  int cod_moneda;
  int num;
  int dec;
  String divisa;
  double cotizacion_gs;

  Moneda({
    this.id_monedas,
    required this.cod_moneda,
    required this.num,
    required this.dec,
    required this.divisa,
    required this.cotizacion_gs,
  });

  factory Moneda.fromMap(Map<String, dynamic> map) {
    return Moneda(
      id_monedas: map['id_monedas'],
      cod_moneda: map['cod_moneda'],
      num: map['num'],
      dec: map['dec'],
      divisa: map['divisa'],
      cotizacion_gs: map['cotizacion_gs'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_monedas': id_monedas,
      'cod_moneda': cod_moneda,
      'num': num,
      'dec': dec,
      'divisa': divisa,
      'cotizacion_gs': cotizacion_gs,
    };
  } 

}
