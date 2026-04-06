import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:myapp/dao/empresadao/datos_transferenciacrudimpl.dart';
import 'package:myapp/dao/facturaciondao/modo_pagocrudimpl.dart';
import 'package:myapp/dao/facturaciondao/pagocrudimpl.dart';
import 'package:myapp/modelo/cliente.dart';
import 'package:myapp/modelo/empresa/datos_transferencia.dart';
import 'package:myapp/modelo/facturacionmodelo/modo_pago.dart';
import 'package:myapp/modelo/facturacionmodelo/pago.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class SelectorMetodoPagoDialog extends StatefulWidget {
  final double totalAPagar;
  final int idUsuario;
  final Cliente cliente;
  final Map<String, dynamic> Function(ModoPago modoPago) payloadFactura;
  final Function(ModoPago modoPago, Pago? pagoCreado) onMetodoSeleccionado;

  const SelectorMetodoPagoDialog({
    Key? key,
    required this.totalAPagar,
    required this.idUsuario,
    required this.cliente,
    required this.payloadFactura,
    required this.onMetodoSeleccionado,
  }) : super(key: key);

  @override
  State<SelectorMetodoPagoDialog> createState() =>
      _SelectorMetodoPagoDialogState();
}

class _SelectorMetodoPagoDialogState extends State<SelectorMetodoPagoDialog> {
  final ModoPagoCrudImpl _modoPagoService = ModoPagoCrudImpl();

  List<ModoPago> _modosPago = [];
  ModoPago? _modoPagoSeleccionado;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarModosPago();
  }

  Future<void> _cargarModosPago() async {
    setState(() => _isLoading = true);

    try {
      final modos = await _modoPagoService.leerModosPago();
      setState(() {
        // Solo muestra Transferencia (id=5) y Giro (id=6)
        _modosPago = modos
            .where((m) => m.id_modo_pago == 5 || m.id_modo_pago == 6)
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _mostrarError('Error al cargar métodos de pago: $e');
    }
  }

  Future<void> _seleccionarMetodo(ModoPago modo) async {
    setState(() => _modoPagoSeleccionado = modo);

    // Transferencia (id=5) o Giro (id=6): abrir diálogo de comprobante
    if (modo.id_modo_pago == 5 || modo.id_modo_pago == 6) {
      final pagoCreado = await showDialog<Pago>(
        context: context,
        barrierDismissible: false,
        builder: (context) => SubirComprobanteDialog(
          modoPago: modo,
          totalAPagar: widget.totalAPagar,
          idUsuario: widget.idUsuario,
          cliente: widget.cliente,
          payloadFactura: widget.payloadFactura(modo),
        ),
      );

      if (pagoCreado != null && mounted) {
        widget.onMetodoSeleccionado(modo, pagoCreado);
        Navigator.pop(context);
      }
    } else {
      widget.onMetodoSeleccionado(modo, null);
      Navigator.pop(context);
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
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _modosPago.isEmpty
                      ? _buildEmptyState()
                      : _buildModosPagoList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade600, Colors.blue.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.payment, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Método de Pago',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Total: ${widget.totalAPagar.toStringAsFixed(0)} Gs.',
                  style: const TextStyle(fontSize: 14, color: Colors.white70),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.payment_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No hay métodos de pago disponibles',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModosPagoList() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _modosPago.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final modo = _modosPago[index];
        return _buildModoPagoCard(modo);
      },
    );
  }

  Widget _buildModoPagoCard(ModoPago modo) {
    final isSelected = _modoPagoSeleccionado?.id_modo_pago == modo.id_modo_pago;

    IconData icono;
    Color color;

    switch (modo.id_modo_pago) {
      case 5: // Transferencia
        icono = Icons.compare_arrows;
        color = Colors.teal;
        break;
      case 6: // Giro
        icono = Icons.sync_alt;
        color = Colors.indigo;
        break;
      default:
        icono = Icons.payment;
        color = Colors.grey;
    }

    return InkWell(
      onTap: () => _seleccionarMetodo(modo),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icono, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    modo.descripcion,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? color : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.upload_file,
                        size: 14,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Requiere comprobante',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: color, size: 28)
            else
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey.shade400,
                size: 16,
              ),
          ],
        ),
      ),
    );
  }
}

// ========================================================================
// DIÁLOGO PARA SUBIR COMPROBANTE (Transferencia/Giro)
// ========================================================================

class SubirComprobanteDialog extends StatefulWidget {
  final ModoPago modoPago;
  final double totalAPagar;
  final int idUsuario;
  final Cliente cliente;
  final Map<String, dynamic> payloadFactura;

  const SubirComprobanteDialog({
    Key? key,
    required this.modoPago,
    required this.totalAPagar,
    required this.idUsuario,
    required this.cliente,
    required this.payloadFactura,
  }) : super(key: key);

  @override
  State<SubirComprobanteDialog> createState() => _SubirComprobanteDialogState();
}

class _SubirComprobanteDialogState extends State<SubirComprobanteDialog> {
  final PagoCrudImpl _pagoService = PagoCrudImpl();
  final DatosTransferenciaCrudImpl _transferenciaCrud =
      DatosTransferenciaCrudImpl();
  final ImagePicker _picker = ImagePicker();

  XFile? _imagenSeleccionada;
  Uint8List? _imagenBytes;
  bool _isUploading = false;

  List<DatosTransferencia> _cuentas = [];
  bool _loadingCuentas = true;

  @override
  void initState() {
    super.initState();
    _cargarCuentas();
  }

  Future<void> _cargarCuentas() async {
    try {
      final resultado =
          await _transferenciaCrud.leerDatosTransferenciaPorSucursal(1);
      setState(() {
        _cuentas = resultado;
        _loadingCuentas = false;
      });
    } catch (e) {
      setState(() => _loadingCuentas = false);
    }
  }

  Widget _buildDatosCuentas(Color color) {
    if (_loadingCuentas) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_cuentas.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.grey.shade500, size: 18),
            const SizedBox(width: 8),
            const Text(
              'No hay cuentas registradas para esta sucursal',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.account_balance, color: color, size: 18),
            const SizedBox(width: 8),
            Text(
              widget.modoPago.id_modo_pago == 5
                  ? 'Datos para la transferencia'
                  : 'Datos para el giro',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ..._cuentas.map((cuenta) => _buildTarjetaCuenta(cuenta, color)),
      ],
    );
  }

  Widget _buildTarjetaCuenta(DatosTransferencia cuenta, Color color) {
    final esTransferencia = widget.modoPago.id_modo_pago == 5;
    final esGiro = widget.modoPago.id_modo_pago == 6;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (esTransferencia) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  cuenta.banco,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    cuenta.banco,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            if (cuenta.alias != null && cuenta.alias!.isNotEmpty) ...[
              _buildFilaDato(Icons.label_outline, 'Alias', cuenta.alias!, copiable: true),
              const SizedBox(height: 6),
            ],
            _buildFilaDato(
                Icons.person_outline, 'Titular', cuenta.titular_cuenta),
            const SizedBox(height: 6),
            _buildFilaDato(Icons.badge_outlined, 'CI', cuenta.ci),
            const SizedBox(height: 6),
            _buildFilaDato(Icons.numbers, 'Nro. Cuenta', cuenta.num_cuenta, copiable: true),
          ],
          if (esGiro &&
              cuenta.nro_giro != null &&
              cuenta.nro_giro!.isNotEmpty) ...[
            _buildFilaDato(Icons.sync_alt, 'Número Giro', cuenta.nro_giro!),
          ],
          if (esGiro && (cuenta.nro_giro == null || cuenta.nro_giro!.isEmpty))
            Row(
              children: [
                Icon(Icons.warning_amber_outlined,
                    size: 15, color: Colors.orange.shade400),
                const SizedBox(width: 6),
                Text(
                  'Sin número receptor registrado',
                  style:
                      TextStyle(fontSize: 12, color: Colors.orange.shade600),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildFilaDato(IconData icono, String label, String valor,
      {bool copiable = false}) {
    return Row(
      children: [
        Icon(icono, size: 15, color: Colors.grey.shade500),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            valor,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (copiable) ...[
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: valor));
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.check_circle,
                            color: Colors.white, size: 16),
                        const SizedBox(width: 8),
                        Text('$label copiado'),
                      ],
                    ),
                    backgroundColor: Colors.green.shade600,
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.copy, size: 12, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    'Copiar',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _seleccionarImagen() async {
    try {
      final XFile? imagen = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (imagen != null) {
        final bytes = await imagen.readAsBytes();
        setState(() {
          _imagenSeleccionada = imagen;
          _imagenBytes = bytes;
        });
      }
    } catch (e) {
      _mostrarError('Error al seleccionar imagen: $e');
    }
  }

  Future<void> _tomarFoto() async {
    try {
      final XFile? imagen = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (imagen != null) {
        final bytes = await imagen.readAsBytes();
        setState(() {
          _imagenSeleccionada = imagen;
          _imagenBytes = bytes;
        });
      }
    } catch (e) {
      _mostrarError('Error al tomar foto: $e');
    }
  }

  Future<void> _procesarPago() async {
    if (_imagenSeleccionada == null) {
      _mostrarError('Debe seleccionar un comprobante');
      return;
    }
    setState(() => _isUploading = true);
    try {
      final fileName =
          'comprobante_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = 'comprobantes/$fileName';
      final bytes = _imagenBytes!;

      await supabase.storage.from('pagos').uploadBinary(
            filePath,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: false,
            ),
          );

      final String publicUrl =
          supabase.storage.from('pagos').getPublicUrl(filePath);

      final nuevoPago = Pago(
        fechaPago: DateTime.now(),
        comprobanteUrl: publicUrl,
        monto: widget.totalAPagar,
        estado: 'PENDIENTE',
        payloadCreacion: widget.payloadFactura,
        usuario: null,
        motivoRechazo: null,
        fk_cliente: widget.cliente,
        fk_modo_pago: widget.modoPago,
      );

      final pagoCreado = await _pagoService.crearPago(nuevoPago);

      print('🔍 payload detalles: ${widget.payloadFactura['detalles']}');
      print('🔍 fk_inmueble: ${widget.payloadFactura['fk_inmueble']}');

      if (pagoCreado != null) {
        final detalles = widget.payloadFactura['detalles'] as List<dynamic>;
        final fkInmueble = widget.payloadFactura['fk_inmueble'] as int;
        try {
          await supabase.rpc(
            'crear_detalle_pago_deuda',
            params: {
              'p_id_pago': pagoCreado.idPago,
              'p_fk_inmueble': fkInmueble,
              'p_detalles': detalles,
            },
          );
        } catch (e) {
          print('Error al crear el detalle de pago: $e');
        }
      }

      setState(() => _isUploading = false);

      if (pagoCreado != null && mounted) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.check_circle,
                    color: Colors.green.shade600, size: 32),
                const SizedBox(width: 12),
                const Text('Comprobante Enviado'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Su comprobante ha sido enviado exitosamente y está pendiente de aprobación.',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ID de Pago: #${pagoCreado.idPago}',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Monto: ${widget.totalAPagar.toStringAsFixed(0)} Gs.',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Estado: ${pagoCreado.estado}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context, pagoCreado);
                },
                child: const Text('Entendido'),
              ),
            ],
          ),
        );
      } else {
        throw Exception('No se pudo crear el pago');
      }
    } catch (e) {
      setState(() => _isUploading = false);
      _mostrarError('Error al procesar pago: $e');
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
    final color =
        widget.modoPago.id_modo_pago == 5 ? Colors.teal : Colors.indigo;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.modoPago.id_modo_pago == 5
                          ? Icons.compare_arrows
                          : Icons.sync_alt,
                      color: color,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Subir Comprobante',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                        Text(
                          widget.modoPago.descripcion,
                          style: TextStyle(
                              fontSize: 14, color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    color: Colors.grey.shade600,
                  ),
                ],
              ),
            ),

            // Contenido
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Monto
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [color.shade50, color.shade100],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: color.shade200),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Monto a Pagar',
                            style: TextStyle(
                                fontSize: 14, color: Colors.grey.shade700),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${widget.totalAPagar.toStringAsFixed(0)} Gs.',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: color.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Datos de transferencia/giro
                    _buildDatosCuentas(color),
                    const SizedBox(height: 20),

                    // Instrucciones
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline,
                              color: Colors.blue.shade700),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Por favor, suba una foto o captura de pantalla del comprobante de pago. El pago quedará en estado PENDIENTE hasta su aprobación.',
                              style: TextStyle(
                                  fontSize: 13, color: Colors.grey.shade700),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Previsualización
                    if (_imagenSeleccionada != null) ...[
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child:
                              Image.memory(_imagenBytes!, fit: BoxFit.cover),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Botones galería/cámara
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed:
                                _isUploading ? null : _seleccionarImagen,
                            icon: const Icon(Icons.photo_library),
                            label: const Text('Galería'),
                            style: OutlinedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isUploading ? null : _tomarFoto,
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Cámara'),
                            style: OutlinedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Botón confirmar
                    ElevatedButton.icon(
                      onPressed:
                          _isUploading || _imagenSeleccionada == null
                              ? null
                              : _procesarPago,
                      icon: _isUploading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white),
                              ),
                            )
                          : const Icon(Icons.check),
                      label: Text(
                          _isUploading ? 'Procesando...' : 'Confirmar Pago'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        disabledBackgroundColor: Colors.grey.shade300,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}