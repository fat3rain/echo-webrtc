import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../models/peer.dart';
import '../services/websocket_service.dart';
import '../services/webrtc_service.dart';

class RoomController extends ChangeNotifier {
  RoomController({
    required this.baseUri,
    required this.roomId,
    required this.token,
    required this.userId,
    required this.displayName,
  });

  final Uri baseUri;
  final String roomId;
  final String token;
  final String userId;
  final String displayName;

  final WebSocketService ws = WebSocketService();
  final WebRTCService rtc = WebRTCService();
  final Map<String, Peer> peers = {};
  final List<String> logs = [];

  StreamSubscription? _subscription;
  final List<Map<String, dynamic>> _pendingCandidates = [];
  bool muted = false;
  bool connected = false;
  bool connecting = false;
  bool _joinSent = false;
  String status = 'Подключаемся...';

  Future<void> connect() async {
    if (connecting || connected) {
      return;
    }

    try {
      connecting = true;
      _setStatus('Запрашиваем доступ к микрофону...');

      await rtc.init();
      _log('Доступ к микрофону получен.');

      peers['local'] = Peer(
        id: 'local',
        name: displayName,
        local: true,
        muted: muted,
      );
      notifyListeners();

      final pc = await rtc.createPeerConnectionForServer((candidate) {
        final candidateValue = candidate.candidate;
        if (candidateValue == null || candidateValue.isEmpty) {
          return;
        }

        final payload = <String, dynamic>{
          'type': 'candidate',
          'candidate': candidate.toMap(),
        };

        if (_joinSent) {
          try {
            ws.send(payload);
            _log('ICE-кандидат отправлен.');
          } catch (error, stackTrace) {
            _handleFailure('Не удалось отправить ICE-кандидат', error, stackTrace);
          }
        } else {
          _pendingCandidates.add(payload);
          _log('ICE-кандидат отложен до отправки join.');
        }
      }, _handleRemoteStream);

      _setStatus('Создаём WebRTC offer...');
      final offer = await pc.createOffer();
      await pc.setLocalDescription(offer);
      _log('Локальный offer создан.');

      final wsUri = _buildWebSocketUri(baseUri);
      _setStatus('Подключаемся к сигнальному серверу...');
      await ws.connect(wsUri);
      _log('WebSocket подключён: $wsUri');

      _subscription = ws.stream.listen(
        (event) async => _handleSignal(event.toString()),
        onDone: () {
          connected = false;
          connecting = false;
          _setStatus('Соединение с сигнальным сервером закрыто.');
        },
        onError: (error, stackTrace) {
          _handleFailure('Ошибка сокета', error, stackTrace);
        },
      );

      ws.send({
        'type': 'join',
        'room': roomId,
        'sdp': offer.sdp,
        'sdpType': offer.type,
        'token': token,
      });
      _joinSent = true;
      _log('Сообщение join отправлено для комнаты "$roomId".');

      for (final candidate in _pendingCandidates) {
        ws.send(candidate);
      }
      if (_pendingCandidates.isNotEmpty) {
        _log('Отправлены отложенные ICE-кандидаты: ${_pendingCandidates.length}.');
      }
      _pendingCandidates.clear();

      connected = true;
      connecting = false;
      _setStatus('Входим в комнату "$roomId"...');
    } catch (error, stackTrace) {
      await disposeAll();
      _handleFailure('Ошибка подключения', error, stackTrace);
    }
  }

  Future<void> _handleSignal(String rawEvent) async {
    try {
      final data = jsonDecode(rawEvent) as Map<String, dynamic>;
      final type = data['type'] as String?;
      final pc = rtc.peerConnection;

      _log('Получено событие сигналинга: ${type ?? 'unknown'}');

      switch (type) {
        case 'participants':
          final participants = data['participants'] as List<dynamic>? ?? [];
          final activeIds = <String>{};
          for (final participant in participants) {
            if (participant is! Map<String, dynamic>) {
              continue;
            }

            final id = participant['id'] as String?;
            final name = participant['displayName'] as String?;
            if (id == null || name == null) {
              continue;
            }

            activeIds.add(id);

            if (id == userId) {
              continue;
            }

            final existing = peers[id];
            if (existing != null) {
              existing.name = name;
            } else {
              peers[id] = Peer(id: id, name: name);
            }
          }

          peers.removeWhere((id, peer) => !peer.local && !activeIds.contains(id));
          break;

        case 'answer':
          if (pc == null) {
            return;
          }
          await pc.setRemoteDescription(
            RTCSessionDescription(
              data['sdp'] as String,
              data['sdpType'] as String,
            ),
          );
          _setStatus('Подключение к комнате "$roomId" установлено.');
          break;

        case 'offer':
          if (pc == null) {
            return;
          }
          await pc.setRemoteDescription(
            RTCSessionDescription(
              data['sdp'] as String,
              data['sdpType'] as String,
            ),
          );
          final answer = await pc.createAnswer();
          await pc.setLocalDescription(answer);
          ws.send({
            'type': 'answer',
            'sdp': answer.sdp,
            'sdpType': answer.type,
          });
          _setStatus('Медиасессия обновлена.');
          break;

        case 'candidate':
        case 'candidateFromServer':
          final rawCandidate = data['candidate'];
          if (pc == null || rawCandidate is! Map<String, dynamic>) {
            return;
          }
          await pc.addCandidate(
            RTCIceCandidate(
              rawCandidate['candidate'] as String?,
              rawCandidate['sdpMid'] as String?,
              rawCandidate['sdpMLineIndex'] as int?,
            ),
          );
          break;

        default:
          _log('Неизвестное событие проигнорировано.');
          return;
      }

      notifyListeners();
    } catch (error, stackTrace) {
      _handleFailure('Ошибка обработки сигнального сообщения', error, stackTrace);
    }
  }

  void _handleRemoteStream(MediaStream stream) {
    _setStatus('Получаем удалённое аудио.');
  }

  void toggleMute() {
    muted = !muted;

    for (final track in rtc.localStream?.getAudioTracks() ?? const <MediaStreamTrack>[]) {
      track.enabled = !muted;
    }

    peers['local']?.muted = muted;
    notifyListeners();
  }

  Future<void> disposeAll() async {
    await _subscription?.cancel();
    _subscription = null;
    ws.dispose();
    await rtc.disposeAll();
    connected = false;
    connecting = false;
    _joinSent = false;
    _pendingCandidates.clear();
  }

  void _setStatus(String value) {
    status = value;
    _log(value);
    notifyListeners();
  }

  void _log(String message) {
    final line = '${DateTime.now().toIso8601String()}  $message';
    logs.insert(0, line);
    if (logs.length > 50) {
      logs.removeLast();
    }
    developer.log(message, name: 'RoomController');
  }

  void _handleFailure(String context, Object error, StackTrace stackTrace) {
    connected = false;
    connecting = false;
    status = '$context: $error';
    _log('$context: $error');
    developer.log(
      context,
      name: 'RoomController',
      error: error,
      stackTrace: stackTrace,
    );
    notifyListeners();
  }

  Uri _buildWebSocketUri(Uri uri) {
    final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
    return uri.replace(
      scheme: scheme,
      path: '/ws',
      queryParameters: null,
      fragment: null,
    );
  }
}
