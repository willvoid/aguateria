import 'package:flutter/material.dart';
import 'package:myapp/modelo/usuario/authprovider.dart';
import 'package:myapp/reportes/data/screens/pantalla_reporte.dart';
import 'package:myapp/vista/categoria_servicio_page.dart';
import 'package:myapp/vista/cliente_page.dart';
import 'package:myapp/vista/dashboard_principal/dashboard_cliente_inmueble.dart';
import 'package:myapp/vista/dashboard_principal/dashboard_resumen.dart';
import 'package:myapp/vista/empresavista/cajapage.dart';
import 'package:myapp/vista/empresavista/dato_empresapage.dart';
import 'package:myapp/vista/empresavista/establecimientopage.dart';
import 'package:myapp/vista/facturacionvista/facturapage.dart';
import 'package:myapp/vista/empresavista/timbradopage.dart';
import 'package:myapp/vista/facturacionvista/apertura_cierre_cajapage.dart';
import 'package:myapp/vista/facturacionvista/ciclo_page.dart';
import 'package:myapp/vista/facturacionvista/concepto_page.dart';
import 'package:myapp/vista/facturacionvista/pagos_page.dart';
import 'package:myapp/vista/inmueblepage.dart';
import 'package:myapp/vista/loginpage.dart';
import 'package:myapp/vista/medidor_page.dart';
import 'package:myapp/vista/tarifa_page.dart';
import 'package:provider/provider.dart';

class DashboardWidget extends StatefulWidget {
  const DashboardWidget({Key? key}) : super(key: key);

  @override
  State<DashboardWidget> createState() => _DashboardWidgetState();
}

class _DashboardWidgetState extends State<DashboardWidget>
    with TickerProviderStateMixin {
  int selectedIndex = 0;
  int? selectedSubIndex;
  bool isSidebarVisible = true;
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
      case 0: // Dashboard
        return const DashboardClientesInmueblesPage();
      case 1: // Clientes
        return const ClientesPage();
      case 2: // Inmuebles
        if (selectedSubIndex != null) {
          switch (selectedSubIndex) {
            case 0:
              return const InmueblesPage();
            case 1:
              return const CategoriaServicioPage();
            case 2:
              return const MedidoresPage();
            case 3:
              return const TarifaPage();
          }
        }
        return const InmueblesPage();
      case 3: // Deudas / Pagos
        return const PagosPage();
      case 4: // Datos Empresa
        if (selectedSubIndex != null) {
          switch (selectedSubIndex) {
            case 0:
              return const EstablecimientosPage();
            case 1:
              return const CajaPage();
            case 2:
              return const TimbradoPage();
            case 3:
              return const AperturaCierreCajaPage();
          }
        }
        return const DatoEmpresaPage();
      case 5: // Facturación
        if (selectedSubIndex != null) {
          switch (selectedSubIndex) {
            case 0:
              return const ConceptosPage();
            case 1:
              return const CiclosPage();
          }
        }
        return const CrearFacturaPage();
      case 6: // Contabilidad
        return const DashboardResumenPage();
      case 7: // Reportes
        if (selectedSubIndex != null) {
          switch (selectedSubIndex) {
            case 0:
              return const ReporteScreen();
          }
        }
        return const ReporteScreen();
      case 8: // Opciones
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
      if (selectedSubIndex != null && item.subItems != null) {
        return '${item.title} - ${item.subItems![selectedSubIndex!].title}';
      }
      return item.title;
    }
    return 'Dashboard';
  }

  IconData _getSelectedIcon() {
    if (selectedIndex >= 0 && selectedIndex < sidebarItems.length) {
      final item = sidebarItems[selectedIndex];
      if (selectedSubIndex != null && item.subItems != null) {
        return item.subItems![selectedSubIndex!].icon;
      }
      return item.icon;
    }
    return Icons.dashboard;
  }

  final List<SidebarItem> sidebarItems = [
    SidebarItem(
      icon: Icons.dashboard_outlined,
      title: 'Dashboard',
      isSelected: true,
    ),
    SidebarItem(
      icon: Icons.account_circle,
      title: 'Clientes',
    ),
    SidebarItem(
      icon: Icons.home,
      title: 'Inmuebles',
      subItems: [
        SidebarSubItem(icon: Icons.home, title: 'Casas'),
        SidebarSubItem(icon: Icons.category, title: 'Categorías de Inmuebles'),
        SidebarSubItem(icon: Icons.speed, title: 'Medidores'),
        SidebarSubItem(icon: Icons.calculate, title: 'Tarifa de Servicio'),
      ],
    ),
    SidebarItem(
      icon: Icons.receipt_long,
      title: 'Deudas',
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
      subItems: [
        SidebarSubItem(icon: Icons.place, title: 'Establecimientos'),
        SidebarSubItem(icon: Icons.point_of_sale_outlined, title: 'Cajas'),
        SidebarSubItem(icon: Icons.electrical_services, title: 'Timbrados'),
        SidebarSubItem(
            icon: Icons.watch_later_outlined,
            title: 'Apertura y Cierre de Caja'),
      ],
    ),
    SidebarItem(
      icon: Icons.receipt,
      title: 'Facturación',
      subItems: [
        SidebarSubItem(icon: Icons.home, title: 'Conceptos'),
        SidebarSubItem(icon: Icons.calendar_month, title: 'Ciclos'),
      ],
    ),
    SidebarItem(
      icon: Icons.trending_up,
      title: 'Contabilidad',
    ),
    SidebarItem(
      icon: Icons.graphic_eq,
      title: 'Reportes',
      subItems: [
        SidebarSubItem(icon: Icons.graphic_eq, title: 'Deudas Clientes'),
      ],
    ),
    SidebarItem(
      icon: Icons.settings,
      title: 'Opciones',
    ),
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
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
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
                      Consumer<AuthProvider>(
                        builder: (context, authProvider, _) {
                          return Row(
                            children: [
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    authProvider.usuarioNombre,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF111827),
                                    ),
                                  ),
                                  Text(
                                    authProvider.cargoNombre,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 12),
                              Container(
                                width: 36,
                                height: 36,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF0085FF),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    authProvider.usuarioNombre.isNotEmpty
                                        ? authProvider.usuarioNombre[0]
                                            .toUpperCase()
                                        : 'U',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert,
                                    size: 20, color: Color(0xFF6B7280)),
                                onSelected: (value) async {
                                  if (value == 'logout') {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title:
                                            const Text('Cerrar Sesión'),
                                        content: const Text(
                                            '¿Estás seguro de que deseas cerrar sesión?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: const Text('Cancelar'),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            style: TextButton.styleFrom(
                                                foregroundColor: Colors.red),
                                            child: const Text('Cerrar Sesión'),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirm == true && context.mounted) {
                                      await authProvider.logout();
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) => const LoginPage()),
                                      );
                                    }
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'logout',
                                    child: Row(
                                      children: [
                                        Icon(Icons.logout,
                                            size: 18, color: Colors.red),
                                        SizedBox(width: 12),
                                        Text('Cerrar Sesión'),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                // Content Area
                Expanded(child: _getSelectedWidget()),
                // Status Bar
                Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration:
                      const BoxDecoration(color: Color(0xFF374151)),
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
                        style:
                            TextStyle(color: Colors.white, fontSize: 12),
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
      count++;
      if (sidebarItems[i].isExpanded && sidebarItems[i].subItems != null) {
        count += sidebarItems[i].subItems!.length;
      }
    }
    return count;
  }

  Widget _buildSidebarItem(int displayIndex) {
    int currentIndex = 0;
    for (int i = 0; i < sidebarItems.length; i++) {
      if (currentIndex == displayIndex) {
        return _buildMainItem(i);
      }
      currentIndex++;
      if (sidebarItems[i].isExpanded && sidebarItems[i].subItems != null) {
        for (int j = 0; j < sidebarItems[i].subItems!.length; j++) {
          if (currentIndex == displayIndex) {
            return _buildSubItem(i, j);
          }
          currentIndex++;
        }
      }
    }
    return Container();
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
              for (var sidebarItem in sidebarItems) {
                sidebarItem.isSelected = false;
                sidebarItem.isExpanded = false;
              }
              sidebarItems[index].isSelected = true;
              selectedIndex = index;
              selectedSubIndex = null;
              if (hasSubItems) {
                sidebarItems[index].isExpanded = true;
              }
            });
          },
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF3A4553)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(item.icon,
                    color: Colors.white.withOpacity(0.9), size: 18),
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
                          horizontal: 6, vertical: 2),
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
    final isSelected =
        parentItem.isSelected && selectedSubIndex == subIndex;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () {
            setState(() {
              for (var sidebarItem in sidebarItems) {
                sidebarItem.isSelected = false;
                sidebarItem.isExpanded = false;
              }
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
              color: isSelected
                  ? const Color(0xFF3A4553)
                  : Colors.transparent,
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