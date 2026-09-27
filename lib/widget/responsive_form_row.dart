import 'package:flutter/material.dart';

/// Reemplaza `Row([Expanded(a), SizedBox(width:16), Expanded(b), ...])`:
/// por debajo de [breakpoint] (evaluado con el ancho real disponible en
/// este punto del árbol, vía [LayoutBuilder]) apila los [children] en
/// columna; por encima, los distribuye en fila con [Expanded]. Soporta N
/// children y, opcionalmente, [flexes] desiguales para secciones grandes
/// en vez de campos sueltos.
class ResponsiveFormRow extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final double breakpoint;
  final List<int>? flexes;

  const ResponsiveFormRow({
    super.key,
    required this.children,
    this.spacing = 16,
    this.breakpoint = 480,
    this.flexes,
  }) : assert(flexes == null || flexes.length == children.length);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < breakpoint) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) SizedBox(height: spacing),
                children[i],
              ],
            ],
          );
        }
        return Row(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) SizedBox(width: spacing),
              Expanded(flex: flexes?[i] ?? 1, child: children[i]),
            ],
          ],
        );
      },
    );
  }
}
