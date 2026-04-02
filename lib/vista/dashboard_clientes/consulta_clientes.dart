import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:myapp/dao/clientecrudimpl.dart';
import 'package:myapp/dao/inmueblescrudimpl.dart';
import 'package:myapp/modelo/cliente.dart';
import 'package:myapp/modelo/inmuebles.dart';
import 'package:myapp/vista/dashboard_clientes/dashboard_clientes.dart';
import 'package:myapp/vista/loginpage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ClienteConsultaPage extends StatefulWidget {
  const ClienteConsultaPage({Key? key}) : super(key: key);

  @override
  State<ClienteConsultaPage> createState() => _ClienteConsultaPageState();
}

class _ClienteConsultaPageState extends State<ClienteConsultaPage> {
  final TextEditingController _documentoController = TextEditingController();
  final ClienteCrudImpl _clienteCrud = ClienteCrudImpl();
  final InmuebleCrudImpl _inmuebleCrud = InmuebleCrudImpl();

  // [NUEVO] Instancia de AppLinks para capturar el deep link de Google
  late final AppLinks _appLinks;

  bool _isLoading = false;
  bool _googleAutenticado = false;
  String? _emailGoogle;
  String? _nombreGoogle;
  String? _fotoGoogle;

  Cliente? _clienteEncontrado;
  List<Inmuebles> _inmuebles = [];
  Inmuebles? _inmuebleSeleccionado;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    // [NUEVO] Inicializa deep links para capturar el redirect de Google
    _initDeepLinks();

    // Escucha cambios de sesión (se dispara cuando getSessionFromUrl tiene éxito)
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session != null && mounted) {
        final user = session.user;
        setState(() {
          _googleAutenticado = true;
          _emailGoogle = user.email;
          _nombreGoogle = user.userMetadata?['full_name'] ?? user.email;
          _fotoGoogle = user.userMetadata?['avatar_url'];
          _isLoading = false;
          _errorMessage = null;
        });
      }
    });
  }

  // [NUEVO] Captura el deep link com.example.myapp://login-callback
  // que Google devuelve tras autenticar, y se lo pasa a Supabase
  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();

    // Caso 1: app ya estaba abierta cuando llegó el redirect
    _appLinks.uriLinkStream.listen((uri) {
      Supabase.instance.client.auth.getSessionFromUrl(uri);
    });

    // Caso 2: el redirect abrió la app desde cero
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

  Future<void> _autenticarConGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        // [NUEVO] redirectTo apunta al scheme real de la app
        redirectTo: 'com.example.myapp://login-callback',
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
      // La sesión llega por onAuthStateChange vía _initDeepLinks
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al autenticar con Google. Intente nuevamente.';
        _isLoading = false;
      });
      print('Error Google OAuth: $e');
    }
  }

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
      final cliente = await _clienteCrud.buscarClientePorDocumento(documento);

      if (cliente == null) {
        // CI no encontrado → no se guarda nada en clientes
        setState(() {
          _errorMessage =
              'Tu CI no está registrado en el sistema. '
              'Contactá a la oficina para registrarte.';
          _isLoading = false;
        });
        return;
      }

      // CI encontrado → recién ahí se guarda el email de Google en clientes
      if (_emailGoogle != null) {
        await _clienteCrud.actualizarEmailCliente(
          cliente.idCliente!,
          _emailGoogle!,
        );
      }

      final inmuebles = await _inmuebleCrud.leerInmueblesPorCliente(
        cliente.idCliente!,
      );

      setState(() {
        _clienteEncontrado = cliente;
        _inmuebles = inmuebles;
        _isLoading = false;
        if (inmuebles.isEmpty) _errorMessage = 'No tiene inmuebles registrados';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al buscar. Intente nuevamente.';
        _isLoading = false;
      });
      print('Error en búsqueda: $e');
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
    setState(() {
      _googleAutenticado = false;
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

  void _limpiarBusqueda() {
    setState(() {
      _documentoController.clear();
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
                          child: _googleAutenticado
                              ? _buildPaso2CiForm()
                              : _buildPaso1GoogleLogin(),
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

  Widget _buildPaso1GoogleLogin() {
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
          'Iniciá sesión con tu cuenta de Google para continuar',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        Center(
          child: Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: const Color(0xFF0085FF).withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.account_circle_outlined,
              size: 52,
              color: Color(0xFF0085FF),
            ),
          ),
        ),
        const SizedBox(height: 40),
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
        const SizedBox(height: 20),
        Text(
          'Tu sesión es segura y solo vos podés ver tu información.',
          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildPaso2CiForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildGoogleUserChip(),
        const SizedBox(height: 28),
        const Text(
          'Ingresá tu número de CI',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF111827),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Para acceder a tu cuenta de agua',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        TextField(
          controller: _documentoController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: 'Número de CI',
            hintText: 'Ej: 1234567',
            prefixIcon: const Icon(Icons.badge, color: Color(0xFF0085FF)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF0085FF), width: 2),
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
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text(
                  'Consultar',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
        ),
        if (_clienteEncontrado != null) ...[
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),
          _buildClienteInfo(),
          if (_inmuebles.isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildSelectorInmuebles(),
          ],
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: _limpiarBusqueda,
            icon: const Icon(Icons.refresh),
            label: const Text('Nueva consulta'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF0085FF),
            ),
          ),
        ],
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _cerrarSesion,
          icon: const Icon(Icons.logout, size: 18),
          label: const Text('Cerrar sesión de Google'),
          style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildGoogleUserChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundImage:
                _fotoGoogle != null ? NetworkImage(_fotoGoogle!) : null,
            backgroundColor: Colors.green[100],
            child: _fotoGoogle == null
                ? Icon(Icons.person, color: Colors.green[700], size: 20)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _nombreGoogle ?? 'Usuario Google',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.green[800],
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _emailGoogle ?? '',
                  style: TextStyle(fontSize: 12, color: Colors.green[700]),
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
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              if (_emailGoogle != null) ...[
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      Icons.email_outlined,
                      size: 12,
                      color: Colors.grey[500],
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _emailGoogle!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSelectorInmuebles() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Seleccioná tu inmueble',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<Inmuebles>(
          value: _inmuebleSeleccionado,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.home, color: Color(0xFF0085FF)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF0085FF), width: 2),
            ),
          ),
          hint: const Text('Seleccioná un inmueble'),
          items: _inmuebles.map((inmueble) {
            return DropdownMenuItem<Inmuebles>(
              value: inmueble,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Código: ${inmueble.cod_inmueble}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    inmueble.direccion,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: _seleccionarInmueble,
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
              style: TextStyle(color: Colors.red[700], fontSize: 14),
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

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0085FF), Color(0xFF0066CC)],
        ),
      ),
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
            child: const Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.white,
                  child: Icon(
                    Icons.water_drop,
                    size: 40,
                    color: Color(0xFF0085FF),
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'SERVICIO DE AGUA',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'SANTA ROSA - C.F.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
              ),
              icon: const Icon(
                Icons.admin_panel_settings,
                color: Colors.white,
                size: 28,
              ),
              tooltip: 'Acceso Administrativo',
            ),
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

    canvas.drawArc(
      rect, -0.5, 1.6, false,
      Paint()
        ..color = const Color(0xFFEA4335)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.18,
    );
    canvas.drawArc(
      rect, 1.1, 1.35, false,
      Paint()
        ..color = const Color(0xFFFBBC05)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.18,
    );
    canvas.drawArc(
      rect, 2.45, 0.9, false,
      Paint()
        ..color = const Color(0xFF34A853)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.18,
    );
    canvas.drawArc(
      rect, 3.35, 1.1, false,
      Paint()
        ..color = const Color(0xFF4285F4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.18,
    );
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