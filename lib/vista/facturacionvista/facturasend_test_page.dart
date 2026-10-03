import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:myapp/dao/clientecrudimpl.dart';
import 'package:myapp/modelo/cliente.dart';
import 'package:myapp/service/facturasend_test_service.dart';

/// Pantalla aislada de prueba (PoC) para validar el envío de un documento de
/// ejemplo a FacturaSend. No integrada al flujo real de facturación — no
/// importa nada de las otras vistas de facturación.
///
/// Gateada en `opciones_page.dart` detrás de
/// `const bool.fromEnvironment('FACTURASEND_POC')`.
class FacturaSendTestPage extends StatefulWidget {
  const FacturaSendTestPage({Key? key}) : super(key: key);

  @override
  State<FacturaSendTestPage> createState() => _FacturaSendTestPageState();
}

class _FacturaSendTestPageState extends State<FacturaSendTestPage> {
  static const Color _primario = Color(0xFF0085FF);

  final FacturaSendTestService _service = FacturaSendTestService();
  final ClienteCrudImpl _clienteCrud = ClienteCrudImpl();

  final TextEditingController _buscadorCtrl = TextEditingController();
  final TextEditingController _jsonCtrl = TextEditingController();

  List<Cliente> _resultadosBusqueda = [];
  Cliente? _clienteSeleccionado;
  bool _buscando = false;
  bool _incluirQr = true;
  bool _enviando = false;

  FacturaSendTestResultado? _resultado;

  @override
  void initState() {
    super.initState();
    _rellenarJsonConDocumento(
      _service.construirDocumentoDePrueba(),
    );
  }

  @override
  void dispose() {
    _buscadorCtrl.dispose();
    _jsonCtrl.dispose();
    super.dispose();
  }

  void _rellenarJsonConDocumento(Map<String, dynamic> documento) {
    final encoder = JsonEncoder.withIndent('  ');
    _jsonCtrl.text = encoder.convert(documento);
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  Future<void> _buscarClientes(String query) async {
    if (query.trim().length < 2) {
      setState(() => _resultadosBusqueda = []);
      return;
    }
    setState(() => _buscando = true);
    try {
      final resultados = await _clienteCrud.buscarClientes(query.trim());
      if (!mounted) return;
      setState(() {
        _resultadosBusqueda = resultados;
        _buscando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _buscando = false);
      _snack('Error al buscar clientes: $e', Colors.red);
    }
  }

  void _seleccionarCliente(Cliente cliente) {
    setState(() {
      _clienteSeleccionado = cliente;
      _resultadosBusqueda = [];
      _buscadorCtrl.text = cliente.nombreCompleto;
    });
    _rellenarJsonConDocumento(
      _service.construirDocumentoDePrueba(cliente: cliente),
    );
  }

  void _limpiarClienteSeleccionado() {
    setState(() {
      _clienteSeleccionado = null;
      _buscadorCtrl.clear();
      _resultadosBusqueda = [];
    });
    _rellenarJsonConDocumento(_service.construirDocumentoDePrueba());
  }

  Future<void> _enviar() async {
    Map<String, dynamic> documento;
    try {
      final decodificado = jsonDecode(_jsonCtrl.text);
      if (decodificado is! Map<String, dynamic>) {
        throw const FormatException('El JSON debe ser un objeto');
      }
      documento = decodificado;
    } catch (e) {
      _snack('JSON inválido: $e', Colors.red);
      return;
    }

    setState(() {
      _enviando = true;
      _resultado = null;
    });

    final resultado = await _service.enviar(documento, qr: _incluirQr);

    if (!mounted) return;
    setState(() {
      _enviando = false;
      _resultado = resultado;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prueba FacturaSend (PoC)'),
        backgroundColor: _primario,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _bannerAdvertencia(),
                const SizedBox(height: 20),
                _buscadorCliente(),
                const SizedBox(height: 20),
                _editorJson(),
                const SizedBox(height: 16),
                CheckboxListTile(
                  value: _incluirQr,
                  onChanged: (v) => setState(() => _incluirQr = v ?? true),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Incluir QR'),
                ),
                const SizedBox(height: 8),
                _botonEnviar(),
                const SizedBox(height: 24),
                if (_resultado != null) _cardResultado(_resultado!),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bannerAdvertencia() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Entorno de PRUEBA — solo borradores. Esta pantalla no está '
              'integrada al sistema de facturación real y solo debe usarse '
              'para validar la conexión con FacturaSend.',
              style: TextStyle(fontSize: 13, color: Color(0xFF7C4A03)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buscadorCliente() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cliente real (opcional)',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _buscadorCtrl,
            decoration: InputDecoration(
              hintText: 'Buscar por razón social, documento o celular...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _clienteSeleccionado != null
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: _limpiarClienteSeleccionado,
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            onChanged: _buscarClientes,
          ),
          if (_buscando)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LinearProgressIndicator(),
            ),
          if (_resultadosBusqueda.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8),
              constraints: const BoxConstraints(maxHeight: 220),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _resultadosBusqueda.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final cliente = _resultadosBusqueda[index];
                  return ListTile(
                    dense: true,
                    title: Text(cliente.nombreCompleto),
                    subtitle: Text(cliente.documento),
                    onTap: () => _seleccionarCliente(cliente),
                  );
                },
              ),
            ),
          if (_clienteSeleccionado != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Cliente seleccionado: ${_clienteSeleccionado!.nombreCompleto} '
                '(${_clienteSeleccionado!.documento})',
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _editorJson() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Documento a enviar (editable)',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _jsonCtrl,
            maxLines: 18,
            minLines: 10,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _botonEnviar() {
    return ElevatedButton.icon(
      onPressed: _enviando ? null : _enviar,
      style: ElevatedButton.styleFrom(
        backgroundColor: _primario,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        elevation: 0,
      ),
      icon: _enviando
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Icon(Icons.send_outlined, size: 18),
      label: Text(
        _enviando ? 'Enviando...' : 'Enviar borrador a FacturaSend',
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _cardResultado(FacturaSendTestResultado resultado) {
    final exito = resultado.ok;
    final color = exito ? Colors.green : Colors.red;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                exito ? Icons.check_circle_outline : Icons.error_outline,
                color: color,
              ),
              const SizedBox(width: 8),
              Text(
                exito ? 'Respuesta recibida' : 'Error',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (resultado.error != null) ...[
            Text(resultado.error!, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
          ],
          _filaDato('upstreamStatus', resultado.upstreamStatus?.toString()),
          _filaDato('draft', resultado.draft.toString()),
          _filaDato('cdc', resultado.cdc),
          _filaDato('loteId', resultado.loteId),
          if (resultado.errores.isNotEmpty)
            _filaDato('errores', resultado.errores.join(', ')),
          const SizedBox(height: 12),
          const Text(
            'Respuesta completa',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: SelectableText(
              const JsonEncoder.withIndent('  ')
                  .convert(resultado.facturasend ?? {}),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filaDato(String etiqueta, String? valor) {
    if (valor == null || valor.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 13, color: Colors.black87),
          children: [
            TextSpan(
              text: '$etiqueta: ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: valor),
          ],
        ),
      ),
    );
  }
}
