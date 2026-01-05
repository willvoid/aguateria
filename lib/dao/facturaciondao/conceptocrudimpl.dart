import 'package:myapp/modelo/categoria_servicio.dart';
import 'package:myapp/modelo/facturacionmodelo/concepto.dart';
import 'package:myapp/modelo/facturacionmodelo/iva.dart';
import 'package:myapp/modelo/facturacionmodelo/unidad_medida.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class ConceptoCrudImpl {

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

  // ==================== CREAR CONCEPTO ====================

  Future<bool> crearConcepto(Concepto concepto) async {
    try {
      await supabase.from('conceptos').insert({
        'nombre': concepto.nombre,
        'arancel': concepto.arancel,
        'descripcion': concepto.descripcion,
        'fk_iva': concepto.fk_iva.id,
        'fk_unidad_medida': concepto.fk_unidad_medida.id,
        'estado': concepto.estado,
        'fk_servicio': concepto.fk_servicio.id,
      });

      return true;
    } catch (e) {
      print('Error al crear concepto: $e');
      return false;
    }
  }

  // ==================== LEER TODOS LOS CONCEPTOS ====================

  Future<List<Concepto>> leerConceptos() async {
    try {
      final data = await supabase.from('conceptos').select('''
        *,
        fk_iva(*),
        fk_unidad_medida(*),
        fk_servicio(*)
      ''');

      if (data == null || data.isEmpty) return [];

      return List<Map<String, dynamic>>.from(data).map((mapa) {
        final datosIva = mapa['fk_iva'];
        final datosUnidadMedida = mapa['fk_unidad_medida'];
        final datosServicio = mapa['fk_servicio'];

        if (datosIva == null || datosUnidadMedida == null || datosServicio == null) {
          throw Exception('Concepto con relaciones incompletas');
        }

        final iva = Iva(
          id: _toInt(datosIva['id_iva']),
          descripcion: datosIva['descripcion'] ?? '',
          valor: _toInt(datosIva['valor']),
        );

        final unidadMedida = UnidadMedida(
          id: _toInt(datosUnidadMedida['id_unidades']),
          cod_unidades_medida: _toInt(datosUnidadMedida['cod_unidades_medida']),
          representacion: datosUnidadMedida['representacion'] ?? '',
          descripcion: datosUnidadMedida['descripcion'] ?? '',
        );

        final categoriaServicio = CategoriaServicio.fromMap(datosServicio);

        return Concepto(
          id: _toInt(mapa['id_concepto']),
          nombre: mapa['nombre'] ?? '',
          arancel: _toDouble(mapa['arancel']),
          descripcion: mapa['descripcion'] ?? '',
          fk_iva: iva,
          fk_unidad_medida: unidadMedida,
          estado: mapa['estado'] ?? 'ACTIVO',
          fk_servicio: categoriaServicio,
        );
      }).toList();

    } catch (e) {
      print('Error al leer conceptos: $e');
      return [];
    }
  }

  // ==================== LEER CONCEPTO POR ID ====================

  Future<Concepto?> leerConceptoPorId(int idConcepto) async {
    try {
      final data = await supabase
          .from('conceptos')
          .select('''
            *,
            fk_iva(*),
            fk_unidad_medida(*),
            fk_servicio(*)
          ''')
          .eq('id_concepto', idConcepto)
          .single();

      return Concepto.fromMap(data);
    } catch (e) {
      print('Error al leer concepto por ID: $e');
      return null;
    }
  }

  // ==================== ACTUALIZAR CONCEPTO ====================

  Future<bool> actualizarConcepto(Concepto concepto) async {
    try {
      await supabase.from('conceptos').update({
        'nombre': concepto.nombre,
        'arancel': concepto.arancel,
        'descripcion': concepto.descripcion,
        'fk_iva': concepto.fk_iva.id,
        'fk_unidad_medida': concepto.fk_unidad_medida.id,
        'estado': concepto.estado,
        'fk_servicio': concepto.fk_servicio.id,
      }).eq('id_concepto', concepto.id!);

      return true;
    } catch (e) {
      print('Error al actualizar concepto: $e');
      return false;
    }
  }

  // ==================== ELIMINAR CONCEPTO ====================

  Future<bool> eliminarConcepto(int idConcepto) async {
    try {
      await supabase.from('conceptos').delete().eq('id_concepto', idConcepto);
      return true;
    } catch (e) {
      print('Error al eliminar concepto: $e');
      return false;
    }
  }

  // ==================== VERIFICAR NOMBRE DE CONCEPTO EXISTENTE ====================

  Future<bool> verificarNombreConceptoExistente(String nombre, {int? idExcluir}) async {
    try {
      var query = supabase.from('conceptos').select('id_concepto').eq('nombre', nombre);

      if (idExcluir != null) {
        query = query.neq('id_concepto', idExcluir);
      }

      final data = await query;
      return data.isNotEmpty;
    } catch (e) {
      print('Error al verificar nombre de concepto: $e');
      return false;
    }
  }

  // ==================== LEER CONCEPTOS POR SERVICIO ====================

  Future<List<Concepto>> leerConceptosPorServicio(int idServicio) async {
    try {
      final data = await supabase
          .from('conceptos')
          .select('''
            *,
            fk_iva(*),
            fk_unidad_medida(*),
            fk_servicio(*)
          ''')
          .eq('fk_servicio', idServicio);

      if (data == null || data.isEmpty) return [];

      return List<Map<String, dynamic>>.from(data).map((mapa) {
        return Concepto.fromMap(mapa);
      }).toList();

    } catch (e) {
      print('Error al leer conceptos por servicio: $e');
      return [];
    }
  }
}