import 'package:flutter/material.dart';
import 'package:myapp/modelo/cliente.dart';

class ClienteAutocomplete extends StatelessWidget {
  final List<Cliente> clientes;
  final Cliente? clienteInicial;
  final void Function(Cliente) onSeleccionado;
  final String? Function(String?)? validator;
  final String label;
  final String hint;

  const ClienteAutocomplete({
    Key? key,
    required this.clientes,
    required this.onSeleccionado,
    this.clienteInicial,
    this.validator,
    this.label = 'Cliente *',
    this.hint = 'Buscar por nombre o documento...',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
        Autocomplete<Cliente>(
          initialValue: clienteInicial != null
              ? TextEditingValue(
                  text: '${clienteInicial!.razonSocial} - ${clienteInicial!.documento}',
                )
              : null,
          displayStringForOption: (Cliente c) =>
              '${c.razonSocial} - ${c.documento}',
          optionsBuilder: (TextEditingValue textValue) {
            if (textValue.text.isEmpty) return clientes;
            final term = textValue.text.toLowerCase();
            return clientes.where((c) =>
                c.razonSocial.toLowerCase().contains(term) ||
                c.documento.toLowerCase().contains(term) ||
                (c.nombreFantasia?.toLowerCase().contains(term) ?? false));
          },
          onSelected: onSeleccionado,
          fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
            if (controller.text.isEmpty && clienteInicial != null) {
              controller.text =
                  '${clienteInicial!.razonSocial} - ${clienteInicial!.documento}';
            }
            return TextFormField(
              controller: controller,
              focusNode: focusNode,
              decoration: InputDecoration(
                hintText: hint,
                filled: true,
                fillColor: Theme.of(context).cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: Theme.of(context).dividerColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: Theme.of(context).dividerColor),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                suffixIcon: const Icon(Icons.search, size: 20),
              ),
              validator: validator ??
                  (value) => (value == null || value.isEmpty)
                      ? 'Debe seleccionar un cliente'
                      : null,
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4.0,
                borderRadius: BorderRadius.circular(6),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 200,
                    maxWidth: 550,
                  ),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final Cliente c = options.elementAt(index);
                      return InkWell(
                        onTap: () => onSelected(c),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.razonSocial,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Doc: ${c.documento} • Tel: ${c.celular}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}