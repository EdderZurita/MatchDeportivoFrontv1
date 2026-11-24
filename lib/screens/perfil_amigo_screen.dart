import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'chat_screen.dart';

class PerfilAmigoScreen extends StatefulWidget {
  final int usuarioId;
  final String username;
  final String miUsername;

  const PerfilAmigoScreen({
    super.key,
    required this.usuarioId,
    required this.username,
    required this.miUsername,
  });

  @override
  State<PerfilAmigoScreen> createState() => _PerfilAmigoScreenState();
}

class _PerfilAmigoScreenState extends State<PerfilAmigoScreen> {
  Map<String, dynamic>? _perfil;
  List<dynamic> _historial = [];
  bool _cargando = true;

  final Map<String, String> _niveles = {
    'PRINCIPIANTE': 'Principiante',
    'INTERMEDIO': 'Intermedio',
    'AVANZADO': 'Avanzado',
  };

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    final resultados = await Future.wait([
      ApiService.getPerfilUsuario(widget.usuarioId),
      ApiService.getHistorialUsuario(widget.usuarioId),
    ]);

    if (!mounted) return;
    setState(() {
      _perfil = resultados[0] as Map<String, dynamic>?;
      _historial = (resultados[1] as List<dynamic>?) ?? [];
      _cargando = false;
    });
  }

  String _formatearFecha(String? fechaStr) {
    if (fechaStr == null) return '';
    final f = DateTime.tryParse(fechaStr)?.toLocal();
    if (f == null) return '';
    return '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year} a las ${f.hour.toString().padLeft(2, '0')}:${f.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final reputacion = _perfil?['reputacion_promedio'] ?? '5.00';
    final esPremium = _perfil?['es_premium'] ?? false;
    final comuna = _perfil?['comuna'] ?? 'Sin comuna especificada';
    final deporte = _perfil?['deporte_favorito'] ?? 'No especificado';
    final nivelDisplay = _niveles[_perfil?['nivel_habilidad']] ?? 'Principiante';
    final bio = (_perfil?['biografia'] ?? '').toString().trim();

    final organizadosCount = _historial.where((h) => h['rol'] == 'ORGANIZADOR').length;
    final participadosCount = _historial.where((h) => h['rol'] == 'PARTICIPANTE').length;

    return Scaffold(
      appBar: AppBar(
        title: Text('Perfil de ${widget.username}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            tooltip: 'Mensaje directo',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    titulo: 'Chat con ${widget.username}',
                    miUsername: widget.miUsername,
                    amigoId: widget.usuarioId,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarDatos,
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Tarjeta de Identidad y Reputación
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: Colors.deepOrange.shade100,
                  child: Text(
                    widget.username.isNotEmpty ? widget.username[0].toUpperCase() : 'U',
                    style: const TextStyle(fontSize: 38, fontWeight: FontWeight.bold, color: Colors.deepOrange),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.username,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.star, size: 16, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(
                            '$reputacion',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (esPremium)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Premium',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.purple.shade900,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 2. Ficha Deportiva (RF-3)
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Detalles Deportivos',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const Divider(height: 18),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 18, color: Colors.deepOrange),
                      const SizedBox(width: 8),
                      Expanded(child: Text('Comuna: $comuna')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.sports_soccer, size: 18, color: Colors.deepOrange),
                      const SizedBox(width: 8),
                      Expanded(child: Text('Deporte: $deporte')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.fitness_center, size: 18, color: Colors.deepOrange),
                      const SizedBox(width: 8),
                      Text('Nivel: '),
                      Chip(
                        label: Text(nivelDisplay),
                        backgroundColor: Colors.deepOrange.shade50,
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        labelStyle: TextStyle(
                          color: Colors.deepOrange.shade900,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  if (bio.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Text('Biografía:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 2),
                    Text(bio, style: const TextStyle(fontSize: 14)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 3. Resumen de Actividad
          Row(
            children: [
              Expanded(
                child: Card(
                  color: Colors.blue.shade50,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      children: [
                        Text(
                          '$participadosCount',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                        ),
                        const Text('Jugados', style: TextStyle(fontSize: 12, color: Colors.black54)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Card(
                  color: Colors.deepOrange.shade50,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      children: [
                        Text(
                          '$organizadosCount',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepOrange.shade900),
                        ),
                        const Text('Organizados', style: TextStyle(fontSize: 12, color: Colors.black54)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 4. Historial de Participación Deportiva (RF-7)
          Text(
            'Historial de Convocatorias (${_historial.length})',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          if (_historial.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Aún no registra participación en actividades deportivas.',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            )
          else
            ..._historial.map((act) {
              final fecha = DateTime.tryParse(act['fecha_hora'] ?? '');
              final esPasada = act['estado'] == 'FINALIZADA' ||
                  (fecha != null && fecha.isBefore(DateTime.now()));
              final bool esOrganizador = act['rol'] == 'ORGANIZADOR';

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 5),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: esOrganizador ? Colors.deepOrange.shade100 : Colors.blue.shade100,
                    child: Icon(
                      esOrganizador ? Icons.campaign : Icons.sports,
                      color: esOrganizador ? Colors.deepOrange : Colors.blue,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    act['titulo'] ?? 'Sin título',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${act['deporte']} • ${act['comuna']}'),
                      Text(
                        _formatearFecha(act['fecha_hora']),
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: esOrganizador ? Colors.deepOrange.shade50 : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: esOrganizador ? Colors.deepOrange.shade200 : Colors.blue.shade200,
                      ),
                    ),
                    child: Text(
                      act['rol'],
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: esOrganizador ? Colors.deepOrange.shade900 : Colors.blue.shade900,
                      ),
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}