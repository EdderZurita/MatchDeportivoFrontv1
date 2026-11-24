import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AdminUsuariosScreen extends StatefulWidget {
  const AdminUsuariosScreen({super.key});

  @override
  State<AdminUsuariosScreen> createState() => _AdminUsuariosScreenState();
}

class _AdminUsuariosScreenState extends State<AdminUsuariosScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _usuarios = [];
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    _buscar('');
  }

  Future<void> _buscar(String query) async {
    setState(() => _cargando = true);
    final resultados = await ApiService.buscarUsuarios(query);
    if (!mounted) return;
    setState(() {
      _usuarios = resultados;
      _cargando = false;
    });
  }

  void _confirmarCambioEstado(Map<String, dynamic> usuario) {
    final bool estaActivo = usuario['is_active'] ?? true;
    final TextEditingController motivoCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          estaActivo ? 'Suspender Usuario' : 'Reactivar Usuario',
          style: TextStyle(
            color: estaActivo ? Colors.red.shade800 : const Color(0xFF2E7D32),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              estaActivo
                  ? '¿Seguro que deseas suspender la cuenta de @${usuario['username']}? No podrá iniciar sesión ni participar en partidos.'
                  : '¿Deseas reactivar el acceso para @${usuario['username']}?',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: motivoCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Motivo de la acción (Auditoría)',
                hintText: 'Ej: Conducta antideportiva, spam, solicitud del usuario...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: estaActivo ? Colors.red.shade700 : const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final resp = await ApiService.cambiarEstadoCuenta(
                usuarioId: usuario['id'],
                motivo: motivoCtrl.text.trim(),
              );

              if (!mounted) return;
              if (resp['exito'] == true) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(resp['data']['detail'] ?? 'Estado actualizado.'),
                    backgroundColor: const Color(0xFF2E7D32),
                  ),
                );
                _buscar(_searchController.text.trim());
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(resp['error']),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Text(estaActivo ? 'Suspender' : 'Reactivar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Cuentas (RF-26)'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar por usuario, nombre o comuna...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _buscar('');
                  },
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onSubmitted: _buscar,
            ),
          ),
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32)))
                : _usuarios.isEmpty
                ? const Center(child: Text('No se encontraron usuarios.'))
                : ListView.separated(
              itemCount: _usuarios.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final u = _usuarios[index];
                final bool activo = u['is_active'] ?? true;
                final bool esStaff = u['is_staff'] == true;

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: activo ? Colors.green.shade100 : Colors.red.shade100,
                    child: Icon(
                      activo ? Icons.person : Icons.person_off,
                      color: activo ? const Color(0xFF2E7D32) : Colors.red.shade800,
                    ),
                  ),
                  title: Row(
                    children: [
                      Text(
                        u['username'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (esStaff) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('STAFF', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue)),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Text(
                    'Email: ${u['email'] ?? 'N/A'} • Comuna: ${u['comuna'] ?? 'N/A'}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                  trailing: esStaff
                      ? const Chip(label: Text('Protegido', style: TextStyle(fontSize: 11)))
                      : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: activo ? Colors.red.shade50 : Colors.green.shade50,
                      foregroundColor: activo ? Colors.red.shade700 : const Color(0xFF2E7D32),
                      elevation: 0,
                      side: BorderSide(
                        color: activo ? Colors.red.shade300 : const Color(0xFF2E7D32),
                      ),
                    ),
                    onPressed: () => _confirmarCambioEstado(u),
                    child: Text(activo ? 'Suspender' : 'Reactivar'),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}