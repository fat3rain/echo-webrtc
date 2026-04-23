import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../controllers/room_controller.dart';
import '../widgets/peer_tile.dart';

class RoomScreen extends StatelessWidget {
  const RoomScreen({
    super.key,
    required this.baseUri,
    required this.roomId,
    required this.roomName,
    required this.token,
    required this.userId,
    required this.displayName,
  });

  final Uri baseUri;
  final String roomId;
  final String roomName;
  final String token;
  final String userId;
  final String displayName;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RoomController(
        baseUri: baseUri,
        roomId: roomId,
        token: token,
        userId: userId,
        displayName: displayName,
      )..connect(),
      child: _RoomView(roomName: roomName),
    );
  }
}

class _RoomView extends StatelessWidget {
  const _RoomView({required this.roomName});

  final String roomName;

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await context.read<RoomController>().disposeAll();
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(roomName),
          leading: IconButton(
            onPressed: () async {
              await context.read<RoomController>().disposeAll();
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: Consumer<RoomController>(
          builder: (context, controller, _) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF00AFF0), Color(0xFF57CCFF)],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Комната: $roomName',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'ID: ${controller.roomId}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: Colors.white.withValues(alpha: 0.92),
                                    ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Скопировать ID комнаты',
                              onPressed: () async {
                                await Clipboard.setData(
                                  ClipboardData(text: controller.roomId),
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('ID комнаты скопирован'),
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.copy_rounded, color: Colors.white),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          controller.status,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth > 860
                            ? 3
                            : constraints.maxWidth > 560
                                ? 2
                                : 1;

                        return GridView.count(
                          crossAxisCount: columns,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: 1.25,
                          children: controller.peers.values
                              .map((peer) => PeerTile(peer: peer))
                              .toList(),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: controller.toggleMute,
                          icon: Icon(
                            controller.muted ? Icons.mic_off : Icons.mic,
                          ),
                          label: Text(
                            controller.muted
                                ? 'Включить микрофон'
                                : 'Выключить микрофон',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            await controller.disposeAll();
                            if (context.mounted) {
                              Navigator.pop(context);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFBEEBFF),
                            foregroundColor: const Color(0xFF17608E),
                          ),
                          icon: const Icon(Icons.call_end),
                          label: const Text('Вернуться к комнатам'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
