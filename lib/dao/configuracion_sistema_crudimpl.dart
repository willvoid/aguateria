import 'package:myapp/modelo/empresa/establecimiento.dart';
import 'package:myapp/modelo/facturacionmodelo/modo_pago.dart';
import 'package:myapp/modelo/facturacionmodelo/moneda.dart';
import 'package:myapp/modelo/facturacionmodelo/tipo_factura.dart';
import 'package:myapp/modelo/configuracion_sistema.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class ConfiguracionSistemaCrudImpl {
  
  // ==================== CREAR CONFIGURACIÓN ====================
  Future<ConfiguracionSistema?> crearConfiguracion(ConfiguracionSistema config) async {
    try {
      final Map<String, dynamic> data = await supabase
          .from('configuracion_sistema')
          .insert({
            'fk_establecimiento_default': config.establecimiento_default.id_establecimiento,
            'fk_moneda_default': config.moneda_default.id_monedas,
            'fk_modo_pago_default': config.modo_pago_default.id_modo_pago,
            'fk_tipo_factura_default': config.tipo_factura_default.id_tipo_factura,
            'condicion_venta_default': config.condicion_venta_default,
          })
          .select()
          .single();

      print('Configuración creada exitosamente');
      return ConfiguracionSistema.fromMap(data);
    } catch (e) {
      print('Error al crear configuración: $e');
      return null;
    }
  }

// ==================== LEER CONFIGURACIÓN ACTUAL ====================
Future<ConfiguracionSistema?> leerConfiguracionActual() async {
  try {
    final configData = await supabase
        .from('configuracion_sistema')
        .select()
        .order('id_config', ascending: false)
        .limit(1);

    if (configData == null || configData.isEmpty) {
      print('⚠️ No se encontró configuración del sistema');
      return null;
    }

    final config = configData.first as Map<String, dynamic>;
    
    print('📋 Config base: $config');

    // Usar la MISMA sintaxis que EstablecimientoCrudImpl
    final establecimientoData = await supabase
        .from('establecimientos')
        .select('*, fk_barrio(*), fk_empresa(*, fk_contribuyente(*), fk_regimen(*))')
        .eq('id_establecimiento', config['establecimiento_default'])
        .maybeSingle();

    if (establecimientoData == null) {
      print('❌ No se encontró el establecimiento');
      return null;
    }

    print('🏢 Establecimiento cargado');

    // Cargar moneda
    final monedaData = await supabase
        .from('monedas')
        .select()
        .eq('id_monedas', config['moneda_default'])
        .maybeSingle();

    if (monedaData == null) {
      print('❌ No se encontró la moneda');
      return null;
    }

    // Cargar modo pago
    final modoPagoData = await supabase
        .from('modo_pago')
        .select()
        .eq('id_modo_pago', config['modo_pago_default'])
        .maybeSingle();

    if (modoPagoData == null) {
      print('❌ No se encontró el modo de pago');
      return null;
    }

    // Cargar tipo factura
    final tipoFacturaData = await supabase
        .from('tipo_factura')
        .select()
        .eq('id_tipo_factura', config['tipo_factura_default'])
        .maybeSingle();

    if (tipoFacturaData == null) {
      print('❌ No se encontró el tipo de factura');
      return null;
    }

    print('✅ Configuración cargada exitosamente');

    return ConfiguracionSistema(
      id_config: config['id_config'] as int,
      establecimiento_default: Establecimiento.fromMap(establecimientoData as Map<String, dynamic>),
      moneda_default: Moneda.fromMap(monedaData as Map<String, dynamic>),
      modo_pago_default: ModoPago.fromMap(modoPagoData as Map<String, dynamic>),
      tipo_factura_default: TipoFactura.fromMap(tipoFacturaData as Map<String, dynamic>),
      condicion_venta_default: config['condicion_venta_default'] as int,
    );
  } catch (e, stackTrace) {
    print('❌ Error al leer configuración actual: $e');
    print('📍 Stack trace: $stackTrace');
    return null;
  }
}
  // ==================== LEER CONFIGURACIÓN POR ID ====================
  Future<ConfiguracionSistema?> leerConfiguracionPorId(int idConfig) async {
    try {
      final Map<String, dynamic> data = await supabase
          .from('configuracion_sistema')
          .select('''
            *,
            establecimiento_default:fk_establecimiento_default(*),
            moneda_default:fk_moneda_default(*),
            modo_pago_default:fk_modo_pago_default(*),
            tipo_factura_default:fk_tipo_factura_default(*)
          ''')
          .eq('id_config', idConfig)
          .single();

      return ConfiguracionSistema(
        id_config: data['id_config'],
        establecimiento_default: Establecimiento.fromMap(data['establecimiento_default']),
        moneda_default: Moneda.fromMap(data['moneda_default']),
        modo_pago_default: ModoPago.fromMap(data['modo_pago_default']),
        tipo_factura_default: TipoFactura.fromMap(data['tipo_factura_default']),
        condicion_venta_default: data['condicion_venta_default'],
      );
    } catch (e) {
      print('Error al leer configuración por ID: $e');
      return null;
    }
  }

  // ==================== LEER TODAS LAS CONFIGURACIONES ====================
  Future<List<ConfiguracionSistema>> leerConfiguraciones() async {
    try {
      final data = await supabase
          .from('configuracion_sistema')
          .select('''
            *,
            establecimiento_default:fk_establecimiento_default(*),
            moneda_default:fk_moneda_default(*),
            modo_pago_default:fk_modo_pago_default(*),
            tipo_factura_default:fk_tipo_factura_default(*)
          ''')
          .order('id_config', ascending: false);

      if (data == null) {
        print('⚠️ La consulta devolvió null');
        return [];
      }

      if (data.isEmpty) {
        print('ℹ️ No hay configuraciones en la base de datos');
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<ConfiguracionSistema> configuraciones = registros.map((mapa) {
        return ConfiguracionSistema(
          id_config: mapa['id_config'],
          establecimiento_default: Establecimiento.fromMap(mapa['establecimiento_default']),
          moneda_default: Moneda.fromMap(mapa['moneda_default']),
          modo_pago_default: ModoPago.fromMap(mapa['modo_pago_default']),
          tipo_factura_default: TipoFactura.fromMap(mapa['tipo_factura_default']),
          condicion_venta_default: mapa['condicion_venta_default'],
        );
      }).toList();

      print('✓ Se cargaron ${configuraciones.length} configuraciones');
      return configuraciones;
    } catch (e) {
      print('Error al leer configuraciones: $e');
      return [];
    }
  }

  // ==================== ACTUALIZAR CONFIGURACIÓN ====================
  Future<bool> actualizarConfiguracion(ConfiguracionSistema config) async {
    try {
      await supabase
          .from('configuracion_sistema')
          .update({
            'fk_establecimiento_default': config.establecimiento_default.id_establecimiento,
            'fk_moneda_default': config.moneda_default.id_monedas,
            'fk_modo_pago_default': config.modo_pago_default.id_modo_pago,
            'fk_tipo_factura_default': config.tipo_factura_default.id_tipo_factura,
            'condicion_venta_default': config.condicion_venta_default,
          })
          .eq('id_config', config.id_config!);

      print('Configuración actualizada exitosamente');
      return true;
    } catch (e) {
      print('Error al actualizar configuración: $e');
      return false;
    }
  }

  // ==================== ELIMINAR CONFIGURACIÓN ====================
  Future<bool> eliminarConfiguracion(int idConfig) async {
    try {
      await supabase
          .from('configuracion_sistema')
          .delete()
          .eq('id_config', idConfig);

      print('Configuración eliminada exitosamente');
      return true;
    } catch (e) {
      print('Error al eliminar configuración: $e');
      return false;
    }
  }

  // ==================== ACTUALIZAR ESTABLECIMIENTO DEFAULT ====================
  Future<bool> actualizarEstablecimientoDefault(int idConfig, int idEstablecimiento) async {
    try {
      await supabase
          .from('configuracion_sistema')
          .update({'fk_establecimiento_default': idEstablecimiento})
          .eq('id_config', idConfig);

      print('Establecimiento default actualizado exitosamente');
      return true;
    } catch (e) {
      print('Error al actualizar establecimiento default: $e');
      return false;
    }
  }

  // ==================== ACTUALIZAR MONEDA DEFAULT ====================
  Future<bool> actualizarMonedaDefault(int idConfig, int idMoneda) async {
    try {
      await supabase
          .from('configuracion_sistema')
          .update({'fk_moneda_default': idMoneda})
          .eq('id_config', idConfig);

      print('Moneda default actualizada exitosamente');
      return true;
    } catch (e) {
      print('Error al actualizar moneda default: $e');
      return false;
    }
  }

  // ==================== ACTUALIZAR MODO PAGO DEFAULT ====================
  Future<bool> actualizarModoPagoDefault(int idConfig, int idModoPago) async {
    try {
      await supabase
          .from('configuracion_sistema')
          .update({'fk_modo_pago_default': idModoPago})
          .eq('id_config', idConfig);

      print('Modo de pago default actualizado exitosamente');
      return true;
    } catch (e) {
      print('Error al actualizar modo de pago default: $e');
      return false;
    }
  }

  // ==================== ACTUALIZAR TIPO FACTURA DEFAULT ====================
  Future<bool> actualizarTipoFacturaDefault(int idConfig, int idTipoFactura) async {
    try {
      await supabase
          .from('configuracion_sistema')
          .update({'fk_tipo_factura_default': idTipoFactura})
          .eq('id_config', idConfig);

      print('Tipo de factura default actualizado exitosamente');
      return true;
    } catch (e) {
      print('Error al actualizar tipo de factura default: $e');
      return false;
    }
  }

  // ==================== ACTUALIZAR CONDICIÓN VENTA DEFAULT ====================
  Future<bool> actualizarCondicionVentaDefault(int idConfig, int condicionVenta) async {
    try {
      await supabase
          .from('configuracion_sistema')
          .update({'condicion_venta_default': condicionVenta})
          .eq('id_config', idConfig);

      print('Condición de venta default actualizada exitosamente');
      return true;
    } catch (e) {
      print('Error al actualizar condición de venta default: $e');
      return false;
    }
  }

  // ==================== VERIFICAR SI EXISTE CONFIGURACIÓN ====================
  Future<bool> existeConfiguracion() async {
    try {
      final data = await supabase
          .from('configuracion_sistema')
          .select('id_config')
          .limit(1);

      return data.isNotEmpty;
    } catch (e) {
      print('Error al verificar existencia de configuración: $e');
      return false;
    }
  }
}