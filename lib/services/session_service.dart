import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../data/role.dart';

class SessionService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _sessionsCollection = 'sessions';

  /// Creates a new game session in Firestore
  static Future<void> createSession({
    required String sessionId,
    required int expectedPlayers,
    required Map<String, int> roleCounts,
    required Map<String, bool> gameRules,
    required List<Role> selectedRoles,
  }) async {
    try {
      // Convert roles to a serializable format
      List<Map<String, dynamic>> rolesData = selectedRoles.map((role) => {
        'name': role.name,
        'displayName': role.displayName,
        'team': role.team.toString(),
        'description': role.description,
        'abilities': role.abilities,
        'winCondition': role.winCondition,
      }).toList();

      // Create session document
      await _firestore.collection(_sessionsCollection).doc(sessionId).set({
        'sessionId': sessionId,
        'expectedPlayers': expectedPlayers,
        'roleCounts': roleCounts,
        'gameRules': gameRules,
        'selectedRoles': rolesData,
        'players': [], // Array of player objects
        'status': 'waiting_for_players', // waiting_for_players, in_progress, completed
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'hostId': 'host', // For now, simple host identification
        'currentPlayerCount': 0,
      });

      debugPrint('Session $sessionId created successfully');
    } catch (e) {
      debugPrint('Error creating session: $e');
      rethrow;
    }
  }

  /// Adds a player to the session
  static Future<bool> addPlayer({
    required String sessionId,
    required String playerName,
  }) async {
    try {
      final sessionRef = _firestore.collection(_sessionsCollection).doc(sessionId);

      // Get current session data
      final sessionDoc = await sessionRef.get();
      if (!sessionDoc.exists) {
        throw Exception('Session not found');
      }

      final sessionData = sessionDoc.data()!;
      final List<dynamic> currentPlayers = sessionData['players'] ?? [];
      final int expectedPlayers = sessionData['expectedPlayers'];

      // Check if session is full
      if (currentPlayers.length >= expectedPlayers) {
        return false; // Session is full
      }

      // Check if player name already exists
      bool nameExists = currentPlayers.any((player) => player['name'] == playerName);
      if (nameExists) {
        return false; // Name already taken
      }

      // Add player with current timestamp
      final newPlayer = {
        'name': playerName,
        'joinedAt': DateTime.now().toIso8601String(),
        'role': null, // Will be assigned when game starts
        'isAlive': true,
      };

      // Add the new player to the existing array
      currentPlayers.add(newPlayer);

      await sessionRef.update({
        'players': currentPlayers,
        'currentPlayerCount': currentPlayers.length,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('Player $playerName added to session $sessionId');
      return true;
    } catch (e) {
      debugPrint('Error adding player: $e');
      return false;
    }
  }

  /// Gets real-time updates for a session
  static Stream<DocumentSnapshot> getSessionStream(String sessionId) {
    return _firestore
        .collection(_sessionsCollection)
        .doc(sessionId)
        .snapshots();
  }

  /// Gets session data once
  static Future<Map<String, dynamic>?> getSession(String sessionId) async {
    try {
      final doc = await _firestore
          .collection(_sessionsCollection)
          .doc(sessionId)
          .get();

      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      debugPrint('Error getting session: $e');
      return null;
    }
  }

  /// Updates session status
  static Future<void> updateSessionStatus({
    required String sessionId,
    required String status,
  }) async {
    try {
      await _firestore.collection(_sessionsCollection).doc(sessionId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating session status: $e');
      rethrow;
    }
  }

  /// Starts the game by assigning roles
  static Future<void> startGame(String sessionId) async {
    try {
      final sessionRef = _firestore.collection(_sessionsCollection).doc(sessionId);
      final sessionDoc = await sessionRef.get();

      if (!sessionDoc.exists) {
        throw Exception('Session not found');
      }

      final sessionData = sessionDoc.data()!;
      final List<dynamic> players = sessionData['players'];
      final Map<String, dynamic> roleCounts = Map<String, dynamic>.from(sessionData['roleCounts']);

      // Create role assignment logic
      List<String> rolePool = [];
      roleCounts.forEach((roleName, roleCount) {
        for (int i = 0; i < roleCount; i++) {
          rolePool.add(roleName);
        }
      });

      // Shuffle roles
      rolePool.shuffle();

      // Assign roles to players
      List<Map<String, dynamic>> updatedPlayers = [];
      for (int i = 0; i < players.length; i++) {
        final player = Map<String, dynamic>.from(players[i]);
        player['role'] = i < rolePool.length ? rolePool[i] : 'citizen';
        updatedPlayers.add(player);
      }

      // Update session with assigned roles and new status
      await sessionRef.update({
        'players': updatedPlayers,
        'status': 'in_progress',
        'gameStartedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('Game started for session $sessionId');
    } catch (e) {
      debugPrint('Error starting game: $e');
      rethrow;
    }
  }

  /// Ends the game and cleans up session
  static Future<void> endGame(String sessionId) async {
    try {
      await _firestore.collection(_sessionsCollection).doc(sessionId).update({
        'status': 'aborted',
        'gameEndedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('Game aborted for session $sessionId');
    } catch (e) {
      debugPrint('Error ending game: $e');
      rethrow;
    }
  }
  /// Updates players after night resolution
  static Future<void> updatePlayersAfterNight({
    required String sessionId,
    required List<Map<String, dynamic>> updatedPlayers,
    required int nightNumber,
  }) async {
    try {
      await _firestore.collection(_sessionsCollection).doc(sessionId).update({
        'players': updatedPlayers,
        'lastNightProcessed': nightNumber,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('Night $nightNumber results updated in Firebase');
    } catch (e) {
      debugPrint('Error updating night results: $e');
      rethrow;
    }
  }
}