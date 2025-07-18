import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../data/role.dart';

class SessionServiceV2 {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection names
  static const String _activeSessionsCollection = 'active_sessions';
  static const String _completedSessionsCollection = 'completed_sessions';
  static const String _analyticsCollection = 'session_analytics';

  /// Creates a new game session in the active_sessions collection
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

      // Create session document in active_sessions
      await _firestore.collection(_activeSessionsCollection).doc(sessionId).set({
        'sessionId': sessionId,
        'expectedPlayers': expectedPlayers,
        'roleCounts': roleCounts,
        'gameRules': gameRules,
        'selectedRoles': rolesData,
        'players': [], // Array of player objects
        'status': 'waiting_for_players', // waiting_for_players, in_progress
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'hostId': 'host', // For now, simple host identification
        'currentPlayerCount': 0,
        'mafiaExtraKills': 0, // Mafia wife Mechanics
        'vigilanteUsed': false, // Vigilante ability tracking
      });

      debugPrint('Session $sessionId created successfully in active_sessions');
    } catch (e) {
      debugPrint('Error creating session: $e');
      rethrow;
    }
  }

  /// Adds a player to an active session
  static Future<bool> addPlayer({
    required String sessionId,
    required String playerName,
  }) async {
    try {
      final sessionRef = _firestore.collection(_activeSessionsCollection).doc(sessionId);

      // Get current session data
      final sessionDoc = await sessionRef.get();
      if (!sessionDoc.exists) {
        throw Exception('Active session not found');
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

      debugPrint('Player $playerName added to active session $sessionId');
      return true;
    } catch (e) {
      debugPrint('Error adding player: $e');
      return false;
    }
  }

  /// Gets real-time updates for an active session
  static Stream<DocumentSnapshot> getActiveSessionStream(String sessionId) {
    return _firestore
        .collection(_activeSessionsCollection)
        .doc(sessionId)
        .snapshots();
  }

  /// Gets active session data once
  static Future<Map<String, dynamic>?> getActiveSession(String sessionId) async {
    try {
      final doc = await _firestore
          .collection(_activeSessionsCollection)
          .doc(sessionId)
          .get();

      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      debugPrint('Error getting active session: $e');
      return null;
    }
  }

  /// Updates session status (only for active sessions)
  static Future<void> updateActiveSessionStatus({
    required String sessionId,
    required String status,
  }) async {
    try {
      await _firestore.collection(_activeSessionsCollection).doc(sessionId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating active session status: $e');
      rethrow;
    }
  }

  /// Starts the game by assigning roles (in active_sessions)
  static Future<void> startGame(String sessionId) async {
    try {
      final sessionRef = _firestore.collection(_activeSessionsCollection).doc(sessionId);
      final sessionDoc = await sessionRef.get();

      if (!sessionDoc.exists) {
        throw Exception('Active session not found');
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

      debugPrint('Game started for active session $sessionId');
    } catch (e) {
      debugPrint('Error starting game: $e');
      rethrow;
    }
  }

  /// Updates players after night resolution and saves night targets for next night
  static Future<void> updatePlayersAfterNight({
    required String sessionId,
    required List<Map<String, dynamic>> updatedPlayers,
    required int nightNumber,
    Map<String, String?>? nightTargets, // NEW: Add night targets parameter
  }) async {
    try {
      Map<String, dynamic> updateData = {
        'players': updatedPlayers,
        'lastNightProcessed': nightNumber,
        'updatedAt': FieldValue.serverTimestamp(),
        'mafiaExtraKills': 0, // Reset Mafia Wife bonus after use
      };

      // Save night targets for next night's restrictions
      if (nightTargets != null) {
        // Convert night targets to a format suitable for restrictions
        Map<String, String> previousNightTargets = {};

        nightTargets.forEach((stageKey, target) {
          if (target != null && target != 'SKIP_NIGHT') {
            // Map stage keys to target tracking keys
            String? targetKey = _mapStageKeyToTargetKey(stageKey);
            if (targetKey != null) {
              previousNightTargets[targetKey] = target;
            }
          }
        });

        updateData['previousNightTargets'] = previousNightTargets;
        updateData['previousNightTargets_nightNumber'] = nightNumber;
      }

      await _firestore.collection(_activeSessionsCollection).doc(sessionId).update(updateData);

      debugPrint('Night $nightNumber results updated in active session');
    } catch (e) {
      debugPrint('Error updating night results: $e');
      rethrow;
    }
  }

  /// Completes a game session and moves it to completed_sessions + analytics
  static Future<void> completeGame({
    required String sessionId,
    required String winningTeam, // 'town', 'scum', 'independent', or 'draw'
    String? winCondition, // How the game was won
  }) async {
    try {
      // Get the active session data
      final activeSessionDoc = await _firestore
          .collection(_activeSessionsCollection)
          .doc(sessionId)
          .get();

      if (!activeSessionDoc.exists) {
        throw Exception('Active session not found');
      }

      final sessionData = activeSessionDoc.data()!;
      final gameStartedAt = sessionData['gameStartedAt'] as Timestamp?;
      final completedAt = Timestamp.now();

      // Calculate game duration in minutes
      int? gameDurationMinutes;
      if (gameStartedAt != null) {
        final duration = completedAt.toDate().difference(gameStartedAt.toDate());
        gameDurationMinutes = duration.inMinutes;
      }

      // Prepare completed session data (full data for 90 days)
      final completedSessionData = Map<String, dynamic>.from(sessionData);
      completedSessionData.addAll({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
        'winningTeam': winningTeam,
        'winCondition': winCondition,
        'gameDurationMinutes': gameDurationMinutes,
      });

      // Prepare analytics data (minimal permanent data)
      final analyticsData = {
        'sessionId': sessionId,
        'gameDurationMinutes': gameDurationMinutes,
        'playerCount': sessionData['currentPlayerCount'] ?? 0,
        'rolesUsed': sessionData['roleCounts'] ?? {},
        'gameRules': sessionData['gameRules'] ?? {},
        'winningTeam': winningTeam,
        'winCondition': winCondition,
        'gameStartedAt': gameStartedAt,
        'completedAt': FieldValue.serverTimestamp(),
        'createdAt': sessionData['createdAt'],
      };

      // Use batch to ensure all operations succeed or fail together
      final batch = _firestore.batch();

      // 1. Add to completed_sessions
      final completedSessionRef = _firestore
          .collection(_completedSessionsCollection)
          .doc(sessionId);
      batch.set(completedSessionRef, completedSessionData);

      // 2. Add to analytics
      final analyticsRef = _firestore
          .collection(_analyticsCollection)
          .doc(sessionId);
      batch.set(analyticsRef, analyticsData);

      // 3. Delete from active_sessions
      final activeSessionRef = _firestore
          .collection(_activeSessionsCollection)
          .doc(sessionId);
      batch.delete(activeSessionRef);

      // Execute all operations
      await batch.commit();

      debugPrint('Game completed and moved to completed_sessions + analytics');
    } catch (e) {
      debugPrint('Error completing game: $e');
      rethrow;
    }
  }

  /// Aborts a game session (deletes immediately from active_sessions)
  static Future<void> abortGame(String sessionId) async {
    try {
      await _firestore.collection(_activeSessionsCollection).doc(sessionId).delete();
      debugPrint('Game aborted and deleted from active_sessions');
    } catch (e) {
      debugPrint('Error aborting game: $e');
      rethrow;
    }
  }

  /// Gets all active sessions (for admin/debugging purposes)
  static Future<List<Map<String, dynamic>>> getAllActiveSessions() async {
    try {
      final querySnapshot = await _firestore
          .collection(_activeSessionsCollection)
          .get();

      return querySnapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
    } catch (e) {
      debugPrint('Error getting all active sessions: $e');
      return [];
    }
  }

  /// Cleanup stale sessions (sessions not updated for 24 hours)
  /// This method can be called manually or by Cloud Functions
  static Future<void> cleanupStaleSessions() async {
    try {
      final cutoffTime = Timestamp.fromDate(
          DateTime.now().subtract(Duration(hours: 24))
      );

      final staleSessionsQuery = await _firestore
          .collection(_activeSessionsCollection)
          .where('updatedAt', isLessThan: cutoffTime)
          .get();

      final batch = _firestore.batch();
      for (final doc in staleSessionsQuery.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      debugPrint('Cleaned up ${staleSessionsQuery.docs.length} stale sessions');
    } catch (e) {
      debugPrint('Error cleaning up stale sessions: $e');
      rethrow;
    }
  }

  /// Cleanup completed sessions older than specified days
  /// Call this manually when needed
  static Future<int> cleanupOldCompletedSessions({int daysOld = 90}) async {
    try {
      final cutoffTime = Timestamp.fromDate(
          DateTime.now().subtract(Duration(days: daysOld))
      );

      final oldSessionsQuery = await _firestore
          .collection(_completedSessionsCollection)
          .where('completedAt', isLessThan: cutoffTime)
          .get();

      final batch = _firestore.batch();
      for (final doc in oldSessionsQuery.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      debugPrint('Cleaned up ${oldSessionsQuery.docs.length} old completed sessions');
      debugPrint('Analytics data preserved in session_analytics');

      return oldSessionsQuery.docs.length;
    } catch (e) {
      debugPrint('Error cleaning up old completed sessions: $e');
      rethrow;
    }
  }

  /// Get cleanup statistics
  static Future<Map<String, int>> getCleanupStats() async {
    try {
      final activeSnapshot = await _firestore.collection(_activeSessionsCollection).get();
      final completedSnapshot = await _firestore.collection(_completedSessionsCollection).get();
      final analyticsSnapshot = await _firestore.collection(_analyticsCollection).get();

      // Count stale sessions (24+ hours old)
      final cutoffTime = Timestamp.fromDate(
          DateTime.now().subtract(Duration(hours: 24))
      );
      final staleSessionsQuery = await _firestore
          .collection(_activeSessionsCollection)
          .where('updatedAt', isLessThan: cutoffTime)
          .get();

      return {
        'activeSessions': activeSnapshot.docs.length,
        'staleSessions': staleSessionsQuery.docs.length,
        'completedSessions': completedSnapshot.docs.length,
        'analyticsRecords': analyticsSnapshot.docs.length,
      };
    } catch (e) {
      debugPrint('Error getting cleanup stats: $e');
      return {
        'activeSessions': 0,
        'staleSessions': 0,
        'completedSessions': 0,
        'analyticsRecords': 0
      };
    }
  }

  /// Emergency cleanup - delete ALL sessions (for testing only)
  /// WARNING: This deletes everything!
  static Future<Map<String, int>> emergencyCleanupAll() async {
    try {
      // Get all documents first
      final activeSnapshot = await _firestore.collection(_activeSessionsCollection).get();
      final completedSnapshot = await _firestore.collection(_completedSessionsCollection).get();

      // Delete active sessions
      final activeBatch = _firestore.batch();
      for (final doc in activeSnapshot.docs) {
        activeBatch.delete(doc.reference);
      }
      await activeBatch.commit();

      // Delete completed sessions
      final completedBatch = _firestore.batch();
      for (final doc in completedSnapshot.docs) {
        completedBatch.delete(doc.reference);
      }
      await completedBatch.commit();

      debugPrint('EMERGENCY CLEANUP: Deleted all sessions');
      debugPrint('Analytics data preserved');

      return {
        'deletedActive': activeSnapshot.docs.length,
        'deletedCompleted': completedSnapshot.docs.length,
      };
    } catch (e) {
      debugPrint('Error in emergency cleanup: $e');
      rethrow;
    }
  }
  /// Updates players nomination status after day phase (in active_sessions)
  static Future<void> updatePlayersNomination({
    required String sessionId,
    required List<Map<String, dynamic>> updatedPlayers,
    required int dayNumber,
  }) async {
    try {
      await _firestore.collection(_activeSessionsCollection).doc(sessionId).update({
        'players': updatedPlayers,
        'lastDayProcessed': dayNumber,
        'phase': 'vote_phase', // Track current game phase
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('Day $dayNumber nomination results updated in active session');
    } catch (e) {
      debugPrint('Error updating nomination results: $e');
      rethrow;
    }
  }

  /// Updates players after voting phase and elimination (in active_sessions)
  static Future<void> updatePlayersAfterDay({
    required String sessionId,
    required List<Map<String, dynamic>> updatedPlayers,
    required int dayNumber,
    String? eliminatedPlayer,
    bool mafiaWifeEliminated = false,
  }) async {
    try {
      Map<String, dynamic> updateData = {
        'players': updatedPlayers,
        'lastDayProcessed': dayNumber,
        'phase': 'night_phase', // Moving to next night phase
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Add elimination info if a player was eliminated
      if (eliminatedPlayer != null) {
        updateData['lastEliminatedPlayer'] = eliminatedPlayer;
        updateData['lastEliminatedOn'] = 'day_$dayNumber';
      }

      // Set Mafia Wife bonus if she was eliminated
      if (mafiaWifeEliminated) {
        updateData['mafiaExtraKills'] = 1;
        debugPrint('Mafia Wife bonus activated for next night');
      }

      await _firestore.collection(_activeSessionsCollection).doc(sessionId).update(updateData);

      debugPrint('Day $dayNumber voting results updated in active session');
    } catch (e) {
      debugPrint('Error updating day results: $e');
      rethrow;
    }
  }

  /// Gets the current game phase and related data
  static Future<Map<String, dynamic>?> getGamePhaseData(String sessionId) async {
    try {
      final sessionData = await getActiveSession(sessionId);
      if (sessionData == null) return null;

      return {
        'phase': sessionData['phase'] ?? 'night_phase',
        'lastNightProcessed': sessionData['lastNightProcessed'] ?? 0,
        'lastDayProcessed': sessionData['lastDayProcessed'] ?? 0,
        'selectedRoles': sessionData['selectedRoles'] ?? [],
        'gameRules': sessionData['gameRules'] ?? {},
      };
    } catch (e) {
      debugPrint('Error getting game phase data: $e');
      return null;
    }
  }
  /// Updates session after vigilante action
  static Future<void> updateVigilanteAction({
    required String sessionId,
    required List<Map<String, dynamic>> updatedPlayers,
    required int dayNumber,
    required String targetPlayer,
    bool vigilanteDied = false,
  }) async {
    try {
      Map<String, dynamic> updateData = {
        'players': updatedPlayers,
        'vigilanteUsed': true, // Mark vigilante ability as used
        'lastVigilanteAction': {
          'dayNumber': dayNumber,
          'targetPlayer': targetPlayer,
          'vigilanteDied': vigilanteDied,
          'timestamp': FieldValue.serverTimestamp(),
        },
        'phase': 'day_phase', // Reset to day phase
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection(_activeSessionsCollection).doc(sessionId).update(updateData);

      debugPrint('Vigilante action processed for session $sessionId');
    } catch (e) {
      debugPrint('Error updating vigilante action: $e');
      rethrow;
    }
  }

  /// Resets day phase after vigilante action (clears nominations)
  static Future<void> resetDayPhaseAfterVigilante({
    required String sessionId,
    required List<Map<String, dynamic>> updatedPlayers,
    required int dayNumber,
  }) async {
    try {
      // Clear all nomination flags from players
      List<Map<String, dynamic>> playersWithClearedNominations = updatedPlayers.map((player) {
        Map<String, dynamic> updatedPlayer = Map.from(player);
        updatedPlayer['isNominated'] = false; // Clear nomination status
        return updatedPlayer;
      }).toList();

      Map<String, dynamic> updateData = {
        'players': playersWithClearedNominations,
        'phase': 'day_phase', // Ensure we're in day phase
        'lastDayProcessed': dayNumber - 1, // Reset to previous day to restart current day
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection(_activeSessionsCollection).doc(sessionId).update(updateData);

      debugPrint('Day phase reset after vigilante action for session $sessionId');
    } catch (e) {
      debugPrint('Error resetting day phase after vigilante: $e');
      rethrow;
    }
  }

  /// Checks if vigilante has used their ability
  static Future<bool> hasVigilanteUsedAbility(String sessionId) async {
    try {
      final sessionData = await getActiveSession(sessionId);
      if (sessionData == null) return false;

      return sessionData['vigilanteUsed'] ?? false;
    } catch (e) {
      debugPrint('Error checking vigilante ability status: $e');
      return false; // Default to false if error
    }
  }

  /// Gets vigilante player from session (if alive and exists)
  static Future<Map<String, dynamic>?> getVigilantePlayer(String sessionId) async {
    try {
      final sessionData = await getActiveSession(sessionId);
      if (sessionData == null) return null;

      final players = List<Map<String, dynamic>>.from(sessionData['players'] ?? []);

      // Find alive vigilante player
      for (final player in players) {
        if ((player['role'] ?? '') == 'vigilante' && (player['isAlive'] ?? false)) {
          return player;
        }
      }

      return null; // No alive vigilante found
    } catch (e) {
      debugPrint('Error getting vigilante player: $e');
      return null;
    }
  }

  /// Helper method to map stage keys to target tracking keys
  static String? _mapStageKeyToTargetKey(String stageKey) {
    switch (stageKey) {
      case 'mafia_eliminate':
        return 'mafia_target';
      case 'detective_action':
        return 'detective_target';
      case 'doctor_action':
        return 'doctor_target';
      case 'lawyer_defend':
        return 'lawyer_target';
      case 'serial_killer_action':
        return 'serial_killer_target';
      case 'interrogator_action':
        return 'interrogator_target';
      default:
      // For custom roles, extract role name from stage key
        if (stageKey.endsWith('_action')) {
          String roleName = stageKey.replaceAll('_action', '');
          return '${roleName}_target';
        }
        return null;
    }
  }

  /// Gets previous night targets for the current night
  static Future<Map<String, dynamic>?> getPreviousNightTargets(String sessionId) async {
    try {
      final sessionData = await getActiveSession(sessionId);
      if (sessionData == null) return null;

      return sessionData['previousNightTargets'] as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('Error getting previous night targets: $e');
      return null;
    }
  }
}