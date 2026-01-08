import 'package:myapp/modelo/empresa/dato_empresa.dart';
import 'package:myapp/modelo/empresa/tipo_contribuyente.dart';
import 'package:myapp/modelo/empresa/tipo_regimen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class DatoEmpresaCrudImpl {

  // ==================== HELPERS ====================

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  // ==================== CREAR DATO EMPRESA ====================

  Future<DatoEmpresa?> crearDatoEmpresa(DatoEmpresa empresa) async {
    try {
      final Map<String, dynamic> data = await supabase
          .from('datos_empresa')
          .insert({
            'ruc': empresa.ruc,
            'razon_social': empresa.razon_social,
            'nombre_fantasia': empresa.nombre_fantasia,
            'fk_contribuyente': empresa.fk_contribuyente.id_tipo_contribuyente,
            'fk_regimen': empresa.fk_regimen.id_regimen,
            'estado': empresa.estado,
          })
          .select('*, fk_contribuyente(*), fk_regimen(*)')
          .single();

      print('Dato de empresa creado exitosamente');
      return DatoEmpresa.fromMap(data);
    } catch (e) {
      print('Error al crear dato de empresa: $e');
      return null;
    }
  }

  // ==================== LEER TODOS LOS DATOS DE EMPRESAS ====================

  Future<List<DatoEmpresa>> leerDatosEmpresas() async {
    try {
      final data = await supabase
          .from('datos_empresa')
          .select('*, fk_contribuyente(*), fk_regimen(*)');

      if (data == null) {
        print('La consulta devolvió null');
        return [];
      }

      if (data.isEmpty) {
        print('No hay datos de empresas en la base de datos');
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<DatoEmpresa> empresas = registros.map((mapa) {
        final datosContribuyente = mapa['fk_contribuyente'];
        final datosRegimen = mapa['fk_regimen'];

        if (datosContribuyente == null || datosRegimen == null) {
          throw Exception('Empresa sin tipo de contribuyente o régimen asignado');
        }

        return DatoEmpresa(
          id_empresa: _toInt(mapa['id_empresa']),
          ruc: mapa['ruc'] ?? '',
          razon_social: mapa['razon_social'] ?? '',
          nombre_fantasia: mapa['nombre_fantasia'] ?? '',
          fk_contribuyente: TipoContribuyente.fromMap(datosContribuyente),
          fk_regimen: TipoRegimen.fromMap(datosRegimen),
          estado: mapa['estado'] ?? 'ACTIVO',
        );
      }).toList();

      print('Se cargaron ${empresas.length} datos de empresas');
      return empresas;
    } catch (e) {
      print('Error al leer datos de empresas: $e');
      return [];
    }
  }

  // ==================== LEER DATO EMPRESA POR ID ====================

  Future<DatoEmpresa?> leerDatoEmpresaPorId(int id) async {
    try {
      final Map<String, dynamic> data = await supabase
          .from('datos_empresa')
          .select('*, fk_contribuyente(*), fk_regimen(*)')
          .eq('id_empresa', id)
          .single();

      return DatoEmpresa.fromMap(data);
    } catch (e) {
      print('Error al leer dato de empresa por ID: $e');
      return null;
    }
  }

  // ==================== LEER DATO EMPRESA POR RUC ====================

  Future<DatoEmpresa?> leerDatoEmpresaPorRuc(String ruc) async {
    try {
      final Map<String, dynamic> data = await supabase
          .from('datos_empresa')
          .select('*, fk_contribuyente(*), fk_regimen(*)')
          .eq('ruc', ruc)
          .single();

      return DatoEmpresa.fromMap(data);
    } catch (e) {
      print('Error al leer dato de empresa por RUC: $e');
      return null;
    }
  }

  // ==================== BUSCAR DATOS DE EMPRESAS ====================

  Future<List<DatoEmpresa>> buscarDatosEmpresas(String busqueda) async {
    try {
      final data = await supabase
          .from('datos_empresa')
          .select('*, fk_contribuyente(*), fk_regimen(*)')
          .or('ruc.ilike.%$busqueda%,razon_social.ilike.%$busqueda%,nombre_fantasia.ilike.%$busqueda%');

      if (data == null || data.isEmpty) {
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<DatoEmpresa> empresas = registros.map((mapa) {
        return DatoEmpresa.fromMap(mapa);
      }).toList();

      return empresas;
    } catch (e) {
      print('Error al buscar datos de empresas: $e');
      return [];
    }
  }

  // ==================== BUSCAR POR TIPO DE CONTRIBUYENTE ====================

  Future<List<DatoEmpresa>> buscarPorTipoContribuyente(int idContribuyente) async {
    try {
      final data = await supabase
          .from('datos_empresa')
          .select('*, fk_contribuyente(*), fk_regimen(*)')
          .eq('fk_contribuyente', idContribuyente);

      if (data == null || data.isEmpty) {
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<DatoEmpresa> empresas = registros.map((mapa) {
        return DatoEmpresa.fromMap(mapa);
      }).toList();

      return empresas;
    } catch (e) {
      print('Error al buscar empresas por tipo de contribuyente: $e');
      return [];
    }
  }

  // ==================== BUSCAR POR TIPO DE RÉGIMEN ====================

  Future<List<DatoEmpresa>> buscarPorTipoRegimen(int idRegimen) async {
    try {
      final data = await supabase
          .from('datos_empresa')
          .select('*, fk_contribuyente(*), fk_regimen(*)')
          .eq('fk_regimen', idRegimen);

      if (data == null || data.isEmpty) {
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<DatoEmpresa> empresas = registros.map((mapa) {
        return DatoEmpresa.fromMap(mapa);
      }).toList();

      return empresas;
    } catch (e) {
      print('Error al buscar empresas por tipo de régimen: $e');
      return [];
    }
  }

  // ==================== BUSCAR POR ESTADO ====================

  Future<List<DatoEmpresa>> buscarPorEstado(String estado) async {
    try {
      final data = await supabase
          .from('datos_empresa')
          .select('*, fk_contribuyente(*), fk_regimen(*)')
          .eq('estado', estado);

      if (data == null || data.isEmpty) {
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<DatoEmpresa> empresas = registros.map((mapa) {
        return DatoEmpresa.fromMap(mapa);
      }).toList();

      return empresas;
    } catch (e) {
      print('Error al buscar empresas por estado: $e');
      return [];
    }
  }

  // ==================== ACTUALIZAR DATO EMPRESA ====================

  Future<bool> actualizarDatoEmpresa(DatoEmpresa empresa) async {
    try {
      await supabase
          .from('datos_empresa')
          .update({
            'ruc': empresa.ruc,
            'razon_social': empresa.razon_social,
            'nombre_fantasia': empresa.nombre_fantasia,
            'fk_contribuyente': empresa.fk_contribuyente.id_tipo_contribuyente,
            'fk_regimen': empresa.fk_regimen.id_regimen,
            'estado': empresa.estado,
          })
          .eq('id_empresa', empresa.id_empresa!);

      print('Dato de empresa actualizado exitosamente');
      return true;
    } catch (e) {
      print('Error al actualizar dato de empresa: $e');
      return false;
    }
  }

  // ==================== CAMBIAR ESTADO EMPRESA ====================

  Future<bool> cambiarEstadoEmpresa(int idEmpresa, String nuevoEstado) async {
    try {
      await supabase
          .from('datos_empresa')
          .update({'estado': nuevoEstado})
          .eq('id_empresa', idEmpresa);

      print('Estado de empresa actualizado a: $nuevoEstado');
      return true;
    } catch (e) {
      print('Error al cambiar estado de empresa: $e');
      return false;
    }
  }

  // ==================== ELIMINAR DATO EMPRESA ====================

  Future<bool> eliminarDatoEmpresa(int id) async {
    try {
      await supabase
          .from('datos_empresa')
          .delete()
          .eq('id_empresa', id);

      print('Dato de empresa eliminado exitosamente');
      return true;
    } catch (e) {
      print('Error al eliminar dato de empresa: $e');
      return false;
    }
  }

  // ==================== VERIFICAR RUC EXISTENTE ====================

  Future<bool> verificarRucExistente(String ruc, {int? idEmpresaExcluir}) async {
    try {
      var query = supabase
          .from('datos_empresa')
          .select('id_empresa')
          .eq('ruc', ruc);

      if (idEmpresaExcluir != null) {
        query = query.neq('id_empresa', idEmpresaExcluir);
      }

      final data = await query;

      return data.isNotEmpty;
    } catch (e) {
      print('Error al verificar RUC: $e');
      return false;
    }
  }

  // ==================== VERIFICAR RAZÓN SOCIAL EXISTENTE ====================

  Future<bool> verificarRazonSocialExistente(String razonSocial, {int? idEmpresaExcluir}) async {
    try {
      var query = supabase
          .from('datos_empresa')
          .select('id_empresa')
          .eq('razon_social', razonSocial);

      if (idEmpresaExcluir != null) {
        query = query.neq('id_empresa', idEmpresaExcluir);
      }

      final data = await query;

      return data.isNotEmpty;
    } catch (e) {
      print('Error al verificar razón social: $e');
      return false;
    }
  }

  // ==================== CONTAR EMPRESAS ====================

  Future<int> contarEmpresas() async {
    try {
      final data = await supabase
          .from('datos_empresa')
          .select('id_empresa')
          .count();

      return data.count;
    } catch (e) {
      print('Error al contar empresas: $e');
      return 0;
    }
  }

  // ==================== CONTAR EMPRESAS POR ESTADO ====================

  Future<int> contarEmpresasPorEstado(String estado) async {
    try {
      final data = await supabase
          .from('datos_empresa')
          .select('id_empresa')
          .eq('estado', estado)
          .count();

      return data.count;
    } catch (e) {
      print('Error al contar empresas por estado: $e');
      return 0;
    }
  }
}