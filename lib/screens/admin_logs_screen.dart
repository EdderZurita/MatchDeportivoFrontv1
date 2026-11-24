import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AdminLogsScreen extends StatefulWidget {
  const AdminLogsScreen({super.key});

  @override
  State<AdminLogsScreen> createState() => _AdminLogsScreenState();
}

class _AdminLogsScreenState extends State<AdminLogsScreen> {
  List<dynamic> _logs = [];
  bool _cargando = true;
  String? _filtroNivel;

  @override
  void initState() {
    super.initState();
    _cargarLogs();
  }

  Future<void> _cargarLogs() async {
    setState(() => _cargando = true);
    final data = await ApiService.getLogsSistema(nivel: _filtroNivel);
    if (!mounted) return;
    setState(() {
      _logs = data;
      _cargando = false;
    });
  }

  Color _obtenerColorNivel(String nivel) {
    switch (nivel.toUpperCase()) {
      case 'SUCCESS':
        return Colors.green.shade600;
      case 'WARNING':
        return Colors.amber.shade800;
      case 'ERROR':
        return Colors.red.shade600;
      default:
        return Colors.blue.shade600;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Auditoría del Sistema (RF-25)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarLogs,
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de filtros rápidos por severidad
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                _buildChipFiltro(null, 'Todos'),
                _buildChipFiltro('INFO', 'Info'),
                _buildChipFiltro('SUCCESS', 'Éxito'),
                _buildChipFiltro('WARNING', 'Advertencias'),
                _buildChipFiltro('ERROR', 'Errores'),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : _logs.isEmpty
                ? const Center(child: Text('No hay registros de actividad.'))
                : ListView.separated(
              itemCount: _logs.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final log = _logs[index];
                final nivel = log['nivel'] ?? 'INFO';
                final fecha = log['fecha_hora'] ?? '';
                final fechaFormateada = fecha.length >= 16
                    ? fecha.substring(0, 16).replaceAll('T', ' ')
                    : fecha;

                return ListTile(
                  leading: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _obtenerColorNivel(nivel).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _obtenerColorNivel(nivel)),
                    ),
                    child: Text(
                      nivel,
                      style: TextStyle(
                        color: _obtenerColorNivel(nivel),
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  title: Text(
                    log['accion'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 3),
                      Text(
                        log['descripcion'] ?? '',
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Usuario: ${log['usuario_username'] ?? 'Sistema'} • IP: ${log['ip_origen'] ?? 'N/A'} • $fechaFormateada hrs',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                      ),
                    ],
                  ),
                  isThreeLine: true,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChipFiltro(String? valor, String texto) {
    final seleccionado = _filtroNivel == valor;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        selected: seleccionado,
        label: Text(texto),
        onSelected: (_) {
          setState(() => _filtroNivel = valor);
          _cargarLogs();
        },
      ),
    );
  }
}