import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'crear_actividad_screen.dart';
import 'detalle_actividad_screen.dart';

class MisActividadesScreen extends StatefulWidget {
  final String? miUsername;

  const MisActividadesScreen({super.key, this.miUsername});

  @override
  State<MisActividadesScreen> createState() => _MisActividadesScreenState();
}

class _MisActividadesScreenState extends State<MisActividadesScreen> {
  List<dynamic> _organizadas = [];
  List<dynamic> _inscripciones = [];
  bool _cargando = true;
  String? _usuarioActual;

  @override
  void initState() {
    super.initState();
    _cargarTodo();
  }

  Future<void> _cargarTodo() async {
    setState(() => _cargando = true);
    try {
      final user = await ApiService.getUsername();
      _usuarioActual = user ?? widget.miUsername;

      if (_usuarioActual == null || _usuarioActual!.isEmpty) {
        setState(() {
          _organizadas = [];
          _inscripciones = [];
          _cargando = false;
        });
        return;
      }

      final resultados = await Future.wait([
        ApiService.getMisActividades(),
        ApiService.getMisInscripciones(),
      ]);

      List<dynamic> misActividades = resultados[0];
      if (misActividades.isEmpty) {
        final todas = await ApiService.getActividades();
        misActividades = todas.where((a) {
          final orgNombre = a['organizador_nombre'] ?? a['organizador_username'] ?? '';
          return orgNombre.toString().toLowerCase() == _usuarioActual!.toLowerCase();
        }).toList();
      }

      if (mounted) {
        setState(() {
          _organizadas = misActividades;
          _inscripciones = resultados[1];
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  bool _esHistorica(dynamic act) {
    if (act['estado'] == 'FINALIZADA' || act['estado'] == 'CANCELADA') {
      return true;
    }
    final fechaStr = act['fecha_hora'];
    if (fechaStr != null) {
      final fecha = DateTime.tryParse(fechaStr);
      if (fecha != null && fecha.isBefore(DateTime.now())) {
        return true;
      }
    }
    return false;
  }

  String _formatearFecha(String? fechaStr) {
    if (fechaStr == null) return '';
    final f = DateTime.tryParse(fechaStr)?.toLocal();
    if (f == null) return '';
    return '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year} a las ${f.hour.toString().padLeft(2, '0')}:${f.minute.toString().padLeft(2, '0')} hrs';
  }

  Future<void> _confirmarEliminacion(int id) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar actividad?'),
        content: const Text('Esta acción cancelará la convocatoria deportiva.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      final exito = await ApiService.eliminarActividad(id);
      if (exito) {
        _cargarTodo();
      }
    }
  }

  Widget _buildTarjetaActividad(dynamic act, {required bool esInscripcion}) {
    final fechaFormateada = _formatearFecha(act['fecha_hora']);
    final bool historica = _esHistorica(act);
    final String deporte = act['deporte_display'] ?? act['deporte'] ?? 'Deporte';
    final String comuna = act['comuna'] ?? '';
    final int cuposDisponibles = act['cupos_disponibles'] ?? 0;
    final int cuposTotales = act['cupos_totales'] ?? 0;
    final String? miEstado = act['mi_estado_inscripcion'];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: historica ? 0.5 : 2,
      color: historica ? Colors.grey.shade100 : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: historica ? Colors.grey.shade300 : Colors.transparent,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        title: Text(
          act['titulo'] ?? 'Sin título',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: historica ? Colors.grey.shade700 : Colors.black87,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '$deporte • $comuna',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
            ),
            const SizedBox(height: 2),
            Text(
              fechaFormateada,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  'Cupos: $cuposDisponibles/$cuposTotales',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: cuposDisponibles > 0 ? Colors.green.shade800 : Colors.red.shade800,
                  ),
                ),
                if (esInscripcion && miEstado != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: miEstado == 'CONFIRMADA' ? Colors.green.shade100 : Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      miEstado == 'CONFIRMADA' ? 'Confirmado' : 'Pendiente',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: miEstado == 'CONFIRMADA' ? Colors.green.shade900 : Colors.brown.shade900,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        isThreeLine: true,
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DetalleActividadScreen(actividad: act),
            ),
          );
          _cargarTodo();
        },
        trailing: esInscripcion
            ? const Icon(Icons.chevron_right, color: Colors.grey)
            : (historica
            ? Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.blueGrey.shade100,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            'HISTÓRICO',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey.shade900,
            ),
          ),
        )
            : Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue, size: 22),
              tooltip: 'Editar partido',
              onPressed: () async {
                final res = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CrearActividadScreen(actividadExistente: act),
                  ),
                );
                if (res == true) _cargarTodo();
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red, size: 22),
              tooltip: 'Eliminar partido',
              onPressed: () => _confirmarEliminacion(act['id']),
            ),
          ],
        )),
      ),
    );
  }

  Widget _buildVistaVacia({required String mensaje, bool mostrarBotonCrear = false}) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 100),
        Icon(Icons.sports_soccer_outlined, size: 64, color: Colors.grey.shade400),
        const SizedBox(height: 16),
        Text(
          mensaje,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
        ),
        if (mostrarBotonCrear) ...[
          const SizedBox(height: 16),
          Center(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final creado = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CrearActividadScreen()),
                );
                if (creado == true) _cargarTodo();
              },
              icon: const Icon(Icons.add),
              label: const Text('Crear Convocatoria'),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_usuarioActual == null || _usuarioActual!.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mis Convocatorias')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline, size: 72, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                const Text(
                  'Sesión requerida',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Debes iniciar sesión para ver y administrar tus partidos.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Mis Partidos ($_usuarioActual)'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Recargar partidos',
              onPressed: _cargarTodo,
            ),
          ],
          bottom: TabBar(
            indicatorColor: Colors.deepOrange,
            labelColor: Colors.deepOrange,
            unselectedLabelColor: Colors.grey.shade600,
            tabs: [
              Tab(
                icon: const Icon(Icons.campaign),
                text: 'Organizadas (${_organizadas.length})',
              ),
              Tab(
                icon: const Icon(Icons.sports),
                text: 'Inscrito (${_inscripciones.length})',
              ),
            ],
          ),
        ),
        body: _cargando
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
          children: [
            // Pestaña 1: Partidos Organizados por el usuario
            RefreshIndicator(
              onRefresh: _cargarTodo,
              child: _organizadas.isEmpty
                  ? _buildVistaVacia(
                mensaje: 'Aún no has organizado ningún partido.',
                mostrarBotonCrear: true,
              )
                  : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _organizadas.length,
                itemBuilder: (context, index) {
                  return _buildTarjetaActividad(
                    _organizadas[index],
                    esInscripcion: false,
                  );
                },
              ),
            ),

            // Pestaña 2: Partidos donde está Inscrito o Pendiente
            RefreshIndicator(
              onRefresh: _cargarTodo,
              child: _inscripciones.isEmpty
                  ? _buildVistaVacia(
                mensaje: 'No estás inscrito en ningún partido actualmente.',
              )
                  : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _inscripciones.length,
                itemBuilder: (context, index) {
                  return _buildTarjetaActividad(
                    _inscripciones[index],
                    esInscripcion: true,
                  );
                },
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(heroTag: 'fab_mis_actividades',
          backgroundColor: Colors.deepOrange,
          foregroundColor: Colors.white,
          onPressed: () async {
            final creado = await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CrearActividadScreen()),
            );
            if (creado == true) _cargarTodo();
          },
          icon: const Icon(Icons.add),
          label: const Text('Crear Partido'),
        ),
      ),
    );
  }
}