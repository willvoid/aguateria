import 'package:flutter/material.dart';
import 'package:myapp/dao/empresadao/cajacrudimpl.dart';
import 'package:myapp/dao/facturaciondao/apertura_cierre_cajacrudimpl.dart';
import 'package:myapp/modelo/empresa/caja.dart';
import 'package:myapp/modelo/facturacionmodelo/apertura_cierre_caja.dart';
import 'package:myapp/modelo/usuario/authprovider.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class AperturaCierreCajaPage extends StatefulWidget {
  const AperturaCierreCajaPage({Key? key}) : super(key: key);

  @override
  State<AperturaCierreCajaPage> createState() => _AperturaCierreCajaPageState();
}

class _AperturaCierreCajaPageState extends State<AperturaCierreCajaPage> {
  final AperturaCierreCajaCrudImpl _aperturaCrud = AperturaCierreCajaCrudImpl();
  final CajaCrudImpl _cajaCrud = CajaCrudImpl();
  final _formKey = GlobalKey<FormState>();

  List<Caja> _cajas = [];
  List<AperturaCierreCaja> _aperturas = [];
  AperturaCierreCaja? _cajaAbierta;
  
  Caja? _cajaSeleccionada;
  final TextEditingController _montoInicialController = TextEditingController();
  final TextEditingController _montoFinalController = TextEditingController();
  
  bool _isLoading = false;
  bool _modoApertura = true; // true = apertura, false = cierre

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    
    try {
      final cajas = await _cajaCrud.leerCajas();
      final aperturas = await _aperturaCrud.leerAperturasCaja();
      
      setState(() {
        _cajas = cajas;
        _aperturas = aperturas;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _mostrarError('Error al cargar datos: $e');
    }
  }

  Future<void> _verificarCajaAbierta() async {
    if (_cajaSeleccionada == null) return;

    setState(() => _isLoading = true);
    
    try {
      final cajaAbierta = await _aperturaCrud.obtenerCajaAbierta(_cajaSeleccionada!.id_caja!);
      
      setState(() {
        _cajaAbierta = cajaAbierta;
        _modoApertura = cajaAbierta == null;
        _isLoading = false;
      });

      if (cajaAbierta != null) {
        _montoInicialController.text = cajaAbierta.monto_inicial.toStringAsFixed(0);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _mostrarError('Error al verificar caja: $e');
    }
  }

  Future<void> _abrirCaja() async {
    if (!_formKey.currentState!.validate()) return;
    if (_cajaSeleccionada == null) {
      _mostrarError('Debe seleccionar una caja');
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final usuario = authProvider.usuarioActual;

    if (usuario == null) {
      _mostrarError('Usuario no autenticado');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final apertura = AperturaCierreCaja(
        apertura: DateTime.now(),
        monto_inicial: double.parse(_montoInicialController.text),
        fk_usuario: usuario,
        fk_caja: _cajaSeleccionada!, monto_final: 0,
      );

      final result = await _aperturaCrud.crearAperturaCaja(apertura);

      setState(() => _isLoading = false);

      if (result != null) {
        _mostrarExito('Caja abierta exitosamente');
        _limpiarFormulario();
        _cargarDatos();
      } else {
        _mostrarError('Error al abrir caja');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _mostrarError('Error al abrir caja: $e');
    }
  }

  Future<void> _cerrarCaja() async {
    if (!_formKey.currentState!.validate()) return;
    if (_cajaAbierta == null) {
      _mostrarError('No hay caja abierta para cerrar');
      return;
    }

    final confirmar = await _mostrarConfirmacion(
      '¿Está seguro de cerrar la caja?',
      'Esta acción no se puede deshacer',
    );

    if (!confirmar) return;

    setState(() => _isLoading = true);

    try {
      final montoFinal = double.parse(_montoFinalController.text);
      final resultado = await _aperturaCrud.cerrarCaja(
        _cajaAbierta!.id_turno!,
        montoFinal,
        DateTime.now(),
      );

      setState(() => _isLoading = false);

      if (resultado) {
        _mostrarExito('Caja cerrada exitosamente');
        _limpiarFormulario();
        _cargarDatos();
      } else {
        _mostrarError('Error al cerrar caja');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _mostrarError('Error al cerrar caja: $e');
    }
  }

  void _limpiarFormulario() {
    _montoInicialController.clear();
    _montoFinalController.clear();
    setState(() {
      _cajaSeleccionada = null;
      _cajaAbierta = null;
      _modoApertura = true;
    });
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

  void _mostrarExito(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<bool> _mostrarConfirmacion(String titulo, String mensaje) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(titulo),
        content: Text(mensaje),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Apertura y Cierre de Caja'),
        backgroundColor: const Color(0xFF0085FF),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Usuario actual
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(Icons.person, color: Color(0xFF0085FF)),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Usuario:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                Text(
                                  authProvider.usuarioNombre,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Formulario
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                _modoApertura ? 'Apertura de Caja' : 'Cierre de Caja',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Seleccionar Caja
                              DropdownButtonFormField<Caja>(
                                value: _cajaSeleccionada,
                                decoration: const InputDecoration(
                                  labelText: 'Caja *',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.point_of_sale),
                                ),
                                items: _cajas.map((caja) {
                                  return DropdownMenuItem(
                                    value: caja,
                                    child: Text(
                                      'Caja ${caja.nro_caja} - ${caja.descripcion_caja}',
                                    ),
                                  );
                                }).toList(),
                                onChanged: (caja) {
                                  setState(() => _cajaSeleccionada = caja);
                                  _verificarCajaAbierta();
                                },
                                validator: (value) =>
                                    value == null ? 'Seleccione una caja' : null,
                              ),
                              const SizedBox(height: 20),

                              // Monto Inicial (solo en apertura)
                              if (_modoApertura) ...[
                                TextFormField(
                                  controller: _montoInicialController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Monto Inicial *',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.attach_money),
                                    suffixText: 'Gs.',
                                  ),
                                  validator: (value) {
                                    if (value?.isEmpty ?? true) {
                                      return 'Campo requerido';
                                    }
                                    if (double.tryParse(value!) == null) {
                                      return 'Ingrese un monto válido';
                                    }
                                    return null;
                                  },
                                ),
                              ],

                              // Info de caja abierta y monto final (solo en cierre)
                              if (!_modoApertura && _cajaAbierta != null) ...[
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.blue.shade200),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Información de Apertura',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue.shade700,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(_cajaAbierta!.apertura)}',
                                      ),
                                      Text(
                                        'Monto Inicial: ${_cajaAbierta!.monto_inicial.toStringAsFixed(0)} Gs.',
                                      ),
                                      Text(
                                        'Usuario: ${_cajaAbierta!.fk_usuario.nombre}',
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),
                                TextFormField(
                                  controller: _montoFinalController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Monto Final *',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.money),
                                    suffixText: 'Gs.',
                                  ),
                                  validator: (value) {
                                    if (value?.isEmpty ?? true) {
                                      return 'Campo requerido';
                                    }
                                    if (double.tryParse(value!) == null) {
                                      return 'Ingrese un monto válido';
                                    }
                                    return null;
                                  },
                                ),
                              ],

                              const SizedBox(height: 24),

                              // Botón
                              ElevatedButton(
                                onPressed: _modoApertura ? _abrirCaja : _cerrarCaja,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _modoApertura
                                      ? const Color(0xFF0085FF)
                                      : Colors.red,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  _modoApertura ? 'Abrir Caja' : 'Cerrar Caja',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Lista de aperturas recientes
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Aperturas Recientes',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (_aperturas.isEmpty)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(32),
                                  child: Text('No hay aperturas registradas'),
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _aperturas.length > 5 ? 5 : _aperturas.length,
                                separatorBuilder: (_, __) => const Divider(),
                                itemBuilder: (context, index) {
                                  final apertura = _aperturas[index];
                                  final estaCerrada = apertura.cierre != null;
                                  
                                  return ListTile(
                                    leading: Icon(
                                      estaCerrada
                                          ? Icons.lock
                                          : Icons.lock_open,
                                      color: estaCerrada
                                          ? Colors.red
                                          : Colors.green,
                                    ),
                                    title: Text(
                                      'Caja ${apertura.fk_caja.nro_caja} - ${apertura.fk_caja.descripcion_caja}',
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Usuario: ${apertura.fk_usuario.nombre}'),
                                        Text(
                                          'Apertura: ${DateFormat('dd/MM/yyyy HH:mm').format(apertura.apertura)}',
                                        ),
                                        if (estaCerrada)
                                          Text(
                                            'Cierre: ${DateFormat('dd/MM/yyyy HH:mm').format(apertura.cierre!)}',
                                          ),
                                      ],
                                    ),
                                    trailing: Chip(
                                      label: Text(
                                        estaCerrada ? 'Cerrada' : 'Abierta',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.white,
                                        ),
                                      ),
                                      backgroundColor: estaCerrada
                                          ? Colors.red
                                          : Colors.green,
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    _montoInicialController.dispose();
    _montoFinalController.dispose();
    super.dispose();
  }
}