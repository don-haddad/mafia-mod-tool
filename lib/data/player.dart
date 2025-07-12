class Player {
  final String id;
  final String name;
  final String role;
  bool isAlive;
  bool hasBeenSaved; // For doctor tracking

  Player({
    required this.id,
    required this.name,
    required this.role,
    this.isAlive = true,
    this.hasBeenSaved = false,
  });
}