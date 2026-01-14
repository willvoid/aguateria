import 'package:myapp/modelo/usuario/usuario.dart';
import 'package:myapp/modelo/usuario/cargo.dart';
import 'package:myapp/modelo/ tipo_documento.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bcrypt/bcrypt.dart';

final supabase = Supabase.instance.client;

class UsuarioCrudImpl {

  // ==================== HELPERS ====================

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  /// Hash de contraseña usando bcrypt (seguro)
  String _hashPassword(String password) {
    return BCrypt.hashpw(password, BCrypt.gensalt());
  }

  /// Verificar contraseña contra hash bcrypt
  bool _verifyPassword(String password, String hashedPassword) {
    try {
      return BCrypt.checkpw(password, hashedPassword);
    } catch (e) {
      print('Error al verificar contraseña: $e');
      return false;
    }
  }

  // ==================== CREAR USUARIO ====================

  Future<Usuario?> crearUsuario(Usuario usuario) async {
    try {
      final claveHasheada = _hashPassword(usuario.clave);

      final Map<String, dynamic> data = await supabase
          .from('usuario')
          .insert({
            'documento': usuario.documento,
            'nombre': usuario.nombre,
            'correo': usuario.correo,
            'usuario': usuario.usuario,
            'clave': claveHasheada,
            'fk_cargo': usuario.fk_cargo.id_cargo,
            'fk_tipo_doc': usuario.fk_tipo_doc.cod_tipo_documento,
            'telefono': usuario.telefono,
          })
          .select('''
            *,
            fk_cargo:cargo(*),
            fk_tipo_doc:tipo_documento(*)
          ''')
          .single();

      print('Usuario creado exitosamente');
      return Usuario.fromMap(data);
    } catch (e) {
      print('Error al crear usuario: $e');
      return null;
    }
  }

  // ==================== LEER TODOS LOS USUARIOS ====================

  Future<List<Usuario>> leerUsuarios() async {
    try {
      final data = await supabase
          .from('usuario')
          .select('''
            *,
            fk_cargo:cargo(*),
            fk_tipo_doc:tipo_documento(*)
          ''');

      if (data == null || data.isEmpty) {
        print('No hay usuarios en la base de datos');
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<Usuario> usuarios = registros.map((mapa) {
        return Usuario.fromMap(mapa);
      }).toList();

      print('Se cargaron ${usuarios.length} usuarios');
      return usuarios;
    } catch (e) {
      print('Error al leer usuarios: $e');
      return [];
    }
  }

  // ==================== LEER USUARIO POR ID ====================

  Future<Usuario?> leerUsuarioPorId(int id) async {
    try {
      final Map<String, dynamic> data = await supabase
          .from('usuario')
          .select('''
            *,
            fk_cargo:cargo(*),
            fk_tipo_doc:tipo_documento(*)
          ''')
          .eq('id_usuario', id)
          .single();

      return Usuario.fromMap(data);
    } catch (e) {
      print('Error al leer usuario por ID: $e');
      return null;
    }
  }

  // ==================== LEER USUARIO POR NOMBRE DE USUARIO ====================

  Future<Usuario?> leerUsuarioPorUsername(String username) async {
    try {
      final Map<String, dynamic> data = await supabase
          .from('usuario')
          .select('''
            *,
            fk_cargo:cargo(*),
            fk_tipo_doc:tipo_documento(*)
          ''')
          .eq('usuario', username)
          .single();

      return Usuario.fromMap(data);
    } catch (e) {
      print('Error al leer usuario por username: $e');
      return null;
    }
  }

  // ==================== LEER USUARIO POR DOCUMENTO ====================

  Future<Usuario?> leerUsuarioPorDocumento(String documento) async {
    try {
      final Map<String, dynamic> data = await supabase
          .from('usuario')
          .select('''
            *,
            fk_cargo:cargo(*),
            fk_tipo_doc:tipo_documento(*)
          ''')
          .eq('documento', documento)
          .single();

      return Usuario.fromMap(data);
    } catch (e) {
      print('Error al leer usuario por documento: $e');
      return null;
    }
  }

  // ==================== BUSCAR USUARIOS ====================

  Future<List<Usuario>> buscarUsuarios(String busqueda) async {
    try {
      final data = await supabase
          .from('usuario')
          .select('''
            *,
            fk_cargo:cargo(*),
            fk_tipo_doc:tipo_documento(*)
          ''')
          .or('nombre.ilike.%$busqueda%,usuario.ilike.%$busqueda%,documento.ilike.%$busqueda%,correo.ilike.%$busqueda%');

      if (data == null || data.isEmpty) {
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<Usuario> usuarios = registros.map((mapa) {
        return Usuario.fromMap(mapa);
      }).toList();

      return usuarios;
    } catch (e) {
      print('Error al buscar usuarios: $e');
      return [];
    }
  }

  // ==================== ACTUALIZAR USUARIO ====================

  Future<bool> actualizarUsuario(Usuario usuario, {bool actualizarClave = false}) async {
    try {
      Map<String, dynamic> updateData = {
        'documento': usuario.documento,
        'nombre': usuario.nombre,
        'correo': usuario.correo,
        'usuario': usuario.usuario,
        'fk_cargo': usuario.fk_cargo.id_cargo,
        'fk_tipo_doc': usuario.fk_tipo_doc.cod_tipo_documento,
        'telefono': usuario.telefono,
      };

      if (actualizarClave) {
        updateData['clave'] = _hashPassword(usuario.clave);
      }

      await supabase
          .from('usuario')
          .update(updateData)
          .eq('id_usuario', usuario.id_usuario!);

      print('Usuario actualizado exitosamente');
      return true;
    } catch (e) {
      print('Error al actualizar usuario: $e');
      return false;
    }
  }

  // ==================== CAMBIAR CONTRASEÑA ====================

  Future<bool> cambiarContrasena(int idUsuario, String claveActual, String claveNueva) async {
    try {
      final usuario = await leerUsuarioPorId(idUsuario);
      if (usuario == null) {
        print('Usuario no encontrado');
        return false;
      }

      if (!_verifyPassword(claveActual, usuario.clave)) {
        print('Contraseña actual incorrecta');
        return false;
      }

      await supabase
          .from('usuario')
          .update({'clave': _hashPassword(claveNueva)})
          .eq('id_usuario', idUsuario);

      print('Contraseña actualizada exitosamente');
      return true;
    } catch (e) {
      print('Error al cambiar contraseña: $e');
      return false;
    }
  }

  // ==================== ELIMINAR USUARIO ====================

  Future<bool> eliminarUsuario(int id) async {
    try {
      await supabase
          .from('usuario')
          .delete()
          .eq('id_usuario', id);

      print('Usuario eliminado exitosamente');
      return true;
    } catch (e) {
      print('Error al eliminar usuario: $e');
      return false;
    }
  }

  // ==================== VERIFICAR USERNAME EXISTENTE ====================

  Future<bool> verificarUsernameExistente(String username, {int? idUsuarioExcluir}) async {
    try {
      var query = supabase
          .from('usuario')
          .select('id_usuario')
          .eq('usuario', username);

      if (idUsuarioExcluir != null) {
        query = query.neq('id_usuario', idUsuarioExcluir);
      }

      final data = await query;
      return data.isNotEmpty;
    } catch (e) {
      print('Error al verificar username: $e');
      return false;
    }
  }

  // ==================== VERIFICAR DOCUMENTO EXISTENTE ====================

  Future<bool> verificarDocumentoExistente(String documento, {int? idUsuarioExcluir}) async {
    try {
      var query = supabase
          .from('usuario')
          .select('id_usuario')
          .eq('documento', documento);

      if (idUsuarioExcluir != null) {
        query = query.neq('id_usuario', idUsuarioExcluir);
      }

      final data = await query;
      return data.isNotEmpty;
    } catch (e) {
      print('Error al verificar documento: $e');
      return false;
    }
  }

  // ==================== VERIFICAR CORREO EXISTENTE ====================

  Future<bool> verificarCorreoExistente(String correo, {int? idUsuarioExcluir}) async {
    try {
      var query = supabase
          .from('usuario')
          .select('id_usuario')
          .eq('correo', correo);

      if (idUsuarioExcluir != null) {
        query = query.neq('id_usuario', idUsuarioExcluir);
      }

      final data = await query;
      return data.isNotEmpty;
    } catch (e) {
      print('Error al verificar correo: $e');
      return false;
    }
  }

  // ==================== AUTENTICAR USUARIO ====================

  Future<Usuario?> autenticarUsuario(String username, String password) async {
    try {
      final usuario = await leerUsuarioPorUsername(username);
      
      if (usuario == null) {
        print('Usuario no encontrado');
        return null;
      }

      if (_verifyPassword(password, usuario.clave)) {
        print('Autenticación exitosa');
        return usuario;
      } else {
        print('Contraseña incorrecta');
        return null;
      }
    } catch (e) {
      print('Error al autenticar usuario: $e');
      return null;
    }
  }

  // ==================== CONTAR USUARIOS ====================

  Future<int> contarUsuarios() async {
    try {
      final data = await supabase
          .from('usuario')
          .select('id_usuario')
          .count();

      return data.count;
    } catch (e) {
      print('Error al contar usuarios: $e');
      return 0;
    }
  }

  // ==================== CONTAR USUARIOS POR CARGO ====================

  Future<int> contarUsuariosPorCargo(int idCargo) async {
    try {
      final data = await supabase
          .from('usuario')
          .select('id_usuario')
          .eq('fk_cargo', idCargo)
          .count();

      return data.count;
    } catch (e) {
      print('Error al contar usuarios por cargo: $e');
      return 0;
    }
  }

  // ==================== LISTAR USUARIOS POR CARGO ====================

  Future<List<Usuario>> listarUsuariosPorCargo(int idCargo) async {
    try {
      final data = await supabase
          .from('usuario')
          .select('''
            *,
            fk_cargo:cargo(*),
            fk_tipo_doc:tipo_documento(*)
          ''')
          .eq('fk_cargo', idCargo);

      if (data == null || data.isEmpty) {
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<Usuario> usuarios = registros.map((mapa) {
        return Usuario.fromMap(mapa);
      }).toList();

      return usuarios;
    } catch (e) {
      print('Error al listar usuarios por cargo: $e');
      return [];
    }
  }

  // ==================== ORDENAR USUARIOS POR NOMBRE ====================

  Future<List<Usuario>> leerUsuariosOrdenados({bool ascendente = true}) async {
    try {
      final data = await supabase
          .from('usuario')
          .select('''
            *,
            fk_cargo:cargo(*),
            fk_tipo_doc:tipo_documento(*)
          ''')
          .order('nombre', ascending: ascendente);

      if (data == null || data.isEmpty) {
        return [];
      }

      final List<Map<String, dynamic>> registros = 
          List<Map<String, dynamic>>.from(data);

      final List<Usuario> usuarios = registros.map((mapa) {
        return Usuario.fromMap(mapa);
      }).toList();

      return usuarios;
    } catch (e) {
      print('Error al leer usuarios ordenados: $e');
      return [];
    }
  }
}