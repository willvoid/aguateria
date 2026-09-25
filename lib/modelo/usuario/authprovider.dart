// lib/provider/auth_provider.dart
import 'package:flutter/foundation.dart';
import 'package:myapp/modelo/usuario/usuario.dart';
import 'package:myapp/dao/usuariodao/usuariocrudimpl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthProvider extends ChangeNotifier {
  Usuario? _usuarioActual;
  bool _isAuthenticated = false;
  final UsuarioCrudImpl _usuarioCrud = UsuarioCrudImpl();

  Usuario? get usuarioActual => _usuarioActual;
  bool get isAuthenticated => _isAuthenticated;

  // Iniciar sesión
  Future<void> login(Usuario usuario) async {
    _usuarioActual = usuario;
    _isAuthenticated = true;
    
    // Guardar solo el ID en SharedPreferences (por seguridad)
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('usuario_id', usuario.id_usuario!);
    await prefs.setBool('is_authenticated', true);
    
    notifyListeners();
  }

  // Cerrar sesión
  Future<void> logout() async {
    _usuarioActual = null;
    _isAuthenticated = false;

    // Cerrar también la sesión real de Supabase (invalida el JWT/refresh token)
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (e) {
      print('Error al cerrar sesión de Supabase: $e');
    }

    // Limpiar SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    notifyListeners();
  }

  // Cargar sesión guardada (al iniciar la app), basada en la sesión real de Supabase
  Future<bool> cargarSesion() async {
    try {
      final session = Supabase.instance.client.auth.currentSession;

      if (session != null) {
        final correo = session.user.email;
        final usuario = correo != null
            ? await _usuarioCrud.obtenerDatosUsuarioPorCorreo(correo)
            : null;

        if (usuario != null) {
          _usuarioActual = usuario;
          _isAuthenticated = true;

          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('usuario_id', usuario.id_usuario!);
          await prefs.setBool('is_authenticated', true);

          notifyListeners();
          return true;
        } else {
          // Hay sesión de Supabase pero no hay datos de empleado asociados
          await logout();
        }
      }
    } catch (e) {
      print('Error al cargar sesión: $e');
      await logout();
    }

    return false;
  }

  // Recargar datos del usuario actual
  Future<void> recargarUsuario() async {
    if (_usuarioActual?.id_usuario != null) {
      try {
        final usuario = await _usuarioCrud.leerUsuarioPorId(_usuarioActual!.id_usuario!);
        if (usuario != null) {
          _usuarioActual = usuario;
          notifyListeners();
        }
      } catch (e) {
        print('Error al recargar usuario: $e');
      }
    }
  }

  // Getters útiles
  int? get usuarioId => _usuarioActual?.id_usuario;
  String get usuarioNombre => _usuarioActual?.nombre ?? 'Usuario';
  String get usuarioDocumento => _usuarioActual?.documento ?? '';
  String get usuarioCorreo => _usuarioActual?.correo ?? '';
  String get cargoNombre => _usuarioActual?.fk_cargo.descripcion_cargo ?? '';
}