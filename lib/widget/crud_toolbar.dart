import 'package:flutter/material.dart';
import 'package:myapp/widget/responsive.dart';

/// Toolbar responsive de las pantallas CRUD: buscador + filtros opcionales +
/// botón de acción + refrescar. Por debajo de [breakpoint] apila el
/// buscador y cada filtro a ancho completo y agrupa botón + refrescar en
/// una fila final, en vez de comprimir el buscador en un `Row` fijo.
class CrudToolbar extends StatelessWidget {
  final Widget search;
  final List<Widget> filters;
  final Widget action;
  final VoidCallback onRefresh;
  final double breakpoint;

  const CrudToolbar({
    super.key,
    required this.search,
    this.filters = const [],
    required this.action,
    required this.onRefresh,
    this.breakpoint = kMobileBreakpoint,
  });

  @override
  Widget build(BuildContext context) {
    final refreshButton = IconButton(
      onPressed: onRefresh,
      icon: const Icon(Icons.refresh),
      tooltip: 'Recargar',
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (isMobile(constraints.maxWidth)) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              search,
              for (final filter in filters) ...[
                const SizedBox(height: 8),
                filter,
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: action),
                  const SizedBox(width: 8),
                  refreshButton,
                ],
              ),
            ],
          );
        }
        return Row(
          children: [
            Expanded(flex: 2, child: search),
            for (final filter in filters) ...[
              const SizedBox(width: 8),
              Expanded(flex: 2, child: filter),
            ],
            const SizedBox(width: 16),
            Flexible(child: action),
            const SizedBox(width: 8),
            refreshButton,
          ],
        );
      },
    );
  }
}
