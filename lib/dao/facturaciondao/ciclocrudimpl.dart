import 'package:myapp/modelo/facturacionmodelo/ciclo.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class CicloCrudImpl {

  // ==================== HELPERS ====================

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  DateTime _toDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  // ==================== CREAR CICLO ====================

  Future<bool> crearCiclo(Ciclo ciclo) async {
    try {
      await supabase.from('ciclos').insert({
        'inicio': ciclo.inicio.toIso8601String(),
        'fin': ciclo.fin.toIso8601String(),
        'vencimiento': ciclo.vencimiento.toIso8601String(),
        'anio': ciclo.anio,
        'descripcion': ciclo.descripcion,
        'ciclo': ciclo.ciclo,
        'estado': ciclo.estado,
      });

      return true;
    } catch (e) {
      print('Error al crear ciclo: $e');
      return false;
    }
  }

  // ==================== LEER TODOS LOS CICLOS ====================

  Future<List<Ciclo>> leerCiclos() async {
    try {
      final data = await supabase
          .from('ciclos')
          .select()
          .order('anio', ascending: false)
          .order('inicio', ascending: false);

      if (data == null || data.isEmpty) return [];

      return List<Map<String, dynamic>>.from(data).map((mapa) {
        return Ciclo(
          id: _toInt(mapa['id_ciclos']),
          inicio: _toDate(mapa['inicio']),
          fin: _toDate(mapa['fin']),
          vencimiento: _toDate(mapa['vencimiento']),
          anio: _toInt(mapa['anio']),
          descripcion: mapa['descripcion'] ?? '',
          ciclo: mapa['ciclo'] ?? '',
          estado: mapa['estado'] ?? 'ACTIVO',
        );
      }).toList();

    } catch (e) {
      print('Error al leer ciclos: $e');
      return [];
    }
  }

  // ==================== LEER CICLO POR ID ====================

  Future<Ciclo?> leerCicloPorId(int idCiclo) async {
    try {
      final data = await supabase
          .from('ciclos')
          .select()
          .eq('id_ciclos', idCiclo)
          .single();

      return Ciclo.fromMap(data);
    } catch (e) {
      print('Error al leer ciclo por ID: $e');
      return null;
    }
  }

  // ==================== ACTUALIZAR CICLO ====================

  Future<bool> actualizarCiclo(Ciclo ciclo) async {
    try {
      await supabase.from('ciclos').update({
        'inicio': ciclo.inicio.toIso8601String(),
        'fin': ciclo.fin.toIso8601String(),
        'vencimiento': ciclo.vencimiento.toIso8601String(),
        'anio': ciclo.anio,
        'descripcion': ciclo.descripcion,
        'ciclo': ciclo.ciclo,
        'estado': ciclo.estado,
      }).eq('id_ciclos', ciclo.id!);

      return true;
    } catch (e) {
      print('Error al actualizar ciclo: $e');
      return false;
    }
  }

  // ==================== ELIMINAR CICLO ====================

  Future<bool> eliminarCiclo(int idCiclo) async {
    try {
      await supabase.from('ciclos').delete().eq('id_ciclos', idCiclo);
      return true;
    } catch (e) {
      print('Error al eliminar ciclo: $e');
      return false;
    }
  }

  // ==================== VERIFICAR CICLO EXISTENTE ====================

  Future<bool> verificarCicloExistente(String ciclo, {int? idExcluir}) async {
    try {
      var query = supabase.from('ciclos').select('id_ciclos').eq('ciclo', ciclo);

      if (idExcluir != null) {
        query = query.neq('id_ciclos', idExcluir);
      }

      final data = await query;
      return data.isNotEmpty;
    } catch (e) {
      print('Error al verificar ciclo existente: $e');
      return false;
    }
  }

  // ==================== VERIFICAR SOLAPAMIENTO DE FECHAS ====================

  Future<bool> verificarSolapamientoFechas(
    DateTime inicio,
    DateTime fin, {
    int? idExcluir,
  }) async {
    try {
      var query = supabase
          .from('ciclos')
          .select('id_ciclos')
          .or('and(inicio.lte.${fin.toIso8601String()},fin.gte.${inicio.toIso8601String()})');

      if (idExcluir != null) {
        query = query.neq('id_ciclos', idExcluir);
      }

      final data = await query;
      return data.isNotEmpty;
    } catch (e) {
      print('Error al verificar solapamiento de fechas: $e');
      return false;
    }
  }

  // ==================== LEER CICLOS POR AÑO ====================

  Future<List<Ciclo>> leerCiclosPorAnio(int anio) async {
    try {
      final data = await supabase
          .from('ciclos')
          .select()
          .eq('anio', anio)
          .order('inicio', ascending: true);

      if (data == null || data.isEmpty) return [];

      return List<Map<String, dynamic>>.from(data).map((mapa) {
        return Ciclo.fromMap(mapa);
      }).toList();

    } catch (e) {
      print('Error al leer ciclos por año: $e');
      return [];
    }
  }

  // ==================== LEER CICLO ACTIVO ====================

  Future<Ciclo?> leerCicloActivo() async {
    try {
      final now = DateTime.now();
      final data = await supabase
          .from('ciclos')
          .select()
          .eq('estado', 'ACTIVO')
          .lte('inicio', now.toIso8601String())
          .gte('fin', now.toIso8601String())
          .maybeSingle();

      if (data == null) return null;

      return Ciclo.fromMap(data);
    } catch (e) {
      print('Error al leer ciclo activo: $e');
      return null;
    }
  }
}