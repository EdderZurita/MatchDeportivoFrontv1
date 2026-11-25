// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'https://matchdeportivo-back-staging.onrender.com/api'; // STAGING: no subir a produccion
  static const _storage = FlutterSecureStorage();

  // ==========================================
  // GESTIÓN DE TOKENS Y SESIÓN (RF-2)
  // ==========================================
  static Future<void> saveTokens({
    required String access,
    required String refresh,
    String? username,
  }) async {
    await _storage.write(key: 'jwt_access', value: access);
    await _storage.write(key: 'jwt_refresh', value: refresh);
    if (username != null && username.isNotEmpty) {
      await _storage.write(key: 'username', value: username);
    }
  }

  static Future<String?> getAccessToken() async {
    return await _storage.read(key: 'jwt_access');
  }

  static Future<String?> getUsername() async {
    return await _storage.read(key: 'username');
  }

  static Future<void> logout() async {
    await _storage.deleteAll();
  }

  static Future<Map<String, String>> _getHeaders() async {
    final token = await getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  // ==========================================
  // AUTENTICACIÓN: REGISTRO Y LOGIN (RF-1, RF-2)
  // ==========================================
  static Future<Map<String, dynamic>> registrarUsuario(Map<String, dynamic> datosUsuario) async {
    try {
      final url = Uri.parse('$baseUrl/auth/registro/');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(datosUsuario),
      );

      final decoded = jsonDecode(response.body);
      if (response.statusCode == 201 || response.statusCode == 200) {
        return {'exito': true, 'data': decoded};
      } else {
        return {'exito': false, 'errores': decoded};
      }
    } catch (e) {
      return {'exito': false, 'errores': {'detail': 'Error de conexión: $e'}};
    }
  }

  static Future<bool> login(String username, String password) async {
    try {
      final url = Uri.parse('$baseUrl/auth/token/');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final access = data['access'];
        final refresh = data['refresh'];

        if (access != null && refresh != null) {
          await saveTokens(access: access, refresh: refresh, username: username);
          return true;
        }
      }
      return false;
    } catch (e) {
      print('Excepción en login: $e');
      return false;
    }
  }

  // ==========================================
  // CRUD DE ACTIVIDADES (RF-8, RF-9, RF-13, RF-15)
  // ==========================================
  static Future<List<dynamic>> getActividades() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse('$baseUrl/actividades/'), headers: headers);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic> && decoded.containsKey('results')) {
          return decoded['results'] as List<dynamic>;
        }
        return decoded as List<dynamic>;
      }
      return [];
    } catch (e) {
      print('Excepción en getActividades: $e');
      return [];
    }
  }

  // Obtener únicamente los partidos creados por el usuario logueado
  static Future<List<dynamic>> getMisActividades() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/actividades/mis-actividades/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic> && decoded.containsKey('results')) {
          return decoded['results'] as List<dynamic>;
        }
        return decoded as List<dynamic>;
      }
      return [];
    } catch (e) {
      print('Excepción en getMisActividades: $e');
      return [];
    }
  }

  // Obtener partidos donde el usuario está inscrito o pendiente de aprobación
  static Future<List<dynamic>> getMisInscripciones() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/actividades/mis-inscripciones/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is List) return decoded;
        if (decoded is Map && decoded['results'] is List) return decoded['results'];
      }
      return [];
    } catch (e) {
      print('Excepción en getMisInscripciones: $e');
      return [];
    }
  }

  static Future<bool> crearActividad(Map<String, dynamic> data) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/actividades/'),
        headers: headers,
        body: jsonEncode(data),
      );
      return response.statusCode == 201;
    } catch (e) {
      print('Excepción en crearActividad: $e');
      return false;
    }
  }

  static Future<bool> editarActividad(int id, Map<String, dynamic> data) async {
    try {
      final headers = await _getHeaders();
      final response = await http.patch(
        Uri.parse('$baseUrl/actividades/$id/'),
        headers: headers,
        body: jsonEncode(data),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Excepción en editarActividad: $e');
      return false;
    }
  }

  static Future<bool> eliminarActividad(int id) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/actividades/$id/'),
        headers: headers,
      );
      return response.statusCode == 204 || response.statusCode == 200;
    } catch (e) {
      print('Excepción en eliminarActividad: $e');
      return false;
    }
  }

  // ==========================================
  // FLUJO DE INSCRIPCIONES Y PARTICIPANTES (RF-10, RF-11, RF-12, RF-14)
  // ==========================================

  // Obtener el detalle fresco de una actividad
  static Future<Map<String, dynamic>?> getDetalleActividad(int actividadId) async {
    try {
      final headers = await _getHeaders();
      final res = await http.get(Uri.parse('$baseUrl/actividades/$actividadId/'), headers: headers);
      if (res.statusCode == 200) {
        return jsonDecode(utf8.decode(res.bodyBytes));
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Inscribirse al partido (RF-10, RF-12, RF-14)
  static Future<Map<String, dynamic>> inscribirseActividad(int actividadId) async {
    try {
      final headers = await _getHeaders();
      final res = await http.post(
        Uri.parse('$baseUrl/actividades/$actividadId/inscribirse/'),
        headers: headers,
      );
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      return {
        'exito': res.statusCode == 201,
        'detail': decoded['detail'] ?? 'Respuesta del servidor',
      };
    } catch (e) {
      return {'exito': false, 'detail': 'Error de conexión: $e'};
    }
  }

  // Abandonar partido (RF-11)
  static Future<Map<String, dynamic>> abandonarActividad(int actividadId) async {
    try {
      final headers = await _getHeaders();
      final res = await http.post(
        Uri.parse('$baseUrl/actividades/$actividadId/abandonar/'),
        headers: headers,
      );
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      return {
        'exito': res.statusCode == 200,
        'detail': decoded['detail'] ?? 'Respuesta del servidor',
      };
    } catch (e) {
      return {'exito': false, 'detail': 'Error de conexión: $e'};
    }
  }

  // Listar los inscritos de un partido
  static Future<List<dynamic>> getParticipantesActividad(int actividadId) async {
    try {
      final headers = await _getHeaders();
      final res = await http.get(
        Uri.parse('$baseUrl/inscripciones/?actividad=$actividadId'),
        headers: headers,
      );
      if (res.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(res.bodyBytes));
        if (decoded is Map<String, dynamic> && decoded.containsKey('results')) {
          return decoded['results'] as List<dynamic>;
        }
        return decoded as List<dynamic>;
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // Moderar participante (RF-14: 'CONFIRMADA', 'RECHAZADA', 'EXPULSADA')
  static Future<bool> gestionarParticipante(int actividadId, int usuarioId, String nuevoEstado) async {
    try {
      final headers = await _getHeaders();
      final res = await http.post(
        Uri.parse('$baseUrl/actividades/$actividadId/gestionar_participante/'),
        headers: headers,
        body: jsonEncode({
          'usuario_id': usuarioId,
          'estado': nuevoEstado,
        }),
      );
      return res.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ==========================================
  // RECUPERACIÓN DE CONTRASEÑA (CÓDIGO OTP)
  // ==========================================

  static Future<Map<String, dynamic>> solicitarCodigoRecuperacion(String email) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/auth/solicitar-recuperacion/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      if (res.statusCode != 200) {
        return {
          'exito': false,
          'detail': 'Error del servidor (${res.statusCode}): Revisa los logs de Render.',
        };
      }

      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      return {
        'exito': true,
        'detail': decoded['detail'] ?? 'Código enviado con éxito.',
      };
    } catch (e) {
      return {'exito': false, 'detail': 'Error de conexión: $e'};
    }
  }

  static Future<Map<String, dynamic>> restablecerPassword({
    required String email,
    required String codigo,
    required String nuevaPassword,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/auth/restablecer-password/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'codigo': codigo,
          'nueva_password': nuevaPassword,
        }),
      );
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      return {
        'exito': res.statusCode == 200,
        'detail': decoded['detail'] ?? 'Respuesta del servidor',
      };
    } catch (e) {
      return {'exito': false, 'detail': 'Error de conexión: $e'};
    }
  }

  // ==========================================
  // AMISTADES Y BÚSQUEDA DE USUARIOS
  // ==========================================

  static Future<List<dynamic>> getMisAmigos() async {
    try {
      final token = await getAccessToken();
      final res = await http.get(
        Uri.parse('$baseUrl/amistades/mis-amigos/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (res.statusCode == 200) {
        return jsonDecode(utf8.decode(res.bodyBytes));
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<List<dynamic>> buscarUsuarios(String query) async {
    try {
      final token = await getAccessToken();
      final res = await http.get(
        Uri.parse('$baseUrl/usuarios/?search=$query'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      );
      if (res.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(res.bodyBytes));
        if (decoded is List) return decoded;
        if (decoded is Map && decoded['results'] is List) return decoded['results'];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> enviarSolicitudAmistad(String username) async {
    try {
      final token = await getAccessToken();
      final res = await http.post(
        Uri.parse('$baseUrl/amistades/enviar-solicitud/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'username': username}),
      );
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      return {
        'exito': res.statusCode == 200 || res.statusCode == 201,
        'detail': decoded['detail'] ?? 'Respuesta del servidor',
      };
    } catch (e) {
      return {'exito': false, 'detail': 'Error de conexión: $e'};
    }
  }

  static Future<Map<String, dynamic>> eliminarAmigo(int amigoId) async {
    try {
      final token = await getAccessToken();
      final res = await http.post(
        Uri.parse('$baseUrl/amistades/eliminar-amigo/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'amigo_id': amigoId}),
      );

      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      return {
        'exito': res.statusCode == 200,
        'detail': decoded['detail'] ?? 'Respuesta del servidor',
      };
    } catch (e) {
      return {'exito': false, 'detail': 'Error de conexión: $e'};
    }
  }

  static Future<List<dynamic>> getSolicitudesRecibidas() async {
    try {
      final token = await getAccessToken();
      final res = await http.get(
        Uri.parse('$baseUrl/amistades/solicitudes-recibidas/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (res.statusCode == 200) {
        return jsonDecode(utf8.decode(res.bodyBytes));
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> responderSolicitud(int solicitudId, String accion) async {
    try {
      final token = await getAccessToken();
      final res = await http.post(
        Uri.parse('$baseUrl/amistades/responder-solicitud/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'solicitud_id': solicitudId,
          'accion': accion,
        }),
      );
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      return {
        'exito': res.statusCode == 200,
        'detail': decoded['detail'] ?? 'Respuesta del servidor',
      };
    } catch (e) {
      return {'exito': false, 'detail': 'Error de conexión: $e'};
    }
  }

  // ==========================================
  // PERFIL DE USUARIO (RF-3)
  // ==========================================
  static Future<Map<String, dynamic>?> getMiPerfil() async {
    try {
      final headers = await _getHeaders();
      final res = await http.get(
        Uri.parse('$baseUrl/usuarios/mi_perfil/'),
        headers: headers,
      );
      if (res.statusCode == 200) {
        return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> actualizarMiPerfil(Map<String, dynamic> datos) async {
    try {
      final headers = await _getHeaders();
      final res = await http.patch(
        Uri.parse('$baseUrl/usuarios/mi_perfil/'),
        headers: headers,
        body: jsonEncode(datos),
      );
      return res.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ==========================================
  // CHAT Y MENSAJERÍA (1 a 1 Y ACTIVIDADES)
  // ==========================================
  static Future<List<dynamic>> getMensajes({int? actividadId, int? amigoId}) async {
    try {
      final token = await getAccessToken();
      String queryParam = '';
      if (actividadId != null) {
        queryParam = '?actividad_id=$actividadId';
      } else if (amigoId != null) {
        queryParam = '?amigo_id=$amigoId';
      }

      final res = await http.get(
        Uri.parse('$baseUrl/mensajes/$queryParam'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (res.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(res.bodyBytes));
        if (decoded is List) return decoded;
        if (decoded is Map && decoded['results'] is List) return decoded['results'];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<bool> enviarMensaje({
    int? actividadId,
    int? amigoId,
    required String contenido,
  }) async {
    try {
      final token = await getAccessToken();
      final body = <String, dynamic>{
        'contenido': contenido,
      };

      if (actividadId != null) body['actividad'] = actividadId;
      if (amigoId != null) body['receptor'] = amigoId;

      final res = await http.post(
        Uri.parse('$baseUrl/mensajes/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      return res.statusCode == 201 || res.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ==========================================
  // PERFIL DE AMIGOS E HISTORIAL (RF-7)
  // ==========================================
  static Future<Map<String, dynamic>?> getPerfilUsuario(int usuarioId) async {
    try {
      final headers = await _getHeaders();
      final res = await http.get(
        Uri.parse('$baseUrl/usuarios/$usuarioId/'),
        headers: headers,
      );
      if (res.statusCode == 200) {
        return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<List<dynamic>> getHistorialUsuario(int usuarioId) async {
    try {
      final headers = await _getHeaders();
      final res = await http.get(
        Uri.parse('$baseUrl/usuarios/$usuarioId/historial/'),
        headers: headers,
      );
      if (res.statusCode == 200) {
        return jsonDecode(utf8.decode(res.bodyBytes)) as List<dynamic>;
      }
      return [];
    } catch (e) {
      return [];
    }
  }
  static Future<bool> registrarTokenFCM(String token) async {
    try {
      final headers = await _getHeaders();
      final res = await http.post(
        Uri.parse('$baseUrl/usuarios/registrar-fcm/'),
        headers: headers,
        body: jsonEncode({'token': token}),
      );
      return res.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
  // ==========================================
  // RF-18, RF-19: CALIFICACIONES POST-PARTIDO
  // ==========================================
  static Future<List<dynamic>> getPendientesCalificar(int actividadId) async {
    try {
      final headers = await _getHeaders();
      final res = await http.get(
        Uri.parse('$baseUrl/calificaciones/pendientes/$actividadId/'),
        headers: headers,
      );
      if (res.statusCode == 200) {
        return jsonDecode(utf8.decode(res.bodyBytes)) as List<dynamic>;
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> calificarJugador({
    required int actividadId,
    required int evaluadoId,
    required int puntuacion,
    String? comentario,
  }) async {
    try {
      final headers = await _getHeaders();
      final res = await http.post(
        Uri.parse('$baseUrl/calificaciones/'),
        headers: headers,
        body: jsonEncode({
          'actividad': actividadId,
          'evaluado': evaluadoId,
          'puntuacion': puntuacion,
          'comentario': comentario ?? '',
        }),
      );
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      return {
        'exito': res.statusCode == 201,
        'detail': decoded['detail'] ?? 'Calificación enviada correctamente.',
      };
    } catch (e) {
      return {'exito': false, 'detail': 'Error de conexión: $e'};
    }
  }

  // ==========================================
  // RF-20: REPORTE DE USUARIO
  // ==========================================
  static Future<Map<String, dynamic>> reportarUsuario({
    required int reportadoId,
    required String motivo,
    required String descripcion,
    int? actividadId,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = <String, dynamic>{
        'reportado': reportadoId,
        'motivo': motivo,
        'descripcion': descripcion,
      };
      if (actividadId != null) body['actividad'] = actividadId;

      final res = await http.post(
        Uri.parse('$baseUrl/reportes/'),
        headers: headers,
        body: jsonEncode(body),
      );
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      return {
        'exito': res.statusCode == 201,
        'detail': decoded['detail'] ?? 'Reporte registrado y enviado a moderación.',
      };
    } catch (e) {
      return {'exito': false, 'detail': 'Error de conexión: $e'};
    }
  }

  // ==========================================
  // RF-21: BLOQUEO DE USUARIO
  // ==========================================
  static Future<bool> bloquearUsuario(int usuarioId) async {
    try {
      final headers = await _getHeaders();
      final res = await http.post(
        Uri.parse('$baseUrl/bloqueos/'),
        headers: headers,
        body: jsonEncode({'bloqueado': usuarioId}),
      );
      return res.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> desbloquearUsuario(int usuarioId) async {
    try {
      final headers = await _getHeaders();
      final res = await http.post(
        Uri.parse('$baseUrl/bloqueos/desbloquear/'),
        headers: headers,
        body: jsonEncode({'bloqueado_id': usuarioId}),
      );
      return res.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
  // ==========================================
  // RF-22, RF-23, RF-24: PASARELA FLOW Y PREMIUM
  // ==========================================

  // RF-22: Solicita la URL y token para vincular tarjeta
  static Future<Map<String, dynamic>> iniciarSuscripcionPremium() async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('$baseUrl/pagos/iniciar-suscripcion/');
      final res = await http.post(url, headers: headers);

      final data = jsonDecode(utf8.decode(res.bodyBytes));

      if (res.statusCode != 200) {
        return {
          'exito': false,
          'detail': data['detail'] ?? 'El servidor respondió con código ${res.statusCode}.',
        };
      }

      return {
        'exito': true,
        'url': data['url'],
        'detail': data['detail'] ?? '',
      };
    } catch (e) {
      return {'exito': false, 'detail': 'Error de conexión: $e'};
    }
  }

  // RF-23: Consulta el estado vigente de la suscripción
  static Future<Map<String, dynamic>?> getEstadoSuscripcion() async {
    try {
      final headers = await _getHeaders();
      final res = await http.get(
        Uri.parse('$baseUrl/pagos/mi-suscripcion/'),
        headers: headers,
      );
      if (res.statusCode == 200) {
        return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // RF-24: Cancela el cobro recurrente en Flow
  static Future<Map<String, dynamic>> cancelarSuscripcion() async {
    try {
      final headers = await _getHeaders();
      final res = await http.post(
        Uri.parse('$baseUrl/pagos/cancelar-suscripcion/'),
        headers: headers,
      );
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      return {
        'exito': res.statusCode == 200,
        'detail': data['detail'] ?? 'Suscripción cancelada.',
      };
    } catch (e) {
      return {'exito': false, 'detail': 'Error de conexión: $e'};
    }
  }
  static Future<Map<String, dynamic>> crearActividadConDetalle(Map<String, dynamic> datos) async {
    try {
      final headers = await _getHeaders();
      final res = await http.post(
        Uri.parse('$baseUrl/actividades/'),
        headers: headers,
        body: jsonEncode(datos),
      );

      final body = jsonDecode(utf8.decode(res.bodyBytes));
      if (res.statusCode == 201) {
        return {'exito': true, 'data': body};
      } else {
        return {
          'exito': false,
          'codigo': res.statusCode,
          'detail': body['detail'] ?? 'No se pudo crear la actividad.',
        };
      }
    } catch (e) {
      return {'exito': false, 'codigo': 500, 'detail': 'Error de conexión: $e'};
    }
  }

  static Future<Map<String, dynamic>> editarActividadConDetalle(int id, Map<String, dynamic> datos) async {
    try {
      final headers = await _getHeaders();
      final res = await http.put(
        Uri.parse('$baseUrl/actividades/$id/'),
        headers: headers,
        body: jsonEncode(datos),
      );

      final body = jsonDecode(utf8.decode(res.bodyBytes));
      if (res.statusCode == 200) {
        return {'exito': true, 'data': body};
      } else {
        return {
          'exito': false,
          'codigo': res.statusCode,
          'detail': body['detail'] ?? 'No se pudo editar la actividad.',
        };
      }
    } catch (e) {
      return {'exito': false, 'codigo': 500, 'detail': 'Error de conexión: $e'};
    }
  }

  // ==========================================
  // RF-25: AUDITORÍA Y LOGS DEL SISTEMA
  // ==========================================
  static Future<List<dynamic>> getLogsSistema({String? modulo, String? nivel}) async {
    try {
      final headers = await _getHeaders();
      String query = '';
      if (modulo != null && modulo.isNotEmpty) query += 'modulo=$modulo&';
      if (nivel != null && nivel.isNotEmpty) query += 'nivel=$nivel&';

      final url = Uri.parse('$baseUrl/admin/logs/?$query');
      final res = await http.get(url, headers: headers);

      // Logs de diagnóstico en la consola de Flutter
      print('--> [LOGS HTTP] Status: ${res.statusCode}');
      print('--> [LOGS HTTP] Body: ${res.body}');

      if (res.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(res.bodyBytes));

        // Manejo de respuesta paginada de Django REST Framework
        if (decoded is Map<String, dynamic> && decoded.containsKey('results')) {
          return decoded['results'] as List<dynamic>;
        }
        if (decoded is List) {
          return decoded;
        }
      }
      return [];
    } catch (e, stack) {
      print('--> [LOGS ERROR]: $e');
      print(stack);
      return [];
    }
  }

  // ==========================================
  // RF-26: SUSPENSIÓN Y GESTIÓN DE USUARIOS
  // ==========================================
  static Future<dynamic> cambiarEstadoCuenta({
    required int usuarioId,
    required String motivo,
  }) async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('$baseUrl/usuarios/$usuarioId/cambiar-estado-cuenta/');

      final res = await http.post(
        url,
        headers: headers,
        body: jsonEncode({'motivo': motivo}),
      );

      final data = jsonDecode(utf8.decode(res.bodyBytes));
      if (res.statusCode == 200) {
        return {'exito': true, 'data': data};
      }
      return {'exito': false, 'error': data['detail'] ?? 'Error al procesar la solicitud.'};
    } catch (e) {
      return {'exito': false, 'error': 'Error de conexión: $e'};
    }
  }
  // ==========================================
  // RF-27: RESEÑAS GENERALES DE ACTIVIDAD
  // ==========================================
  static Future<dynamic> crearResenaActividad({
    required int actividadId,
    required int puntuacion,
    required String comentario,
  }) async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('$baseUrl/resenas/');

      final res = await http.post(
        url,
        headers: headers,
        body: jsonEncode({
          'actividad': actividadId,
          'puntuacion': puntuacion,
          'comentario': comentario,
        }),
      );

      final data = jsonDecode(utf8.decode(res.bodyBytes));
      if (res.statusCode == 201) {
        return {'exito': true, 'data': data};
      }
      return {'exito': false, 'error': data['detail'] ?? 'No se pudo enviar la reseña.'};
    } catch (e) {
      return {'exito': false, 'error': 'Error de conexión: $e'};
    }
  }

  static Future<dynamic> getMiResenaActividad(int actividadId) async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('$baseUrl/resenas/mi-resena/$actividadId/');
      final res = await http.get(url, headers: headers);

      if (res.statusCode == 200) {
        return jsonDecode(utf8.decode(res.bodyBytes));
      }
      return {'existe': false};
    } catch (_) {
      return {'existe': false};
    }
  }

  static Future<List<dynamic>> getResenasActividad(int actividadId) async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('$baseUrl/resenas/?actividad=$actividadId');
      final res = await http.get(url, headers: headers);

      if (res.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(res.bodyBytes));
        // Soporte para paginación de DRF (results)
        if (decoded is Map<String, dynamic> && decoded.containsKey('results')) {
          return decoded['results'] as List<dynamic>;
        }
        if (decoded is List) return decoded;
      }
      return [];
    } catch (_) {
      return [];
    }
  }
  // ==========================================
  // MOTOR DE MATCHMAKING (PARTIDOS RECOMENDADOS)
  // ==========================================
  static Future<dynamic> getActividadesRecomendadas() async {
    try {
      final headers = await _getHeaders();
      final res = await http.get(
        Uri.parse('$baseUrl/actividades/recomendadas/'),
        headers: headers,
      );

      if (res.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(res.bodyBytes));
        List<dynamic> items = [];
        if (decoded is List) items = decoded;
        if (decoded is Map && decoded.containsKey('results')) {
          items = decoded['results'] as List<dynamic>;
        }
        return {'es_premium': true, 'data': items};
      } else if (res.statusCode == 403) {
        return {'es_premium': false, 'data': []};
      }
      return {'es_premium': true, 'data': []};
    } catch (e) {
      print('Error al obtener partidos recomendados: $e');
      return {'es_premium': true, 'data': []};
    }
  }
}





