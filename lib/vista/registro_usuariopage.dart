import 'package:flutter/material.dart';
import 'package:myapp/dao/tipodoc_crudimpl.dart';
import 'package:myapp/dao/usuariodao/cargocrudimpl.dart';
import 'package:myapp/dao/usuariodao/usuariocrudimpl.dart';
import 'package:myapp/modelo/%20tipo_documento.dart';
import 'package:myapp/modelo/usuario/usuario.dart';
import 'package:myapp/modelo/usuario/cargo.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegistroUsuarioPage extends StatefulWidget {
  const RegistroUsuarioPage({Key? key}) : super(key: key);

  @override
  State<RegistroUsuarioPage> createState() => _RegistroUsuarioPageState();
}

class _RegistroUsuarioPageState extends State<RegistroUsuarioPage> {
  final _formKey = GlobalKey<FormState>();
  final UsuarioCrudImpl _usuarioCrud = UsuarioCrudImpl();
  final CargoCrudImpl _cargoCrud = CargoCrudImpl();
  final TipoDocCrudimpl _tipoDocCrud = TipoDocCrudimpl();

  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _documentoController = TextEditingController();
  final TextEditingController _correoController = TextEditingController();
  final TextEditingController _usuarioController = TextEditingController();
  final TextEditingController _claveController = TextEditingController();
  final TextEditingController _confirmarClaveController = TextEditingController();
  final TextEditingController _telefonoController = TextEditingController();

  List<Cargo> cargos = [];
  List<TipoDocumento> tiposDocumento = [];
  Cargo? _cargoSeleccionado;
  TipoDocumento? _tipoDocumentoSeleccionado;

  bool _isLoading = false;
  bool _isDatosLoading = true;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isDatosLoading = true);

    try {
      final resultados = await Future.wait([
        _cargoCrud.leerCargos(),
        _tipoDocCrud.leerTipoDoc(),
      ]);

      setState(() {
        cargos = resultados[0] as List<Cargo>;
        tiposDocumento = resultados[1] as List<TipoDocumento>;
        _cargoSeleccionado = cargos.isNotEmpty ? cargos.first : null;
        _tipoDocumentoSeleccionado = tiposDocumento.isNotEmpty ? tiposDocumento.first : null;
        _isDatosLoading = false;
      });
    } catch (e) {
      setState(() => _isDatosLoading = false);
      _mostrarError('Error al cargar datos: $e');
    }
  }

  Future<void> _registrarUsuario() async {
  if (!_formKey.currentState!.validate()) return;

  if (_cargoSeleccionado == null || _tipoDocumentoSeleccionado == null) {
    _mostrarError('Por favor seleccione cargo y tipo de documento');
    return;
  }

  if (_correoController.text.trim().isEmpty) {
    _mostrarError('El correo electrónico es obligatorio para el registro');
    return;
  }

  setState(() => _isLoading = true);

  try {
    // 1. Verificar duplicados en tu base de datos personalizada
    final usernameExiste = await _usuarioCrud.verificarUsernameExistente(
      _usuarioController.text.trim(),
    );
    if (usernameExiste) throw Exception('El nombre de usuario ya está en uso');

    final documentoExiste = await _usuarioCrud.verificarDocumentoExistente(
      _documentoController.text.trim(),
    );
    if (documentoExiste) throw Exception('El documento ya está registrado');

    final correoExiste = await _usuarioCrud.verificarCorreoExistente(
      _correoController.text.trim(),
    );
    if (correoExiste) throw Exception('El correo ya está registrado');

    // 2. Registrar al usuario en auth.users (Supabase)
    final AuthResponse res = await Supabase.instance.client.auth.signUp(
      email: _correoController.text.trim(),
      password: _claveController.text,
    );

    if (res.user == null) {
      throw Exception('No se pudo crear el usuario en Autenticación');
    }

    // 3. Crear el usuario en tu tabla personalizada
    final nuevoUsuario = Usuario(
      // NOTA: Sería ideal guardar res.user!.id en tu modelo Usuario para enlazar ambas tablas
      documento: _documentoController.text.trim(),
      nombre: _nombreController.text.trim(),
      correo: _correoController.text.trim(),
      usuario: _usuarioController.text.trim(),
      clave: _claveController.text,
      fk_cargo: _cargoSeleccionado!,
      fk_tipo_doc: _tipoDocumentoSeleccionado!,
      telefono: _telefonoController.text.trim().isEmpty
          ? null
          : _telefonoController.text.trim(),
    );

    final usuarioCreado = await _usuarioCrud.crearUsuario(nuevoUsuario);

    setState(() => _isLoading = false);

    if (usuarioCreado != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Usuario registrado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } else {
      // Opcional: Si falla la creación en tu tabla, deberías borrar el usuario
      // de Auth para evitar inconsistencias
      throw Exception(
        'Usuario creado en Auth, pero falló en la base de datos local',
      );
    }
  } on AuthException catch (e) {
    setState(() => _isLoading = false);
    _mostrarError('Error de Autenticación: ${e.message}');
  } catch (e) {
    setState(() => _isLoading = false);
    _mostrarError(e.toString().replaceAll('Exception: ', ''));
  }
}

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 600,
            margin: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).dividerColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _isDatosLoading
                ? const Padding(
                    padding: EdgeInsets.all(100),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Header
                        Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: Color(0xFF0085FF),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(12),
                              topRight: Radius.circular(12),
                            ),
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                icon: Icon(Icons.arrow_back, color: Theme.of(context).cardColor),
                                onPressed: () => Navigator.pop(context),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Crear Nueva Cuenta',
                                    style: TextStyle(
                                      color: Theme.of(context).cardColor,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Complete los datos para registrarse',
                                    style: TextStyle(
                                      color: Theme.of(context).cardColor.withOpacity(0.7),
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Form
                        Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Información Personal
                              _buildSectionTitle('Información Personal'),
                              const SizedBox(height: 16),

                              _buildTextField(
                                controller: _nombreController,
                                label: 'Nombre Completo *',
                                hint: 'Ingrese su nombre completo',
                                icon: Icons.person_outline,
                                validator: (value) =>
                                    value?.isEmpty ?? true ? 'Campo requerido' : null,
                              ),
                              const SizedBox(height: 16),

                              Row(
                                children: [
                                  Expanded(
                                    child: _buildDropdown<TipoDocumento>(
                                      label: 'Tipo Documento *',
                                      value: _tipoDocumentoSeleccionado,
                                      items: tiposDocumento,
                                      onChanged: (value) =>
                                          setState(() => _tipoDocumentoSeleccionado = value),
                                      itemLabel: (item) => item.descripcion_tipodoc,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildTextField(
                                      controller: _documentoController,
                                      label: 'Documento *',
                                      hint: 'Ingrese su documento',
                                      icon: Icons.badge_outlined,
                                      validator: (value) =>
                                          value?.isEmpty ?? true ? 'Campo requerido' : null,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              Row(
                                children: [
                                  Expanded(
                                    child: _buildTextField(
                                      controller: _correoController,
                                      label: 'Correo Electrónico',
                                      hint: 'ejemplo@correo.com',
                                      icon: Icons.email_outlined,
                                      validator: (value) {
                                        if (value != null && value.isNotEmpty) {
                                          if (!value.contains('@') || !value.contains('.')) {
                                            return 'Email inválido';
                                          }
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildTextField(
                                      controller: _telefonoController,
                                      label: 'Teléfono',
                                      hint: 'Ingrese su teléfono',
                                      icon: Icons.phone_outlined,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              _buildDropdown<Cargo>(
                                label: 'Cargo *',
                                value: _cargoSeleccionado,
                                items: cargos,
                                onChanged: (value) => setState(() => _cargoSeleccionado = value),
                                itemLabel: (item) => item.nombre,
                              ),
                              const SizedBox(height: 24),

                              // Credenciales de Acceso
                              _buildSectionTitle('Credenciales de Acceso'),
                              const SizedBox(height: 16),

                              _buildTextField(
                                controller: _usuarioController,
                                label: 'Nombre de Usuario *',
                                hint: 'Ingrese su usuario',
                                icon: Icons.account_circle_outlined,
                                validator: (value) {
                                  if (value?.isEmpty ?? true) return 'Campo requerido';
                                  if (value!.length < 4) {
                                    return 'Mínimo 4 caracteres';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              _buildTextField(
                                controller: _claveController,
                                label: 'Contraseña *',
                                hint: 'Ingrese su contraseña',
                                icon: Icons.lock_outline,
                                obscureText: _obscurePassword,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    setState(() => _obscurePassword = !_obscurePassword);
                                  },
                                ),
                                validator: (value) {
                                  if (value?.isEmpty ?? true) return 'Campo requerido';
                                  if (value!.length < 6) {
                                    return 'Mínimo 6 caracteres';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              _buildTextField(
                                controller: _confirmarClaveController,
                                label: 'Confirmar Contraseña *',
                                hint: 'Confirme su contraseña',
                                icon: Icons.lock_outline,
                                obscureText: _obscureConfirmPassword,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureConfirmPassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    setState(() =>
                                        _obscureConfirmPassword = !_obscureConfirmPassword);
                                  },
                                ),
                                validator: (value) {
                                  if (value?.isEmpty ?? true) return 'Campo requerido';
                                  if (value != _claveController.text) {
                                    return 'Las contraseñas no coinciden';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 32),

                              // Botón Registrar
                              ElevatedButton(
                                onPressed: _isLoading ? null : _registrarUsuario,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).primaryColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
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
                                        'Crear Cuenta',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                              const SizedBox(height: 16),

                              // Ya tengo cuenta
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '¿Ya tienes cuenta? ',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text(
                                      'Iniciar Sesión',
                                      style: TextStyle(
                                        color: Color(0xFF0085FF),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Color(0xFF374151),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF374151),
          ),
        ),
        SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          obscureText: obscureText,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 20),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: Theme.of(context).cardColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Theme.of(context).dividerColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Theme.of(context).dividerColor),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T? value,
    required List<T> items,
    required Function(T?) onChanged,
    required String Function(T) itemLabel,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF374151),
          ),
        ),
        SizedBox(height: 8),
        DropdownButtonFormField<T>(
          value: value,
          items: items
              .map((item) => DropdownMenuItem<T>(
                    value: item,
                    child: Text(itemLabel(item)),
                  ))
              .toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            filled: true,
            fillColor: Theme.of(context).cardColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Theme.of(context).dividerColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Theme.of(context).dividerColor),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _documentoController.dispose();
    _correoController.dispose();
    _usuarioController.dispose();
    _claveController.dispose();
    _confirmarClaveController.dispose();
    _telefonoController.dispose();
    super.dispose();
  }
}