import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/material.dart';
import 'package:myapp/service/thermal_printer_service.dart';

/// Tarjeta de configuración de la impresora térmica Bluetooth (solo Android).
class ImpresoraTermicaCard extends StatefulWidget {
  const ImpresoraTermicaCard({Key? key}) : super(key: key);

  @override
  State<ImpresoraTermicaCard> createState() => _ImpresoraTermicaCardState();
}

class _ImpresoraTermicaCardState extends State<ImpresoraTermicaCard> {
  ImpresoraGuardada? _impresora;
  bool _cargando = true;
  bool _ocupado = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final guardada = await ThermalPrinterService.impresoraGuardada();
    if (!mounted) return;
    setState(() {
      _impresora = guardada;
      _cargando = false;
    });
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  Future<void> _elegir() async {
    setState(() => _ocupado = true);
    try {
      final dispositivos = await ThermalPrinterService.listarEmparejadas();
      if (!mounted) return;
      if (dispositivos.isEmpty) {
        _snack(
          'No hay dispositivos emparejados. Empareje la impresora en los ajustes Bluetooth.',
          Colors.orange,
        );
        return;
      }
      final elegido = await showDialog<BluetoothDevice>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('Seleccione la impresora'),
          children: dispositivos
              .map((d) => SimpleDialogOption(
                    onPressed: () => Navigator.pop(ctx, d),
                    child: Text('${d.name ?? 'Sin nombre'}  (${d.address})'),
                  ))
              .toList(),
        ),
      );
      if (elegido == null || elegido.address == null) return;
      final nueva = ImpresoraGuardada(
        nombre: elegido.name ?? elegido.address!,
        direccion: elegido.address!,
        columnas: _impresora?.columnas ?? 32,
      );
      await ThermalPrinterService.guardarImpresora(nueva);
      if (mounted) setState(() => _impresora = nueva);
    } catch (e) {
      if (mounted) _snack('Error: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _cambiarColumnas(int columnas) async {
    final actual = _impresora;
    if (actual == null) return;
    final nueva = ImpresoraGuardada(
      nombre: actual.nombre,
      direccion: actual.direccion,
      columnas: columnas,
    );
    await ThermalPrinterService.guardarImpresora(nueva);
    if (mounted) setState(() => _impresora = nueva);
  }

  Future<void> _probar() async {
    final actual = _impresora;
    if (actual == null) return;
    setState(() => _ocupado = true);
    try {
      await ThermalPrinterService.imprimirPrueba(actual);
    } catch (e) {
      if (mounted) _snack('No se pudo imprimir: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _olvidar() async {
    await ThermalPrinterService.olvidarImpresora();
    if (mounted) setState(() => _impresora = null);
  }

  @override
  Widget build(BuildContext context) {
    if (!ThermalPrinterService.disponible) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(20),
      child: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Row(
                  children: [
                    Icon(Icons.print_outlined, size: 16, color: Color(0xFF6B7280)),
                    SizedBox(width: 8),
                    Text(
                      'Impresora Térmica Bluetooth',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF374151),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _impresora == null
                      ? 'Sin impresora configurada: los tickets se imprimen como PDF.'
                      : '${_impresora!.nombre} (${_impresora!.direccion})',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                ),
                if (_impresora != null) ...[
                  const SizedBox(height: 12),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 32, label: Text('Papel 58 mm')),
                      ButtonSegment(value: 48, label: Text('Papel 80 mm')),
                    ],
                    selected: {_impresora!.columnas},
                    onSelectionChanged: (s) => _cambiarColumnas(s.first),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _ocupado ? null : _elegir,
                      icon: const Icon(Icons.bluetooth_searching, size: 18),
                      label: Text(_impresora == null ? 'Elegir impresora' : 'Cambiar'),
                    ),
                    if (_impresora != null) ...[
                      OutlinedButton.icon(
                        onPressed: _ocupado ? null : _probar,
                        icon: const Icon(Icons.receipt_long_outlined, size: 18),
                        label: const Text('Imprimir prueba'),
                      ),
                      TextButton(
                        onPressed: _ocupado ? null : _olvidar,
                        child: const Text('Quitar'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
    );
  }
}
