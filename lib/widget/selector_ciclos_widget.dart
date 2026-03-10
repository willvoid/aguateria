import 'package:flutter/material.dart';
import 'package:myapp/modelo/facturacionmodelo/ciclo.dart';

class SelectorCiclosDialog extends StatefulWidget {
  final List<Ciclo> ciclosDisponibles;
  final List<Ciclo> ciclosSeleccionados;
  final double montoPorCiclo;
  final Function(List<Ciclo>) onCiclosSeleccionados;

  const SelectorCiclosDialog({
    Key? key,
    required this.ciclosDisponibles,
    required this.ciclosSeleccionados,
    required this.montoPorCiclo,
    required this.onCiclosSeleccionados,
  }) : super(key: key);

  @override
  State<SelectorCiclosDialog> createState() => _SelectorCiclosDialogState();
}

class _SelectorCiclosDialogState extends State<SelectorCiclosDialog> {
  /// IDs de los ciclos actualmente seleccionados (comparación segura por id).
  late Set<int> _idsSeleccionados;

  int? _anioSeleccionado;
  List<int> _aniosDisponibles = [];

  @override
  void initState() {
    super.initState();
    // Inicializar con los ids de los ciclos pre-seleccionados
    _idsSeleccionados = widget.ciclosSeleccionados
        .where((c) => c.id != null)
        .map((c) => c.id!)
        .toSet();
    _cargarAniosDisponibles();
  }

  void _cargarAniosDisponibles() {
    final anios = widget.ciclosDisponibles
        .map((ciclo) => ciclo.anio)
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));

    setState(() {
      _aniosDisponibles = anios;
      if (anios.isNotEmpty) {
        final anioActual = DateTime.now().year;
        _anioSeleccionado =
            anios.contains(anioActual) ? anioActual : anios.first;
      }
    });
  }

  List<Ciclo> _getCiclosFiltrados() {
    if (_anioSeleccionado == null) return widget.ciclosDisponibles;
    return widget.ciclosDisponibles
        .where((ciclo) => ciclo.anio == _anioSeleccionado)
        .toList();
  }

  /// Devuelve los objetos Ciclo que corresponden a los ids seleccionados.
  List<Ciclo> get _ciclosSeleccionadosActuales {
    return widget.ciclosDisponibles
        .where((c) => c.id != null && _idsSeleccionados.contains(c.id))
        .toList();
  }

  void _toggleCiclo(Ciclo ciclo) {
    if (ciclo.id == null) return;
    setState(() {
      if (_idsSeleccionados.contains(ciclo.id)) {
        _idsSeleccionados.remove(ciclo.id);
      } else {
        _idsSeleccionados.add(ciclo.id!);
      }
    });
  }

  void _seleccionarTodos() {
    setState(() {
      for (final ciclo in _getCiclosFiltrados()) {
        if (ciclo.id != null) _idsSeleccionados.add(ciclo.id!);
      }
    });
  }

  void _deseleccionarTodos() {
    setState(() {
      final idsFiltrados =
          _getCiclosFiltrados().map((c) => c.id).whereType<int>().toSet();
      _idsSeleccionados.removeAll(idsFiltrados);
    });
  }

  void _confirmarSeleccion() {
    widget.onCiclosSeleccionados(_ciclosSeleccionadosActuales);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final ciclosFiltrados = _getCiclosFiltrados();
    final totalSeleccionados = _idsSeleccionados.length;
    final totalPagar = totalSeleccionados * widget.montoPorCiclo;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(totalSeleccionados, totalPagar),
            _buildFiltroAnio(),
            Expanded(
              child: ciclosFiltrados.isEmpty
                  ? _buildSinCiclos()
                  : ListView(
                      padding: const EdgeInsets.all(20),
                      children: ciclosFiltrados.map((ciclo) {
                        final isSelected = ciclo.id != null &&
                            _idsSeleccionados.contains(ciclo.id);
                        return _CicloItem(
                          ciclo: ciclo,
                          isSelected: isSelected,
                          montoPorCiclo: widget.montoPorCiclo,
                          onToggle: () => _toggleCiclo(ciclo),
                        );
                      }).toList(),
                    ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(int totalSeleccionados, double totalPagar) {
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
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.calendar_month,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Seleccionar Ciclos',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Elige los ciclos que deseas pagar',
                      style: TextStyle(fontSize: 13, color: Colors.white70),
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
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ciclos seleccionados',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade600),
                    ),
                    Text(
                      '$totalSeleccionados',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
                Container(
                    height: 40, width: 1, color: Colors.grey.shade300),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Total a pagar',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade600),
                    ),
                    Text(
                      '${totalPagar.toStringAsFixed(0)} Gs.',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltroAnio() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.filter_list,
                  size: 20, color: Colors.grey.shade700),
              const SizedBox(width: 8),
              Text(
                'Filtrar por año:',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _aniosDisponibles.map((anio) {
                      final isSelected = _anioSeleccionado == anio;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(anio.toString()),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              _anioSeleccionado = selected ? anio : null;
                            });
                          },
                          selectedColor: Colors.blue,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _seleccionarTodos,
                  icon: const Icon(Icons.check_box, size: 18),
                  label: const Text('Seleccionar todos'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    side: BorderSide(color: Colors.blue.shade300),
                    foregroundColor: Colors.blue.shade700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _deseleccionarTodos,
                  icon: const Icon(Icons.check_box_outline_blank, size: 18),
                  label: const Text('Deseleccionar todos'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    side: BorderSide(color: Colors.grey.shade300),
                    foregroundColor: Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSinCiclos() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No hay ciclos disponibles',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            _anioSeleccionado != null
                ? 'para el año $_anioSeleccionado'
                : 'en este momento',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: const Text('Cancelar'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: _idsSeleccionados.isNotEmpty
                  ? _confirmarSeleccion
                  : null,
              icon: const Icon(Icons.check_circle),
              label: Text('Confirmar (${_idsSeleccionados.length})'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0085FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                disabledBackgroundColor: Colors.grey.shade300,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CicloItem extends StatelessWidget {
  final Ciclo ciclo;
  final bool isSelected;
  final double montoPorCiclo;
  final VoidCallback onToggle;

  const _CicloItem({
    Key? key,
    required this.ciclo,
    required this.isSelected,
    required this.montoPorCiclo,
    required this.onToggle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isVencido = ciclo.vencimiento?.isBefore(DateTime.now()) ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: isSelected ? Colors.blue.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        elevation: isSelected ? 2 : 0,
        child: InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected ? Colors.blue : Colors.grey.shade300,
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Checkbox(
                  value: isSelected,
                  onChanged: (_) => onToggle(),
                  activeColor: Colors.blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              ciclo.descripcion,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          if (isVencido)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'VENCIDO',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red.shade700,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.water_drop,
                              size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            'Ciclo: ${ciclo.ciclo}',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.calendar_today,
                              size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            'Año: ${ciclo.anio}',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                      if (ciclo.vencimiento != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.event,
                              size: 14,
                              color: isVencido
                                  ? Colors.red.shade700
                                  : Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Vence: ${ciclo.vencimiento.toString().split(' ')[0]}',
                              style: TextStyle(
                                fontSize: 11,
                                color: isVencido
                                    ? Colors.red.shade700
                                    : Colors.grey.shade600,
                                fontWeight: isVencido
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${montoPorCiclo.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? Colors.blue
                            : Colors.grey.shade800,
                      ),
                    ),
                    Text(
                      'Gs.',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}