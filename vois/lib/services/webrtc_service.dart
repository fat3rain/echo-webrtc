import 'package:flutter_webrtc/flutter_webrtc.dart';

class WebRTCService {
  RTCPeerConnection? peerConnection;
  MediaStream? localStream;

  final config = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ],
  };

  Future<void> init() async {
    localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': false,
    });
  }

  Future<RTCPeerConnection> createPeerConnectionForServer(
    Function(RTCIceCandidate) onIce,
    Function(MediaStream) onTrack,
  ) async {
    final pc = await createPeerConnection(config);

    localStream!.getTracks().forEach((track) {
      pc.addTrack(track, localStream!);
    });

    pc.onIceCandidate = onIce;

    pc.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        onTrack(event.streams[0]);
      }
    };

    peerConnection = pc;
    return pc;
  }

  Future<void> disposeAll() async {
    await peerConnection?.close();
    peerConnection = null;

    for (final track
        in localStream?.getTracks() ?? const <MediaStreamTrack>[]) {
      track.stop();
    }
    await localStream?.dispose();
    localStream = null;
  }
}
