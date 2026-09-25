import 'dart:async';

import 'package:flutter/material.dart';
import 'package:myapp/modelo/usuario/authprovider.dart';
import 'package:myapp/vista/loginpage.dart';
import 'package:provider/provider.dart';

/// Envuelve una pantalla (pensado para el panel de administrador/empleado)
/// y cierra la sesión automáticamente si no hay interacción durante
/// [timeout], o si la app estuvo en background más de ese tiempo.
class InactivityWrapper extends StatefulWidget {
  final Widget child;
  final Duration timeout;

  const InactivityWrapper({
    Key? key,
    required this.child,
    this.timeout = const Duration(minutes: 15),
  }) : super(key: key);

  @override
  State<InactivityWrapper> createState() => _InactivityWrapperState();
}

class _InactivityWrapperState extends State<InactivityWrapper>
    with WidgetsBindingObserver {
  Timer? _timer;
  DateTime? _backgroundedAt;
  bool _cerrandoSesion = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _reiniciarTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _backgroundedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final backgroundedAt = _backgroundedAt;
      _backgroundedAt = null;
      if (backgroundedAt != null &&
          DateTime.now().difference(backgroundedAt) >= widget.timeout) {
        _cerrarPorInactividad();
      } else {
        _reiniciarTimer();
      }
    }
  }

  void _reiniciarTimer() {
    _timer?.cancel();
    _timer = Timer(widget.timeout, _cerrarPorInactividad);
  }

  Future<void> _cerrarPorInactividad() async {
    if (_cerrandoSesion || !mounted) return;
    _cerrandoSesion = true;

    await Provider.of<AuthProvider>(context, listen: false).logout();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  void _registrarActividad([_]) {
    if (!_cerrandoSesion) _reiniciarTimer();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _registrarActividad,
      onPointerMove: _registrarActividad,
      child: widget.child,
    );
  }
}
