import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:myapp/dao/clientecrudimpl.dart';
import 'package:myapp/dao/inmueblescrudimpl.dart';
import 'package:myapp/modelo/cliente.dart';
import 'package:myapp/modelo/inmuebles.dart';
import 'package:myapp/vista/dashboard_clientes/dashboard_clientes.dart';
import 'package:myapp/vista/loginpage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html show window;

class ClienteConsultaPage extends StatefulWidget {
  const ClienteConsultaPage({Key? key}) : super(key: key);

  @override
  State<ClienteConsultaPage> createState() => _ClienteConsultaPageState();
}

class _ClienteConsultaPageState extends State<ClienteConsultaPage> {
  final TextEditingController _documentoController = TextEditingController();
  final ClienteCrudImpl _clienteCrud = ClienteCrudImpl();
  final InmuebleCrudImpl _inmuebleCrud = InmuebleCrudImpl();

  late final AppLinks _appLinks;

  // Variable estática como fallback para móvil
  static String? _ciPendienteStatic;

  // 0 = ingresa CI, 1 = login OAuth, 2 = selector inmuebles
  int _paso = 0;

  bool _isLoading = false;
  String? _emailGoogle;
  String? _nombreGoogle;
  String? _fotoGoogle;

  Cliente? _clienteEncontrado;
  List<Inmuebles> _inmuebles = [];
  Inmuebles? _inmuebleSeleccionado;
  String? _errorMessage;

  // ── Persistencia del CI (web usa localStorage, móvil usa static) ─────────
  void _guardarCI(String documento) {
    if (kIsWeb) {
      html.window.localStorage['ci_pendiente'] = documento;
    } else {
      _ciPendienteStatic = documento;
    }
  }

  String? _recuperarCI() {
    if (kIsWeb) {
      return html.window.localStorage['ci_pendiente'];
    }
    return _ciPendienteStatic;
  }

  void _limpiarCI() {
    if (kIsWeb) {
      html.window.localStorage.remove('ci_pendiente');
    } else {
      _ciPendienteStatic = null;
    }
  }

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
    _restaurarSesionPendiente();

     Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session != null && mounted) {
        final user = session.user;
        final emailSesion = user.email ?? '';

        setState(() {
          _emailGoogle = emailSesion.isEmpty ? 'Sin email' : emailSesion;
          _nombreGoogle = user.userMetadata?['full_name'] ??
              user.userMetadata?['name'] ??
              user.email;
          _fotoGoogle = user.userMetadata?['avatar_url'] ??
              user.userMetadata?['picture'];
          _isLoading = false;
          _errorMessage = null;
        });

        _limpiarCI();
        _cargarInmueblesYNavegar();
      }
    });
  }

  // Restaura el CI guardado si hay sesión activa al volver del OAuth
  Future<void> _restaurarSesionPendiente() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return;

    final ciGuardado = _recuperarCI();
    if (ciGuardado == null || ciGuardado.isEmpty) return;

    _documentoController.text = ciGuardado;
    await _buscarClienteSilencioso(ciGuardado);
  }

  // Igual que _buscarCliente pero sin tocar _paso (lo maneja onAuthStateChange)
  Future<void> _buscarClienteSilencioso(String documento) async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final cliente =
          await _clienteCrud.buscarClientePorDocumento(documento);
      if (!mounted) return;

      if (cliente == null) {
        await Supabase.instance.client.auth.signOut();
        _limpiarCI();
        setState(() {
          _errorMessage =
              'Tu CI no está registrado en el sistema. '
              'Contactá a la oficina para registrarte.';
          _isLoading = false;
          _paso = 0;
        });
        return;
      }

      setState(() {
        _clienteEncontrado = cliente;
        _isLoading = false;
      });

      // Dispara manualmente la carga de inmuebles si ya hay sesión
      _cargarInmueblesYNavegar();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error al restaurar sesión. Intente nuevamente.';
        _isLoading = false;
      });
    }
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();
    _appLinks.uriLinkStream.listen((uri) {
      Supabase.instance.client.auth.getSessionFromUrl(uri);
    });
    final initialUri = await _appLinks.getInitialLink();
    if (initialUri != null) {
      await Supabase.instance.client.auth.getSessionFromUrl(initialUri);
    }
  }

  @override
  void dispose() {
    _documentoController.dispose();
    super.dispose();
  }

  String get _redirectTo => kIsWeb
      ? 'https://aguateria-prueba4.netlify.app'
      : 'com.example.myapp://login-callback';

  Future<void> _buscarCliente() async {
    final documento = _documentoController.text.trim();

    if (documento.isEmpty) {
      setState(() => _errorMessage = 'Por favor, ingrese su número de CI');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _clienteEncontrado = null;
      _inmuebles = [];
      _inmuebleSeleccionado = null;
    });

    try {
      final cliente =
          await _clienteCrud.buscarClientePorDocumento(documento);

      if (cliente == null) {
        setState(() {
          _errorMessage =
              'Tu CI no está registrado en el sistema. '
              'Contactá a la oficina para registrarte.';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _clienteEncontrado = cliente;
        _isLoading = false;
        _paso = 1;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al buscar. Intente nuevamente.';
        _isLoading = false;
      });
    }
  }

  Future<void> _autenticarConGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      _guardarCI(_documentoController.text.trim());
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: _redirectTo,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
    } catch (e) {
      _limpiarCI();
      setState(() {
        _errorMessage =
            'Error al autenticar con Google. Intente nuevamente.';
        _isLoading = false;
      });
    }
  }

  Future<void> _autenticarConFacebook() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      _guardarCI(_documentoController.text.trim());
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.facebook,
        redirectTo: _redirectTo,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
    } catch (e) {
      _limpiarCI();
      setState(() {
        _errorMessage =
            'Error al autenticar con Facebook. Intente nuevamente.';
        _isLoading = false;
      });
    }
  }

  Future<void> _cargarInmueblesYNavegar() async {
    if (_clienteEncontrado == null) return;

    // ── Verificación de email ──────────────────────────────────────────────
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      final emailSesion = session.user.email?.trim().toLowerCase() ?? '';
      final emailBD = _clienteEncontrado!.email?.trim().toLowerCase() ?? '';

      if (emailBD.isNotEmpty &&
          emailSesion.isNotEmpty &&
          emailBD != emailSesion) {
        await Supabase.instance.client.auth.signOut();
        _limpiarCI();
        if (mounted) {
          setState(() {
            _emailGoogle = null;
            _nombreGoogle = null;
            _fotoGoogle = null;
            _clienteEncontrado = null;
            _paso = 0;
            _isLoading = false;
            _errorMessage =
                'El correo de tu cuenta ($emailSesion) no coincide '
                'con el registrado en el sistema.\n'
                'Iniciá sesión con el correo correcto '
                'o contactá a la oficina.';
          });
        }
        return;
      }

      // Si el cliente no tenía email, guardarlo ahora
      if (emailBD.isEmpty && emailSesion.isNotEmpty) {
        await _clienteCrud.actualizarEmailCliente(
          _clienteEncontrado!.idCliente!,
          emailSesion,
        );
      }
    }
    // ──────────────────────────────────────────────────────────────────────

    setState(() => _isLoading = true);

    try {
      final inmuebles = await _inmuebleCrud.leerInmueblesPorCliente(
        _clienteEncontrado!.idCliente!,
      );

      if (!mounted) return;

      setState(() {
        _inmuebles = inmuebles;
        _isLoading = false;
        if (inmuebles.isEmpty) {
          _errorMessage = 'No tiene inmuebles registrados';
        } else if (inmuebles.length > 1) {
          _paso = 2;
        }
      });

      if (inmuebles.length == 1) {
        _seleccionarInmueble(inmuebles.first);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error al cargar inmuebles. Intente nuevamente.';
        _isLoading = false;
      });
    }
  }

  void _seleccionarInmueble(Inmuebles? inmueble) {
    setState(() => _inmuebleSeleccionado = inmueble);
    if (inmueble != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ClienteDashboardPage(
            cliente: _clienteEncontrado!,
            inmueble: inmueble,
          ),
        ),
      );
    }
  }

  Future<void> _cerrarSesion() async {
    await Supabase.instance.client.auth.signOut();
    _limpiarCI();
    setState(() {
      _paso = 0;
      _emailGoogle = null;
      _nombreGoogle = null;
      _fotoGoogle = null;
      _documentoController.clear();
      _clienteEncontrado = null;
      _inmuebles = [];
      _inmuebleSeleccionado = null;
      _errorMessage = null;
    });
  }

  void _volverAlCI() {
    setState(() {
      _paso = 0;
      _clienteEncontrado = null;
      _inmuebles = [];
      _inmuebleSeleccionado = null;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: switch (_paso) {
                            0 => _buildPaso0CiForm(),
                            1 => _buildPaso1Login(),
                            2 => _buildPaso2SelectorInmuebles(),
                            _ => _buildPaso0CiForm(),
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildPaso0CiForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Consulta tu información',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF111827),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Ingresá tu número de CI para comenzar',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        Center(
          child: Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: const Color(0xFF0085FF).withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.badge_outlined,
              size: 52,
              color: Color(0xFF0085FF),
            ),
          ),
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _documentoController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: 'Número de CI',
            hintText: 'Ej: 1234567',
            prefixIcon:
                const Icon(Icons.badge, color: Color(0xFF0085FF)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFF0085FF), width: 2),
            ),
          ),
          onSubmitted: (_) => _buscarCliente(),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          _buildErrorBox(_errorMessage!),
        ],
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _isLoading ? null : _buscarCliente,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0085FF),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text(
                  'Verificar CI',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
        ),
      ],
    );
  }

  Widget _buildPaso1Login() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green[200]!),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    _clienteEncontrado!.razonSocial[0].toUpperCase(),
                    style: TextStyle(
                      color: Colors.green[800],
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _clienteEncontrado!.razonSocial,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.green[800],
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'CI: ${_clienteEncontrado!.documento}',
                      style: TextStyle(
                          fontSize: 12, color: Colors.green[700]),
                    ),
                  ],
                ),
              ),
              Icon(Icons.check_circle,
                  color: Colors.green[600], size: 22),
            ],
          ),
        ),
        const SizedBox(height: 28),
        const Text(
          'Ahora iniciá sesión',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF111827),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Para verificar tu identidad',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        if (_errorMessage != null) ...[
          _buildErrorBox(_errorMessage!),
          const SizedBox(height: 16),
        ],
        OutlinedButton(
          onPressed: _isLoading ? null : _autenticarConGoogle,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            side: BorderSide(color: Colors.grey[300]!),
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildGoogleLogo(),
                    const SizedBox(width: 12),
                    const Text(
                      'Continuar con Google',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _isLoading ? null : _autenticarConFacebook,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            side: const BorderSide(color: Color(0xFF1877F2)),
            backgroundColor: const Color(0xFF1877F2),
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildFacebookLogo(),
                    const SizedBox(width: 12),
                    const Text(
                      'Continuar con Facebook',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _volverAlCI,
          icon: const Icon(Icons.arrow_back, size: 18),
          label: const Text('Cambiar CI'),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF0085FF),
          ),
        ),
      ],
    );
  }

  Widget _buildPaso2SelectorInmuebles() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildGoogleUserChip(),
        const SizedBox(height: 24),
        _buildClienteInfo(),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 20),
        Row(
          children: [
            const Icon(Icons.home_work_outlined,
                color: Color(0xFF0085FF), size: 20),
            const SizedBox(width: 8),
            Text(
              'Seleccioná tu inmueble',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF0085FF).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_inmuebles.length}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0085FF),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ..._inmuebles.asMap().entries.map((entry) {
          final index = entry.key;
          final inmueble = entry.value;
          final isSelected = _inmuebleSeleccionado?.cod_inmueble ==
              inmueble.cod_inmueble;

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              onTap: () => _seleccionarInmueble(inmueble),
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF0085FF).withOpacity(0.07)
                      : Colors.grey[50],
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF0085FF)
                        : Colors.grey[200]!,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF0085FF)
                            : Colors.grey[200],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: isSelected
                            ? const Icon(Icons.home,
                                color: Colors.white, size: 22)
                            : Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[600],
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Código: ${inmueble.cod_inmueble}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? const Color(0xFF0085FF)
                                  : const Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Icon(Icons.location_on_outlined,
                                  size: 13, color: Colors.grey[500]),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  inmueble.direccion,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600]),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      isSelected
                          ? Icons.check_circle
                          : Icons.arrow_forward_ios,
                      color: isSelected
                          ? const Color(0xFF0085FF)
                          : Colors.grey[400],
                      size: isSelected ? 22 : 16,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _cerrarSesion,
          icon: const Icon(Icons.logout, size: 18),
          label: const Text('Cerrar sesión'),
          style:
              TextButton.styleFrom(foregroundColor: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildGoogleUserChip() {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundImage: _fotoGoogle != null
                ? NetworkImage(_fotoGoogle!)
                : null,
            backgroundColor: Colors.green[100],
            child: _fotoGoogle == null
                ? Icon(Icons.person,
                    color: Colors.green[700], size: 20)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _nombreGoogle ?? 'Usuario',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.green[800],
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _emailGoogle ?? '',
                  style: TextStyle(
                      fontSize: 12, color: Colors.green[700]),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.verified, color: Colors.green[600], size: 20),
        ],
      ),
    );
  }

  Widget _buildClienteInfo() {
    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: const Color(0xFF0085FF).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              _clienteEncontrado!.razonSocial[0].toUpperCase(),
              style: const TextStyle(
                color: Color(0xFF0085FF),
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _clienteEncontrado!.razonSocial,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'CI: ${_clienteEncontrado!.documento}',
                style:
                    TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBox(String mensaje) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red[700], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              mensaje,
              style:
                  TextStyle(color: Colors.red[700], fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoogleLogo() {
    return SizedBox(
      width: 22,
      height: 22,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }

  Widget _buildFacebookLogo() {
    return Container(
      width: 22,
      height: 22,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: const Center(
        child: Text(
          'f',
          style: TextStyle(
            color: Color(0xFF1877F2),
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0085FF), Color(0xFF0066CC)],
        ),
      ),
      padding:
          const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 20,
            backgroundColor: Colors.white,
            child: Icon(Icons.water_drop,
                size: 22, color: Color(0xFF0085FF)),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'SERVICIO DE AGUA',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  'SANTA ROSA - C.F.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LoginPage()),
            ),
            icon: const Icon(Icons.admin_panel_settings,
                color: Colors.white, size: 24),
            tooltip: 'Acceso Administrativo',
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Text(
        '© 2026 Servicio de Agua Santa Rosa',
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    canvas.drawArc(rect, -0.5, 1.6, false,
        Paint()
          ..color = const Color(0xFFEA4335)
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * 0.18);
    canvas.drawArc(rect, 1.1, 1.35, false,
        Paint()
          ..color = const Color(0xFFFBBC05)
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * 0.18);
    canvas.drawArc(rect, 2.45, 0.9, false,
        Paint()
          ..color = const Color(0xFF34A853)
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * 0.18);
    canvas.drawArc(rect, 3.35, 1.1, false,
        Paint()
          ..color = const Color(0xFF4285F4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * 0.18);
    canvas.drawLine(
      Offset(center.dx, center.dy),
      Offset(center.dx + radius, center.dy),
      Paint()
        ..color = const Color(0xFF4285F4)
        ..strokeWidth = size.width * 0.18,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}