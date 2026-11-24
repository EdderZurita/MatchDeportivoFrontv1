import 'package:flutter/material.dart';
import '../services/api_service.dart';

class RecuperarPasswordScreen extends StatefulWidget {
  const RecuperarPasswordScreen({super.key});

  @override
  State<RecuperarPasswordScreen> createState() => _RecuperarPasswordScreenState();
}

class _RecuperarPasswordScreenState extends State<RecuperarPasswordScreen> {
  final _emailCtrl = TextEditingController();
  final _codigoCtrl = TextEditingController();
  final _nuevaPasswordCtrl = TextEditingController();

  bool _codigoEnviado = false;
  bool _cargando = false;
  String? _mensaje;
  bool _esError = false;

  Future<void> _solicitarCodigo() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() {
        _mensaje = 'Por favor ingresa tu correo electrónico.';
        _esError = true;
      });
      return;
    }

    setState(() {
      _cargando = true;
      _mensaje = null;
    });

    final res = await ApiService.solicitarCodigoRecuperacion(email);

    setState(() {
      _cargando = false;
      _mensaje = res['detail'];
      _esError = !res['exito'];
      if (res['exito'] == true) {
        _codigoEnviado = true;
      }
    });
  }

  Future<void> _restablecerPassword() async {
    final codigo = _codigoCtrl.text.trim();
    final nuevaClave = _nuevaPasswordCtrl.text;

    if (codigo.length != 6) {
      setState(() {
        _mensaje = 'El código debe tener exactamente 6 dígitos.';
        _esError = true;
      });
      return;
    }

    if (nuevaClave.length < 8) {
      setState(() {
        _mensaje = 'La nueva contraseña debe tener al menos 8 caracteres.';
        _esError = true;
      });
      return;
    }

    setState(() {
      _cargando = true;
      _mensaje = null;
    });

    final res = await ApiService.restablecerPassword(
      email: _emailCtrl.text.trim(),
      codigo: codigo,
      nuevaPassword: nuevaClave,
    );

    setState(() {
      _cargando = false;
      _mensaje = res['detail'];
      _esError = !res['exito'];
    });

    if (res['exito'] == true) {
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.pop(context); // Vuelve al Login
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recuperar Contraseña')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.lock_reset, size: 72, color: Colors.deepOrange),
            const SizedBox(height: 16),
            Text(
              !_codigoEnviado
                  ? 'Ingresa tu correo asociado para recibir un código de recuperación.'
                  : 'Ingresa el código de 6 dígitos enviado a tu correo y tu nueva contraseña.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 15),
            ),
            const SizedBox(height: 24),

            // Paso 1: Email
            TextFormField(
              controller: _emailCtrl,
              enabled: !_codigoEnviado,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Correo electrónico',
                prefixIcon: Icon(Icons.email_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Paso 2: Código OTP y Nueva Contraseña
            if (_codigoEnviado) ...[
              TextFormField(
                controller: _codigoCtrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'Código de 6 dígitos',
                  prefixIcon: Icon(Icons.pin_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nuevaPasswordCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Nueva Contraseña (mínimo 8 caracteres)',
                  prefixIcon: Icon(Icons.lock_outline),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
            ],

            ElevatedButton(
              onPressed: _cargando
                  ? null
                  : (!_codigoEnviado ? _solicitarCodigo : _restablecerPassword),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _cargando
                  ? const CircularProgressIndicator()
                  : Text(!_codigoEnviado ? 'Enviar Código' : 'Restablecer Contraseña'),
            ),

            if (_mensaje != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _esError ? Colors.red.shade50 : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _esError ? Colors.red.shade300 : Colors.green.shade300,
                  ),
                ),
                child: Text(
                  _mensaje!,
                  style: TextStyle(
                    color: _esError ? Colors.red.shade900 : Colors.green.shade900,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}