class ReporteMensual {
  final String idInmueble; // <-- ¡Aquí está el nuevo campo!
  final String nombres;
  final String cedula;
  final String celular;
  final String estadoConexion;
  final double deudaTotal;
  final List<double> meses;

  ReporteMensual({
    required this.idInmueble,
    required this.nombres,
    required this.cedula,
    required this.celular,
    required this.estadoConexion,
    required this.deudaTotal,
    required this.meses,
  });

  factory ReporteMensual.fromJson(Map<String, dynamic> json) {
    return ReporteMensual(
      // Mapeamos el id_inmueble exacto como viene de tu vista SQL
      idInmueble: json['id_inmueble']?.toString() ?? '',
      nombres: json['nombres_y_apellidos']?.toString() ?? '',
      cedula: json['nro_cedula']?.toString() ?? '',
      celular: json['nro_celular']?.toString() ?? '',
      estadoConexion: json['estado_conexion']?.toString().toUpperCase() ?? 'CONECTADO',
      deudaTotal: (json['deuda_total'] ?? 0).toDouble(),
      meses: [
        (json['enero'] ?? 0).toDouble(),
        (json['febrero'] ?? 0).toDouble(),
        (json['marzo'] ?? 0).toDouble(),
        (json['abril'] ?? 0).toDouble(),
        (json['mayo'] ?? 0).toDouble(),
        (json['junio'] ?? 0).toDouble(),
        (json['julio'] ?? 0).toDouble(),
        (json['agosto'] ?? 0).toDouble(),
        (json['septiembre'] ?? 0).toDouble(),
        (json['octubre'] ?? 0).toDouble(),
        (json['noviembre'] ?? 0).toDouble(),
        (json['diciembre'] ?? 0).toDouble(),
      ],
    );
  }
}