import 'package:myapp/modelo/facturacionmodelo/ciclo.dart';
import 'package:myapp/modelo/medidor.dart';

class Consumo {
  int? id_consumos;
  double lectura_anterior;
  double lectura_actual;
  double consumo_m3;
  Medidor fk_medidores;
  Ciclo fk_ciclo;
  String estado;

  Consumo({
    this.id_consumos,
    required this.lectura_anterior,
    required this.lectura_actual,
    required this.consumo_m3,
    required this.fk_medidores,
    required this.fk_ciclo,
    required this.estado,
  });
  factory Consumo.fromMap(Map<String, dynamic> map) {
    return Consumo(
      id_consumos: map['id_consumos'],
      lectura_anterior: (map['lectura_anterior'] ?? 0).toDouble(),
      lectura_actual: (map['lectura_actual'] ?? 0).toDouble(),
      consumo_m3: (map['consumo_m3'] ?? 0).toDouble(),
      fk_medidores: Medidor.fromMap(map['fk_medidores']),
      fk_ciclo: Ciclo.fromMap(map['fk_ciclo']),
      estado: map['estado'] ?? '',
    );
  }
  Map<String, dynamic> toMap() {
    return {
      'id_consumos': id_consumos,
      'lectura_anterior': lectura_anterior,
      'lectura_actual': lectura_actual,
      'consumo_m3': consumo_m3,
      'fk_medidores': fk_medidores.toMap(),
      'fk_ciclo': fk_ciclo.toMap(),
      'estado': estado,
    };
  }
}
