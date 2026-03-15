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

  bool _isLoading = false;
  Cliente? _clienteEncontrado;
  List<Inmuebles> _inmuebles = [];
  Inmuebles? _inmuebleSeleccionado;
  String? _errorMessage;

  @override
  void dispose() {
    _documentoController.dispose();
    super.dispose();
  }

  Future<void> _buscarCliente() async {
    final documento = _documentoController.text.trim();

    if (documento.isEmpty) {
      setState(() {
        _errorMessage = 'Por favor, ingrese su número de documento';
      });
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
      // 1. RECONSTRUIMOS EL CORREO FICTICIO Y LA CONTRASEÑA
      final String correoFicticio = '$documento@santarosa.local';
      
      // 2. INICIAMOS SESIÓN EN SUPABASE AUTH
      await Supabase.instance.client.auth.signInWithPassword(
        email: correoFicticio,
        password: documento,
      );

      // 3. SI EL LOGIN FUE EXITOSO, BUSCAMOS SUS DATOS EN TU TABLA (Tu código original)
      final cliente = await _clienteCrud.buscarClientePorDocumento(documento);

      if (cliente == null) {
        setState(() {
          _errorMessage = 'No se encontró información adicional del cliente';
          _isLoading = false;
        });
        return;
      }

      // 4. BUSCAMOS SUS INMUEBLES
      final inmuebles = await _inmuebleCrud.leerInmueblesPorCliente(
        cliente.idCliente!,
      );

      setState(() {
        _clienteEncontrado = cliente;
        _inmuebles = inmuebles;
        _isLoading = false;
      });

      if (inmuebles.isEmpty) {
        setState(() {
          _errorMessage = 'No tiene inmuebles registrados';
        });
      }

    } catch (e) {
      // Si el login falla (ej: documento no existe en Auth) o falla la base de datos
      setState(() {
        _errorMessage = 'Documento incorrecto o no registrado.';
        _isLoading = false;
      });
      print('Error en el login/búsqueda: $e'); // Para que veas en consola el error real
    }
  }

  void _seleccionarInmueble(Inmuebles? inmueble) {
    setState(() {
      _inmuebleSeleccionado = inmueble;
    });

    if (inmueble != null) {
      // Navegar al dashboard del cliente con el inmueble seleccionado
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
            // Header
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [const Color(0xFF0085FF), const Color(0xFF0066CC)],
                ),
              ),
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 32,
                      horizontal: 24,
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.water_drop,
                            size: 40,
                            color: Color(0xFF0085FF),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'SERVICIO DE AGUA',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
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
                  // Botón de acceso administrativo
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginPage()),
                        );
                      },
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
            ),

            // Contenido principal
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Tarjeta de búsqueda
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
                          child: Column(
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
                                'Ingresa tu número de documento para continuar',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 32),

                              // Campo de documento
                              TextField(
                                controller: _documentoController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                decoration: InputDecoration(
                                  labelText: 'Número de Documento',
                                  hintText: 'Ej: 1234567',
                                  prefixIcon: const Icon(
                                    Icons.badge,
                                    color: Color(0xFF0085FF),
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.grey[300]!,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF0085FF),
                                      width: 2,
                                    ),
                                  ),
                                ),
                                onSubmitted: (_) => _buscarCliente(),
                              ),

                              if (_errorMessage != null) ...[
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.red[50],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.red[200]!),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.error_outline,
                                        color: Colors.red[700],
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          _errorMessage!,
                                          style: TextStyle(
                                            color: Colors.red[700],
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              const SizedBox(height: 24),

                              // Botón de buscar
                              ElevatedButton(
                                onPressed: _isLoading ? null : _buscarCliente,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0085FF),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
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
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      )
                                    : const Text(
                                        'Consultar',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),

                              // Mostrar cliente encontrado
                              if (_clienteEncontrado != null) ...[
                                const SizedBox(height: 24),
                                const Divider(),
                                const SizedBox(height: 24),

                                Row(
                                  children: [
                                    Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF0085FF,
                                        ).withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          _clienteEncontrado!.razonSocial[0]
                                              .toUpperCase(),
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
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
                                            'Doc: ${_clienteEncontrado!.documento}',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                // Selector de inmuebles
                                if (_inmuebles.isNotEmpty) ...[
                                  const SizedBox(height: 24),
                                  const Text(
                                    'Selecciona tu inmueble',
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
                                      prefixIcon: const Icon(
                                        Icons.home,
                                        color: Color(0xFF0085FF),
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Colors.grey[300]!,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Color(0xFF0085FF),
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                    hint: const Text('Selecciona un inmueble'),
                                    items: _inmuebles.map((inmueble) {
                                      return DropdownMenuItem<Inmuebles>(
                                        value: inmueble,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              'Código: ${inmueble.cod_inmueble}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            Text(
                                              inmueble.direccion,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: _seleccionarInmueble,
                                  ),
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
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              child: Text(
                '© 2024 Servicio de Agua Santa Rosa',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
