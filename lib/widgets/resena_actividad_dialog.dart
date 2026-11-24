import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ResenaActividadDialog extends StatefulWidget {
  final int actividadId;
  final String tituloActividad;

  const ResenaActividadDialog({
    super.key,
    required this.actividadId,
    required this.tituloActividad,
  });

  @override
  State<ResenaActividadDialog> createState() => _ResenaActividadDialogState();
}

class _ResenaActividadDialogState extends State<ResenaActividadDialog> {
  int _puntuacion = 5;
  final TextEditingController _comentarioCtrl = TextEditingController();
  bool _enviando = false;

  @override
  void dispose() {
    _comentarioCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final comentario = _comentarioCtrl.text.trim();
    if (comentario.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, escribe un comentario sobre el partido o recinto.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _enviando = true);

    final res = await ApiService.crearResenaActividad(
      actividadId: widget.actividadId,
      puntuacion: _puntuacion,
      comentario: comentario,
    );

    if (!mounted) return;
    setState(() => _enviando = false);

    final bool exito = res['exito'] == true;
    final String mensaje = res['data']?['detail'] ??
        res['error']?.toString() ??
        (exito ? '¡Reseña registrada con éxito!' : 'No se pudo registrar la reseña.');

    Navigator.pop(context, exito);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: exito ? const Color(0xFF2E7D32) : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Evaluar Encuentro (RF-27)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 4),
          Text(
            widget.tituloActividad,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '¿Cómo estuvo el partido, la organización y el recinto?',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),

            // Ajuste responsivo de estrellas sin desborde
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final valor = i + 1;
                  return IconButton(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      valor <= _puntuacion ? Icons.star : Icons.star_border,
                      color: Colors.amber.shade700,
                      size: 32,
                    ),
                    onPressed: () => setState(() => _puntuacion = valor),
                  );
                }),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _comentarioCtrl,
              maxLines: 3,
              maxLength: 500,
              decoration: InputDecoration(
                labelText: 'Comentario general',
                hintText: 'Ej: Buena cancha, puntualidad, buen ambiente...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
            backgroundColor: const Color(0xFF2E7D32),
            foregroundColor: Colors.white,
          ),
          onPressed: _enviando ? null : _enviar,
          child: _enviando
              ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
          )
              : const Text('Publicar'),
        ),
      ],
    );
  }
}