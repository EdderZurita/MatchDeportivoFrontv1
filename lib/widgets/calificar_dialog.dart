import 'package:flutter/material.dart';
import '../services/api_service.dart';

class CalificarJugadorDialog extends StatefulWidget {
  final int actividadId;
  final int usuarioId;
  final String username;

  const CalificarJugadorDialog({
    super.key,
    required this.actividadId,
    required this.usuarioId,
    required this.username,
  });

  @override
  State<CalificarJugadorDialog> createState() => _CalificarJugadorDialogState();
}

class _CalificarJugadorDialogState extends State<CalificarJugadorDialog> {
  int _estrellas = 5;
  final _comentarioCtrl = TextEditingController();
  bool _enviando = false;

  @override
  void dispose() {
    _comentarioCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    setState(() => _enviando = true);
    final res = await ApiService.calificarJugador(
      actividadId: widget.actividadId,
      evaluadoId: widget.usuarioId,
      puntuacion: _estrellas,
      comentario: _comentarioCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _enviando = false);

    final bool exito = res['exito'] == true;
    final String mensaje = res['detail']?.toString() ??
        (exito ? 'Calificación registrada correctamente.' : 'Error al calificar.');

    Navigator.pop(context, exito);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: exito ? Colors.green : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Calificar a ${widget.username}',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '¿Qué tal fue su juego limpio y puntualidad?',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Ajuste responsivo para evitar el desborde horizontal de píxeles
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final valor = index + 1;
                  return IconButton(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      valor <= _estrellas ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 32,
                    ),
                    onPressed: () => setState(() => _estrellas = valor),
                  );
                }),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _comentarioCtrl,
              maxLines: 2,
              maxLength: 200,
              decoration: const InputDecoration(
                hintText: 'Comentario opcional sobre su desempeño...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _enviando ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepOrange,
            foregroundColor: Colors.white,
          ),
          onPressed: _enviando ? null : _enviar,
          child: _enviando
              ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
              : const Text('Enviar Calificación'),
        ),
      ],
    );
  }
}