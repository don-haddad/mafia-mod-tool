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

  /// Updates players after night resolution (in active_sessions)
  static Future<void> updatePlayersAfterNight({
    required String sessionId,
    required List<Map<String, dynamic>> updatedPlayers,
    required int nightNumber,
  }) async {
    try {
      await _firestore.collection(_activeSessionsCollection).doc(sessionId).update({
        'players': updatedPlayers,
        'lastNightProcessed': nightNumber,
        'updatedAt': FieldValue.serverTimestamp(),
      });

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

  // ====================
  // TEST METHODS
  // ====================

  /// Test method to verify the new collection structure works
  static Future<bool> testNewCollectionStructure() async {
    try {
      debugPrint('🧪 Starting collection structure test...');

      final testSessionId = 'TEST_${DateTime.now().millisecondsSinceEpoch}';

      // Test 1: Create a session
      debugPrint('📝 Test 1: Creating test session...');
      await createSession(
        sessionId: testSessionId,
        expectedPlayers: 2,
        roleCounts: {'mafia': 1, 'citizen': 1},
        gameRules: {'Mafia Night Skip': false},
        selectedRoles: [
          RoleManager.getRoleByName('mafia')!,
          RoleManager.getRoleByName('citizen')!,
        ],
      );
      debugPrint('✅ Test 1 passed: Session created in active_sessions');
      debugPrint('🔍 CHECK FIREBASE: You should now see "active_sessions" collection with document: $testSessionId');

      // Wait a moment for Firebase Console to update
      await Future.delayed(Duration(seconds: 2));

      // Test 2: Add players
      debugPrint('📝 Test 2: Adding test players...');
      bool player1Added = await addPlayer(sessionId: testSessionId, playerName: 'TestPlayer1');
      bool player2Added = await addPlayer(sessionId: testSessionId, playerName: 'TestPlayer2');

      if (!player1Added || !player2Added) {
        throw Exception('Failed to add test players');
      }
      debugPrint('✅ Test 2 passed: Players added to session');
      debugPrint('🔍 CHECK FIREBASE: The session document should now have 2 players in the "players" array');

      // Wait a moment for Firebase Console to update
      await Future.delayed(Duration(seconds: 2));

      // Test 3: Start game
      debugPrint('📝 Test 3: Starting test game...');
      await startGame(testSessionId);
      debugPrint('✅ Test 3 passed: Game started, roles assigned');
      debugPrint('🔍 CHECK FIREBASE: The session status should now be "in_progress" and players should have roles assigned');

      // Wait a moment for Firebase Console to update
      await Future.delayed(Duration(seconds: 3));

      // Test 4: Complete game and test collection movement
      debugPrint('📝 Test 4: Completing test game...');
      await completeGame(
        sessionId: testSessionId,
        winningTeam: 'town',
        winCondition: 'Test completion',
      );
      debugPrint('✅ Test 4 passed: Game completed and moved to collections');
      debugPrint('🔍 CHECK FIREBASE: Session should be GONE from "active_sessions" and NOW appear in:');
      debugPrint('   - "completed_sessions" collection (full game data)');
      debugPrint('   - "session_analytics" collection (minimal analytics data)');

      // Test 5: Verify data is in correct collections
      debugPrint('📝 Test 5: Verifying data placement...');

      // Check active_sessions (should be empty)
      final activeSession = await getActiveSession(testSessionId);
      if (activeSession != null) {
        throw Exception('Session still exists in active_sessions');
      }

      // Check completed_sessions (should exist)
      final completedDoc = await _firestore
          .collection(_completedSessionsCollection)
          .doc(testSessionId)
          .get();
      if (!completedDoc.exists) {
        throw Exception('Session not found in completed_sessions');
      }

      // Check analytics (should exist)
      final analyticsDoc = await _firestore
          .collection(_analyticsCollection)
          .doc(testSessionId)
          .get();
      if (!analyticsDoc.exists) {
        throw Exception('Session not found in session_analytics');
      }

      debugPrint('✅ Test 5 passed: Data correctly placed in collections');

      // DON'T clean up test data so you can see it in Firebase Console
      debugPrint('📝 Test 6: LEAVING test data for inspection...');
      debugPrint('🔍 FINAL CHECK: Go to Firebase Console now and you should see:');
      debugPrint('   - "completed_sessions" collection with document: $testSessionId');
      debugPrint('   - "session_analytics" collection with document: $testSessionId');
      debugPrint('   - "active_sessions" collection should be empty (or not exist if this was the only test)');

      debugPrint('🎉 All tests passed! New collection structure is working correctly.');
      debugPrint('💡 You can manually delete the test documents from Firebase Console when done inspecting.');
      return true;

    } catch (e) {
      debugPrint('❌ Test failed: $e');
      return false;
    }
  }

  /// Test method for abort functionality
  static Future<bool> testAbortFunctionality() async {
    try {
      debugPrint('🧪 Starting abort functionality test...');

      final testSessionId = 'ABORT_TEST_${DateTime.now().millisecondsSinceEpoch}';

      // Create a session
      await createSession(
        sessionId: testSessionId,
        expectedPlayers: 2,
        roleCounts: {'mafia': 1, 'citizen': 1},
        gameRules: {},
        selectedRoles: [
          RoleManager.getRoleByName('mafia')!,
          RoleManager.getRoleByName('citizen')!,
        ],
      );

      // Verify it exists
      final sessionBeforeAbort = await getActiveSession(testSessionId);
      if (sessionBeforeAbort == null) {
        throw Exception('Test session was not created');
      }

      // Abort the session
      await abortGame(testSessionId);

      // Verify it's gone
      final sessionAfterAbort = await getActiveSession(testSessionId);
      if (sessionAfterAbort != null) {
        throw Exception('Session was not deleted after abort');
      }

      debugPrint('✅ Abort functionality test passed!');
      return true;

    } catch (e) {
      debugPrint('❌ Abort test failed: $e');
      return false;
    }
  }

  /// Creates a test session that stays in active_sessions for inspection
  static Future<String> createTestActiveSession() async {
    try {
      final testSessionId = 'ACTIVE_TEST_${DateTime.now().millisecondsSinceEpoch}';

      await createSession(
        sessionId: testSessionId,
        expectedPlayers: 4,
        roleCounts: {'mafia': 2, 'citizen': 1, 'detective': 1},
        gameRules: {'Mafia Night Skip': true, 'Reveal Roles on Death': false},
        selectedRoles: [
          RoleManager.getRoleByName('mafia')!,
          RoleManager.getRoleByName('citizen')!,
          RoleManager.getRoleByName('detective')!,
        ],
      );

      // Add some test players
      await addPlayer(sessionId: testSessionId, playerName: 'Alice');
      await addPlayer(sessionId: testSessionId, playerName: 'Bob');

      debugPrint('✅ Created test active session: $testSessionId');
      debugPrint('🔍 CHECK FIREBASE: You should see this in "active_sessions" collection');

      return testSessionId;
    } catch (e) {
      debugPrint('❌ Failed to create test active session: $e');
      rethrow;
    }
  }
}