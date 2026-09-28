import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Shell modal compartido por los diálogos "Agregar/Editar X": header azul
/// (icono + título + cerrar), cuerpo scrolleable y footer Cancelar/Guardar.
/// Calcula ancho/alto en función de la pantalla real para no overflowear
/// en móvil, en vez del `Dialog(child: Container(width: fijo, ...))` que
/// cada pantalla repetía.
class CrudDialog extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget body;
  final VoidCallback onGuardar;
  final double preferredWidth;
  final double preferredMaxHeight;
  final String cancelLabel;
  final String saveLabel;

  const CrudDialog({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.onGuardar,
    this.preferredWidth = 700,
    this.preferredMaxHeight = 650,
    this.cancelLabel = 'Cancelar',
    this.saveLabel = 'Guardar',
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = math.min(preferredWidth, size.width - 32);
    final maxHeight = math.min(preferredMaxHeight, size.height - 64);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: width,
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          children: [
            _CrudDialogHeader(icon: icon, title: title),
            Expanded(child: body),
            _CrudDialogFooter(
              cancelLabel: cancelLabel,
              saveLabel: saveLabel,
              onGuardar: onGuardar,
            ),
          ],
        ),
      ),
    );
  }
}

class _CrudDialogHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _CrudDialogHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF0085FF),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(4),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

class _CrudDialogFooter extends StatelessWidget {
  final String cancelLabel;
  final String saveLabel;
  final VoidCallback onGuardar;

  const _CrudDialogFooter({
    required this.cancelLabel,
    required this.saveLabel,
    required this.onGuardar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(cancelLabel),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: onGuardar,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0085FF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(saveLabel),
          ),
        ],
      ),
    );
  }
}
