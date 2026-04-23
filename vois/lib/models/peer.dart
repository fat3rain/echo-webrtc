class Peer {
  final String id;
  String name;
  final bool local;
  bool muted;

  Peer({
    required this.id,
    required this.name,
    this.local = false,
    this.muted = false,
  });
}
