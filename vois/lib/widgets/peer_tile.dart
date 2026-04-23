import 'package:flutter/material.dart';

import '../models/peer.dart';

class PeerTile extends StatelessWidget {
  const PeerTile({super.key, required this.peer});

  final Peer peer;

  @override
  Widget build(BuildContext context) {
    final accent =
        peer.local ? const Color(0xFF0096DE) : const Color(0xFF00AFF0);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFDCEFFC)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1200AFF0),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  peer.local
                      ? Icons.waving_hand_rounded
                      : Icons.graphic_eq_rounded,
                  color: accent,
                ),
              ),
              const Spacer(),
              Icon(
                peer.muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                color: peer.muted ? const Color(0xFF8B2E4F) : accent,
              ),
            ],
          ),
          const Spacer(),
          Text(
            peer.local ? '${peer.name} (you)' : peer.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF173A63),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            peer.local
                ? 'Your microphone is ${peer.muted ? 'muted' : 'live'}.'
                : 'Connected to the room.',
            style: const TextStyle(fontSize: 14, color: Color(0xFF65829D)),
          ),
        ],
      ),
    );
  }
}
