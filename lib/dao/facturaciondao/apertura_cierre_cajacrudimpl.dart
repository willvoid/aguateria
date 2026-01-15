import 'package:myapp/dao/empresadao/cajacrudimpl.dart';
import 'package:myapp/modelo/empresa/caja.dart';
import 'package:myapp/modelo/facturacionmodelo/apertura_cierre_caja.dart';
import 'package:myapp/modelo/usuario/usuario.dart';
import 'package:myapp/dao/usuariodao/usuariocrudimpl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class AperturaCierreCajaCrudImpl {
  final CajaCrudImpl _cajaCrud = CajaCrudImpl();
  final UsuarioCrudImpl _usuarioCrud = UsuarioCrudImpl();
  
  // ==================== HELPERS ====================
  
  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  DateTime _toDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  // ==================== CREAR APERTURA CAJA ====================
  Future<AperturaCierreCaja?> crearAperturaCaja(AperturaCierreCaja apertura) async {
    try {
      final Map<String, dynamic> data = await supabase
          .from('apertura_cierre_caja')
          .insert({
            'apertura': apertura.apertura.toIso8601String(),
            'cierre': apertura.cierre?.toIso8601String(),
            'monto_inicial': apertura.monto_inicial,
            'monto_final': apertura.monto_final,
            'fk_usuario': apertura.fk_usuario.id_usuario,
            'fk_caja': apertura.fk_caja.id_caja,
          })
          .select()
          .single();

      print('Apertura de caja creada exitosamente');
      return await _convertirApertura(data);
    } catch (e) {
      print('Error al crear apertura de caja: $e');
      return null;
    }
  }

  // ==================== LEER TODAS LAS APERTURAS ====================
  Future<List<AperturaCierreCaja>> leerAperturasCaja() async {
    try {
      final data = await supabase
          .from('apertura_cierre_caja')
          .select()
          .order('apertura', ascending: false);

      if (data == null) {
        print('⚠️ La consulta devolvió null');
        return [];
      }

      if (data.isEmpty) {
        print('ℹ️ No hay aperturas de caja en la base de datos');
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<AperturaCierreCaja> aperturas = [];
      
      for (var mapa in registros) {
        try {
          final apertura = await _convertirApertura(mapa);
          aperturas.add(apertura);
        } catch (e) {
          print('Error al convertir apertura: $e');
          continue;
        }
      }

      print('✓ Se cargaron ${aperturas.length} aperturas de caja');
      return aperturas;
    } catch (e) {
      print('Error al leer aperturas de caja: $e');
      return [];
    }
  }

  // ==================== LEER APERTURA POR ID ====================
  Future<AperturaCierreCaja?> leerAperturaPorId(int idTurno) async {
    try {
      final Map<String, dynamic> data = await supabase
          .from('apertura_cierre_caja')
          .select()
          .eq('id_turno', idTurno)
          .single();

      return await _convertirApertura(data);
    } catch (e) {
      print('Error al leer apertura por ID: $e');
      return null;
    }
  }

  // ==================== LEER APERTURAS POR CAJA ====================
  Future<List<AperturaCierreCaja>> leerAperturasPorCaja(int idCaja) async {
    try {
      final data = await supabase
          .from('apertura_cierre_caja')
          .select()
          .eq('fk_caja', idCaja)
          .order('apertura', ascending: false);

      if (data == null || data.isEmpty) {
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<AperturaCierreCaja> aperturas = [];
      
      for (var mapa in registros) {
        try {
          final apertura = await _convertirApertura(mapa);
          aperturas.add(apertura);
        } catch (e) {
          print('Error al convertir apertura: $e');
          continue;
        }
      }

      return aperturas;
    } catch (e) {
      print('Error al leer aperturas por caja: $e');
      return [];
    }
  }

  // ==================== LEER APERTURAS POR USUARIO ====================
  Future<List<AperturaCierreCaja>> leerAperturasPorUsuario(int idUsuario) async {
    try {
      final data = await supabase
          .from('apertura_cierre_caja')
          .select()
          .eq('fk_usuario', idUsuario)
          .order('apertura', ascending: false);

      if (data == null || data.isEmpty) {
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<AperturaCierreCaja> aperturas = [];
      
      for (var mapa in registros) {
        try {
          final apertura = await _convertirApertura(mapa);
          aperturas.add(apertura);
        } catch (e) {
          print('Error al convertir apertura: $e');
          continue;
        }
      }

      return aperturas;
    } catch (e) {
      print('Error al leer aperturas por usuario: $e');
      return [];
    }
  }

  // ==================== OBTENER CAJA ABIERTA (SIN CIERRE) ====================
  Future<AperturaCierreCaja?> obtenerCajaAbierta(int idCaja) async {
    try {
      final data = await supabase
          .from('apertura_cierre_caja')
          .select()
          .eq('fk_caja', idCaja)
          .isFilter('cierre', null)
          .order('apertura', ascending: false)
          .limit(1);

      if (data == null || data.isEmpty) {
        return null;
      }

      return await _convertirApertura(data.first);
    } catch (e) {
      print('Error al obtener caja abierta: $e');
      return null;
    }
  }

  // ==================== CERRAR CAJA ====================
  Future<bool> cerrarCaja(int idTurno, double montoFinal, DateTime fechaCierre) async {
    try {
      await supabase
          .from('apertura_cierre_caja')
          .update({
            'cierre': fechaCierre.toIso8601String(),
            'monto_final': montoFinal,
          })
          .eq('id_turno', idTurno);

      print('Caja cerrada exitosamente');
      return true;
    } catch (e) {
      print('Error al cerrar caja: $e');
      return false;
    }
  }

  // ==================== ACTUALIZAR APERTURA CAJA ====================
  Future<bool> actualizarAperturaCaja(AperturaCierreCaja apertura) async {
    try {
      await supabase
          .from('apertura_cierre_caja')
          .update({
            'apertura': apertura.apertura.toIso8601String(),
            'cierre': apertura.cierre?.toIso8601String(),
            'monto_inicial': apertura.monto_inicial,
            'monto_final': apertura.monto_final,
            'fk_usuario': apertura.fk_usuario.id_usuario,
            'fk_caja': apertura.fk_caja.id_caja,
          })
          .eq('id_turno', apertura.id_turno!);

      print('Apertura de caja actualizada exitosamente');
      return true;
    } catch (e) {
      print('Error al actualizar apertura de caja: $e');
      return false;
    }
  }

  // ==================== ELIMINAR APERTURA CAJA ====================
  Future<bool> eliminarAperturaCaja(int idTurno) async {
    try {
      await supabase
          .from('apertura_cierre_caja')
          .delete()
          .eq('id_turno', idTurno);

      print('Apertura de caja eliminada exitosamente');
      return true;
    } catch (e) {
      print('Error al eliminar apertura de caja: $e');
      return false;
    }
  }

  // ==================== LEER APERTURAS POR RANGO DE FECHAS ====================
  Future<List<AperturaCierreCaja>> leerAperturasPorRangoFechas(
    DateTime fechaInicio, 
    DateTime fechaFin
  ) async {
    try {
      final data = await supabase
          .from('apertura_cierre_caja')
          .select()
          .gte('apertura', fechaInicio.toIso8601String())
          .lte('apertura', fechaFin.toIso8601String())
          .order('apertura', ascending: false);

      if (data == null || data.isEmpty) {
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<AperturaCierreCaja> aperturas = [];
      
      for (var mapa in registros) {
        try {
          final apertura = await _convertirApertura(mapa);
          aperturas.add(apertura);
        } catch (e) {
          print('Error al convertir apertura: $e');
          continue;
        }
      }

      return aperturas;
    } catch (e) {
      print('Error al leer aperturas por rango de fechas: $e');
      return [];
    }
  }

  // ==================== VERIFICAR SI HAY CAJA ABIERTA PARA USUARIO ====================
  Future<bool> verificarCajaAbiertaUsuario(int idUsuario) async {
    try {
      final List<dynamic> data = await supabase
          .from('apertura_cierre_caja')
          .select('id_turno')
          .eq('fk_usuario', idUsuario)
          .isFilter('cierre', null);

      return data.isNotEmpty;
    } catch (e) {
      print('Error al verificar caja abierta para usuario: $e');
      return false;
    }
  }

  // ==================== OBTENER ÚLTIMO TURNO DE CAJA ====================
  Future<AperturaCierreCaja?> obtenerUltimoTurnoCaja(int idCaja) async {
    try {
      final data = await supabase
          .from('apertura_cierre_caja')
          .select()
          .eq('fk_caja', idCaja)
          .order('apertura', ascending: false)
          .limit(1);

      if (data == null || data.isEmpty) {
        return null;
      }

      return await _convertirApertura(data.first);
    } catch (e) {
      print('Error al obtener último turno de caja: $e');
      return null;
    }
  }

  // ==================== MÉTODO AUXILIAR PARA CONVERTIR ====================
  Future<AperturaCierreCaja> _convertirApertura(Map<String, dynamic> mapa) async {
    // Extraer IDs
    final idUsuario = _toInt(mapa['fk_usuario']);
    final idCaja = _toInt(mapa['fk_caja']);

    // Cargar usuario y caja por separado
    final usuario = await _usuarioCrud.leerUsuarioPorId(idUsuario);
    final caja = await _cajaCrud.leerCajaPorId(idCaja);

    if (usuario == null) {
      throw Exception('Usuario con ID $idUsuario no encontrado');
    }

    if (caja == null) {
      throw Exception('Caja con ID $idCaja no encontrada');
    }

    return AperturaCierreCaja(
      id_turno: _toInt(mapa['id_turno']),
      apertura: _toDate(mapa['apertura']),
      cierre: mapa['cierre'] != null ? _toDate(mapa['cierre']) : null,
      monto_inicial: _toDouble(mapa['monto_inicial']),
      monto_final: mapa['monto_final'] != null ? _toDouble(mapa['monto_final']) : 0,
      fk_usuario: usuario,
      fk_caja: caja,
    );
  }
}