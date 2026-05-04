import 'package:flutter/material.dart';
import 'package:myapp/modelo/facturacionmodelo/ciclo.dart';

class CicloAutocomplete extends StatelessWidget {
  final List<Ciclo> ciclos;
  final Ciclo? cicloInicial;
  final void Function(Ciclo) onSeleccionado;
  final String? Function(String?)? validator;
  final String label;
  final String hint;

  const CicloAutocomplete({
    Key? key,
    required this.ciclos,
    required this.onSeleccionado,
    this.cicloInicial,
    this.validator,
    this.label = 'Ciclo *',
    this.hint = 'Buscar por ciclo o descripción...',
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
        Autocomplete<Ciclo>(
          initialValue: cicloInicial != null
              ? TextEditingValue(
                  text: '${cicloInicial!.ciclo} - ${cicloInicial!.descripcion}',
                )
              : null,
          displayStringForOption: (Ciclo c) => '${c.ciclo} - ${c.descripcion}',
          optionsBuilder: (TextEditingValue textValue) {
            if (textValue.text.isEmpty) return ciclos;
            final term = textValue.text.toLowerCase();
            return ciclos.where((c) =>
                c.ciclo.toLowerCase().contains(term) ||
                c.descripcion.toLowerCase().contains(term));
          },
          onSelected: onSeleccionado,
          fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
            if (controller.text.isEmpty && cicloInicial != null) {
              controller.text =
                  '${cicloInicial!.ciclo} - ${cicloInicial!.descripcion}';
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
                suffixIcon: const Icon(Icons.calendar_today, size: 20),
              ),
              validator: validator ??
                  (value) => (value == null || value.isEmpty)
                      ? 'Debe seleccionar un ciclo'
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
                      final Ciclo c = options.elementAt(index);
                      final bool esActivo = c.estado == 'ACTIVO';
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
                              Row(
                                children: [
                                  Text(
                                    c.ciclo,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: esActivo
                                          ? Colors.green.shade100
                                          : Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      c.estado,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: esActivo
                                            ? Colors.green.shade700
                                            : Colors.grey.shade600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                c.descripcion,
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