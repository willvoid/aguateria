import 'package:flutter/material.dart';
import 'package:myapp/vista/categoria_servicio_page.dart';
import 'package:myapp/vista/cliente_page.dart';
import 'package:myapp/vista/inmueblepage.dart';
import 'package:myapp/vista/tarifa_page.dart';

class DashboardWidget extends StatefulWidget {
  const DashboardWidget({Key? key}) : super(key: key);

  @override
  State<DashboardWidget> createState() => _DashboardWidgetState();
}

class _DashboardWidgetState extends State<DashboardWidget>
    with TickerProviderStateMixin {
  int selectedIndex = 0;
  int? selectedSubIndex;
  bool isSidebarVisible = true; // Controla la visibilidad del sidebar
  late AnimationController _animationController;
  late Animation<double> _sidebarAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _sidebarAnimation = Tween<double>(begin: 0.0, end: 240.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Iniciar con el sidebar visible
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleSidebar() {
    setState(() {
      isSidebarVisible = !isSidebarVisible;
      if (isSidebarVisible) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  Widget _getSelectedWidget() {
    switch (selectedIndex) {
      case 0:
        return const ClientesPage();
      case 1:
        //return const CategoriaServicioPage();
        // Sub-items de Deudas
        if (selectedSubIndex != null) {
          switch (selectedSubIndex) {
            case 0:
              return const InmueblesPage();
            case 1:
              return const CategoriaServicioPage();
            case 2:
              return const Center(child: Text('Medidores'));
            case 3:
              return const TarifaPage();
          }
        }
        
        return const InmueblesPage();
      case 2:
        return Container(
          padding: const EdgeInsets.all(24),
          child: const Center(
            child: Text(
              'Datos de Empresa',
              style: TextStyle(fontSize: 16, color: Color(0xFF6B7280)),
            ),
          ),
        );
      case 3:
      //return const NuevaFacturaPage();
      case 4:
        return Container(
          padding: const EdgeInsets.all(24),
          child: const Center(
            child: Text(
              'Contabilidad',
              style: TextStyle(fontSize: 16, color: Color(0xFF6B7280)),
            ),
          ),
        );
      case 5:
        return Container(
          padding: const EdgeInsets.all(24),
          child: const Center(
            child: Text(
              'Opciones',
              style: TextStyle(fontSize: 16, color: Color(0xFF6B7280)),
            ),
          ),
        );
      default:
        return Container(
          padding: const EdgeInsets.all(24),
          child: const Center(
            child: Text(
              'Selecciona una opción',
              style: TextStyle(fontSize: 16, color: Color(0xFF6B7280)),
            ),
          ),
        );
    }
  }

  String _getSelectedTitle() {
    if (selectedIndex >= 0 && selectedIndex < sidebarItems.length) {
      final item = sidebarItems[selectedIndex];
      if (selectedIndex == 1 &&
          selectedSubIndex != null &&
          item.subItems != null) {
        // Si estamos en Deudas y hay un subitem seleccionado
        return '${item.title} - ${item.subItems![selectedSubIndex!].title}';
      }
      return item.title;
    }
    return 'Dashboard';
  }

  IconData _getSelectedIcon() {
    if (selectedIndex >= 0 && selectedIndex < sidebarItems.length) {
      final item = sidebarItems[selectedIndex];
      if (selectedIndex == 1 &&
          selectedSubIndex != null &&
          item.subItems != null) {
        // Si estamos en Deudas y hay un subitem seleccionado
        return item.subItems![selectedSubIndex!].icon;
      }
      return item.icon;
    }
    return Icons.dashboard;
  }

  final List<SidebarItem> sidebarItems = [
    SidebarItem(
      icon: Icons.account_circle,
      title: 'Clientes',
      isSelected: true,
    ),
    SidebarItem(
      icon: Icons.home,
      title: 'Inmuebles',
      subItems: [
        SidebarSubItem(icon: Icons.home, title: 'Casas'),
        SidebarSubItem(icon: Icons.category, title: 'Categorías de Inmuebles'),
        SidebarSubItem(icon: Icons.rule_rounded, title: 'Medidores'),
        SidebarSubItem(icon: Icons.calculate, title: 'Tarifa de Servicio'),
      ],
    ),
    SidebarItem(
      icon: Icons.receipt_long,
      title: 'Deudas',
      isSelected: false,
      subItems: [
        SidebarSubItem(icon: Icons.home, title: 'Casas'),
        SidebarSubItem(icon: Icons.water_drop, title: 'Cuentas Consumo'),
        SidebarSubItem(
          icon: Icons.electrical_services,
          title: 'Cuentas Conexión',
        ),
      ],
    ),
    SidebarItem(
      icon: Icons.account_balance_outlined,
      title: 'Datos de Empresa',
    ),
    SidebarItem(icon: Icons.receipt, title: 'Facturación'),
    SidebarItem(icon: Icons.trending_up, title: 'Contabilidad'),
    SidebarItem(icon: Icons.settings, title: 'Opciones'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Row(
        children: [
          // Sidebar Animado
          AnimatedBuilder(
            animation: _sidebarAnimation,
            builder: (context, child) {
              return Container(
                width: _sidebarAnimation.value,
                child: _sidebarAnimation.value > 0
                    ? Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A3441),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(2, 0),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Header
                            Container(
                              height: 60,
                              padding: const EdgeInsets.all(16),
                              decoration: const BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: Color(0xFF3A4553),
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0085FF),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(
                                      Icons.water_drop,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  if (_sidebarAnimation.value > 180)
                                    const Expanded(
                                      child: Text(
                                        'SERVICIO DE AGUA SANTA ROSA - C.F.',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            // Sidebar Items
                            Expanded(
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                itemCount: _getTotalItemCount(),
                                itemBuilder: (context, index) {
                                  return _buildSidebarItem(index);
                                },
                              ),
                            ),
                          ],
                        ),
                      )
                    : null,
              );
            },
          ),
          // Main Content
          Expanded(
            child: Column(
              children: [
                // Top Bar
                Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.grey.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Botón para mostrar/ocultar sidebar
                      IconButton(
                        onPressed: _toggleSidebar,
                        icon: Icon(
                          isSidebarVisible ? Icons.menu_open : Icons.menu,
                          color: const Color(0xFF6B7280),
                          size: 20,
                        ),
                        tooltip: isSidebarVisible
                            ? 'Ocultar menú'
                            : 'Mostrar menú',
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        _getSelectedIcon(),
                        color: const Color(0xFF6B7280),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _getSelectedTitle(),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
                // Content Area
                Expanded(child: _getSelectedWidget()),
                // Status Bar
                Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: const BoxDecoration(color: Color(0xFF374151)),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Sistema Activo',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      const Spacer(),
                      Text(
                        'Versión 1.0.0',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _getTotalItemCount() {
    int count = 0;
    for (int i = 0; i < sidebarItems.length; i++) {
      count++; // Item principal
      if (sidebarItems[i].isExpanded && sidebarItems[i].subItems != null) {
        count += sidebarItems[i].subItems!.length; // Sub-items
      }
    }
    return count;
  }

  Widget _buildSidebarItem(int displayIndex) {
    int currentIndex = 0;

    for (int i = 0; i < sidebarItems.length; i++) {
      if (currentIndex == displayIndex) {
        // Es un item principal
        return _buildMainItem(i);
      }
      currentIndex++;

      // Si el item está expandido, construir los sub-items
      if (sidebarItems[i].isExpanded && sidebarItems[i].subItems != null) {
        for (int j = 0; j < sidebarItems[i].subItems!.length; j++) {
          if (currentIndex == displayIndex) {
            return _buildSubItem(i, j);
          }
          currentIndex++;
        }
      }
    }

    return Container(); // Fallback
  }

  Widget _buildMainItem(int index) {
    final item = sidebarItems[index];
    final isSelected = item.isSelected && selectedSubIndex == null;
    final hasSubItems = item.subItems != null && item.subItems!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () {
            setState(() {
              // Desmarcar todos los items
              for (var sidebarItem in sidebarItems) {
                sidebarItem.isSelected = false;
                sidebarItem.isExpanded = false;
              }
              // Marcar el item seleccionado
              sidebarItems[index].isSelected = true;
              selectedIndex = index;
              selectedSubIndex = null;

              // Si tiene sub-items, expandir
              if (hasSubItems) {
                sidebarItems[index].isExpanded = true;
              }
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF3A4553) : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(item.icon, color: Colors.white.withOpacity(0.9), size: 18),
                if (_sidebarAnimation.value > 120) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.title,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                        fontWeight: isSelected
                            ? FontWeight.w500
                            : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (hasSubItems)
                    Icon(
                      item.isExpanded
                          ? Icons.keyboard_arrow_down
                          : Icons.keyboard_arrow_right,
                      color: Colors.white.withOpacity(0.7),
                      size: 16,
                    ),
                  if (item.badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0085FF),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        item.badge!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubItem(int parentIndex, int subIndex) {
    final parentItem = sidebarItems[parentIndex];
    final subItem = parentItem.subItems![subIndex];
    final isSelected = parentItem.isSelected && selectedSubIndex == subIndex;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () {
            setState(() {
              // Desmarcar todos los items principales
              for (var sidebarItem in sidebarItems) {
                sidebarItem.isSelected = false;
                sidebarItem.isExpanded = false;
              }
              // Marcar el item padre y el sub-item
              sidebarItems[parentIndex].isSelected = true;
              sidebarItems[parentIndex].isExpanded = true;
              selectedIndex = parentIndex;
              selectedSubIndex = subIndex;
            });
          },
          child: Container(
            padding: EdgeInsets.only(
              left: _sidebarAnimation.value > 120 ? 42 : 12,
              right: 12,
              top: 8,
              bottom: 8,
            ),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF3A4553) : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(
                  subItem.icon,
                  color: Colors.white.withOpacity(0.8),
                  size: 16,
                ),
                if (_sidebarAnimation.value > 120) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      subItem.title,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.w500
                            : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SidebarItem {
  final IconData icon;
  final String title;
  final String? badge;
  final List<SidebarSubItem>? subItems;
  bool isSelected;
  bool isExpanded;

  SidebarItem({
    required this.icon,
    required this.title,
    this.badge,
    this.subItems,
    this.isSelected = false,
    this.isExpanded = false,
  });
}

class SidebarSubItem {
  final IconData icon;
  final String title;

  SidebarSubItem({required this.icon, required this.title});
}
