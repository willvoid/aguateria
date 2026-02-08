import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:myapp/dao/facturaciondao/modo_pagocrudimpl.dart';
import 'package:myapp/dao/facturaciondao/pagocrudimpl.dart';
import 'package:myapp/modelo/cliente.dart';
import 'package:myapp/modelo/facturacionmodelo/modo_pago.dart';
import 'package:myapp/modelo/facturacionmodelo/pago.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class SelectorMetodoPagoDialog extends StatefulWidget {
  final double totalAPagar;
  final int idUsuario;
  final Cliente cliente; // AÑADIDO
  final Map<String, dynamic> Function(ModoPago modoPago) payloadFactura;
  final Function(ModoPago modoPago, Pago? pagoCreado) onMetodoSeleccionado;

  const SelectorMetodoPagoDialog({
    Key? key,
    required this.totalAPagar,
    required this.idUsuario,
    required this.cliente, // AÑADIDO
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
        _modosPago = modos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _mostrarError('Error al cargar métodos de pago: $e');
    }
  }

  Future<void> _seleccionarMetodo(ModoPago modo) async {
  setState(() => _modoPagoSeleccionado = modo);

  // Si es Transferencia (id=5) o Giro (id=6), abrir diálogo de comprobante
  if (modo.id_modo_pago == 5 || modo.id_modo_pago == 6) {
    final pagoCreado = await showDialog<Pago>(
      context: context,
      barrierDismissible: false,
      builder: (context) => SubirComprobanteDialog(
        modoPago: modo,
        totalAPagar: widget.totalAPagar,
        idUsuario: widget.idUsuario,
        cliente: widget.cliente,
        payloadFactura: widget.payloadFactura(modo), // ✅ Llamar a la función aquí
      ),
    );

    if (pagoCreado != null && mounted) {
      widget.onMetodoSeleccionado(modo, pagoCreado);
      Navigator.pop(context);
    }
  } else {
    // Para otros métodos (Efectivo, Tarjeta, etc.), solo devolver el método
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
            // Header
            _buildHeader(),

            // Contenido
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

    // Iconos según el método
    IconData icono;
    Color color;

    switch (modo.id_modo_pago) {
      case 1: // Efectivo
        icono = Icons.money;
        color = Colors.green;
        break;
      case 2: // Tarjeta
        icono = Icons.credit_card;
        color = Colors.blue;
        break;
      case 3: // Cheque
        icono = Icons.description;
        color = Colors.orange;
        break;
      case 4: // Crédito
        icono = Icons.account_balance_wallet;
        color = Colors.purple;
        break;
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
                  if (modo.id_modo_pago == 5 || modo.id_modo_pago == 6) ...[
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
  final Cliente cliente; // AÑADIDO
  final Map<String, dynamic> payloadFactura;

  const SubirComprobanteDialog({
    Key? key,
    required this.modoPago,
    required this.totalAPagar,
    required this.idUsuario,
    required this.cliente, // AÑADIDO
    required this.payloadFactura,
  }) : super(key: key);

  @override
  State<SubirComprobanteDialog> createState() => _SubirComprobanteDialogState();
}

class _SubirComprobanteDialogState extends State<SubirComprobanteDialog> {
  final PagoCrudImpl _pagoService = PagoCrudImpl();
  final ImagePicker _picker = ImagePicker();

  File? _imagenSeleccionada;
  bool _isUploading = false;

  Future<void> _seleccionarImagen() async {
    try {
      final XFile? imagen = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (imagen != null) {
        setState(() {
          _imagenSeleccionada = File(imagen.path);
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
        setState(() {
          _imagenSeleccionada = File(imagen.path);
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
      // 1. Subir imagen a Supabase Storage
      final fileName =
          'comprobante_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = 'comprobantes/$fileName';

      final bytes = await _imagenSeleccionada!.readAsBytes();

      await supabase.storage
          .from('pagos') // Nombre del bucket
          .uploadBinary(
            filePath,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: false,
            ),
          );

      // 2. Obtener URL pública
      final String publicUrl = supabase.storage
          .from('pagos')
          .getPublicUrl(filePath);

      // 3. Crear el pago en la BD
      final nuevoPago = Pago(
        fechaPago: DateTime.now(),
        comprobanteUrl: publicUrl,
        monto: widget.totalAPagar,
        estado: 'PENDIENTE', // Estado inicial pendiente de aprobación
        payloadCreacion: widget.payloadFactura,
        usuario: null, // Se puede cargar el objeto Usuario si lo tienes
        motivoRechazo: null,
        fk_cliente: widget.cliente, // AÑADIDO
        fk_modo_pago: widget.modoPago, // AÑADIDO
      );

      final pagoCreado = await _pagoService.crearPago(nuevoPago);

      setState(() => _isUploading = false);

      if (pagoCreado != null && mounted) {
        // Mostrar éxito
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.green.shade600,
                  size: 32,
                ),
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
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
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
                  Navigator.pop(context); // Cerrar alerta
                  Navigator.pop(
                    context,
                    pagoCreado,
                  ); // Cerrar diálogo con el pago
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
    final color = widget.modoPago.id_modo_pago == 5
        ? Colors.teal
        : Colors.indigo;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 650),
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
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
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
                              fontSize: 14,
                              color: Colors.grey.shade700,
                            ),
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
                    const SizedBox(height: 24),

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
                          Icon(Icons.info_outline, color: Colors.blue.shade700),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Por favor, suba una foto o captura de pantalla del comprobante de pago. El pago quedará en estado PENDIENTE hasta su aprobación.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Previsualización de imagen
                    if (_imagenSeleccionada != null) ...[
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            _imagenSeleccionada!,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Botones para seleccionar imagen
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isUploading ? null : _seleccionarImagen,
                            icon: const Icon(Icons.photo_library),
                            label: const Text('Galería'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
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
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Botón de procesar
                    ElevatedButton.icon(
                      onPressed: _isUploading || _imagenSeleccionada == null
                          ? null
                          : _procesarPago,
                      icon: _isUploading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Icon(Icons.check),
                      label: Text(
                        _isUploading ? 'Procesando...' : 'Confirmar Pago',
                      ),
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
