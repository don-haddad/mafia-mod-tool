import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../components/buttons/primary_button.dart';
import '../components/app_colors.dart';
import '../components/app_text_styles.dart';
import '../data/role.dart';
import '../services/session_service_v2.dart'; // Updated import
import 'overview_screen.dart';

class QRScreen extends StatefulWidget {
  final String sessionId;
  final int expectedPlayers;
  final Map<String, bool> gameRules;
  final List<Role> selectedRoles;
  final Map<String, int> roleCounts;

  const QRScreen({
    super.key,
    required this.sessionId,
    required this.expectedPlayers,
    required this.gameRules,
    required this.selectedRoles,
    required this.roleCounts,
  });

  @override
  State<QRScreen> createState() => _QRScreenState();
}

class _QRScreenState extends State<QRScreen> {
  int joinedPlayersCount = 0;
  List<String> playerNames = [];
  bool isSessionCreated = false;
  String sessionStatus = 'waiting_for_players';

  @override
  void initState() {
    super.initState();
    _createSession();
    _listenToSession();
  }

  // Helper methods to show messages without BuildContext async gaps
  void _showSuccessMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  /// Creates the session in Firebase using SessionServiceV2
  Future<void> _createSession() async {
    try {
      await SessionServiceV2.createSession(
        sessionId: widget.sessionId,
        expectedPlayers: widget.expectedPlayers,
        roleCounts: widget.roleCounts,
        gameRules: widget.gameRules,
        selectedRoles: widget.selectedRoles,
      );

      if (!mounted) return;

      setState(() {
        isSessionCreated = true;
      });

      // Show success message using helper method
      _showSuccessMessage('Game session created! Players can now join.');
    } catch (e) {
      debugPrint('Error creating session: $e');
      _showErrorMessage('Error creating session: $e');
    }
  }

  /// Listens for real-time session updates using SessionServiceV2
  void _listenToSession() {
    SessionServiceV2.getActiveSessionStream(widget.sessionId).listen((snapshot) {
      if (snapshot.exists && mounted) {
        final data = snapshot.data() as Map<String, dynamic>;
        final players = List<Map<String, dynamic>>.from(data['players'] ?? []);

        setState(() {
          joinedPlayersCount = players.length;
          playerNames = players.map((player) => player['name'] as String).toList();
          sessionStatus = data['status'] ?? 'waiting_for_players';
        });
      }
    }, onError: (error) {
      debugPrint('Error listening to session: $error');
    });
  }

  @override
  Widget build(BuildContext context) {
    // This is the URL players scan to join
    String joinUrl = "https://mafia-mod-tool.web.app/join/${widget.sessionId}";
    bool allPlayersJoined = joinedPlayersCount >= widget.expectedPlayers;

    return Scaffold(
      backgroundColor: AppColors.darkGray,
      appBar: AppBar(
        backgroundColor: AppColors.darkGray,
        foregroundColor: AppColors.white,
        title: Text(
          'INVITE PLAYERS',
          style: AppTextStyles.screenTitle,
        ),
        centerTitle: true,
        actions: [
          // Info button to show game settings
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showGameInfo(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Session ID Display
            Text(
              'SESSION: ${widget.sessionId}',
              style: AppTextStyles.sectionHeader.copyWith(fontSize: 24, letterSpacing: 3.0),
            ),
            const SizedBox(height: 30),

            // QR Code
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    spreadRadius: 5,
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: QrImageView(
                data: joinUrl,
                version: QrVersions.auto,
                size: 250.0,
                backgroundColor: AppColors.white,
              ),
            ),
            const SizedBox(height: 10),

            // Instructions
            Text(
              'Scan to join this session.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyText,
            ),
            const SizedBox(height: 40),

            // Player Count Status
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: allPlayersJoined ? Colors.green : AppColors.primaryOrange,
                    width: 2
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'PLAYERS JOINED:',
                    style: AppTextStyles.sectionHeaderSmall,
                  ),
                  Text(
                    '$joinedPlayersCount/${widget.expectedPlayers}',
                    style: AppTextStyles.playerCount.copyWith(
                      color: allPlayersJoined ? Colors.green : AppColors.primaryOrange,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Status indicator - always visible
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  allPlayersJoined ? 'All players joined!' : 'Waiting for all players to join...',
                  style: AppTextStyles.bodyText.copyWith(
                    color: allPlayersJoined ? Colors.green : AppColors.primaryOrange,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 15),
                if (!allPlayersJoined)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator.adaptive(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryOrange),
                    ),
                  ),
              ],
            ),

            // Spacer to push buttons to bottom
            const Spacer(),

            // Session status indicator
            if (!isSessionCreated)
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                  ),
                  SizedBox(width: 10),
                  Text('Creating session...', style: TextStyle(color: AppColors.white)),
                ],
              )
            else
            // Test button for development - adds fake player using SessionServiceV2
              PrimaryButton(
                text: 'ADD TEST PLAYER',
                width: 200,
                fontSize: 16,
                onPressed: () async {
                  // Add a test player using the new service
                  String testPlayerName = 'TestPlayer${joinedPlayersCount + 1}';
                  bool success = await SessionServiceV2.addPlayer(
                    sessionId: widget.sessionId,
                    playerName: testPlayerName,
                  );

                  if (!success) {
                    _showErrorMessage('Could not add test player');
                  }
                },
              ),
            const SizedBox(height: 20),

            // Start Game Button - only enabled when all players joined
            PrimaryButton(
              text: 'START GAME',
              width: 280,
              fontSize: 22,
              onPressed: (allPlayersJoined && isSessionCreated) ? _startGame : null,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startGame() async {
    try {
      // Start the game using SessionServiceV2
      await SessionServiceV2.startGame(widget.sessionId);

      // Get the updated session data with assigned roles
      final sessionData = await SessionServiceV2.getActiveSession(widget.sessionId);

      if (sessionData == null) {
        if (!mounted) return;
        _showErrorMessage('Could not load game session');
        return;
      }

      // Extract players with their assigned roles
      final List<Map<String, dynamic>> playersWithRoles =
      List<Map<String, dynamic>>.from(sessionData['players'] ?? []);

      debugPrint('Game started successfully!');
      debugPrint('Session ID: ${widget.sessionId}');
      debugPrint('Players with roles: $playersWithRoles');

      if (!mounted) return;
      _showSuccessMessage('Game started! Roles have been assigned.');

      // Navigate to overview screen
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OverviewScreen(
            sessionId: widget.sessionId,
            players: playersWithRoles,
            allRoles: widget.selectedRoles,
            gameRules: widget.gameRules,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error starting game: $e');
      if (!mounted) return;
      _showErrorMessage('Error starting game: $e');
    }
  }

  void _showGameInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.darkGray,
          title: const Text(
            'GAME CONFIGURATION',
            style: TextStyle(
              color: AppColors.white,
              fontFamily: 'AlfaSlabOne',
              fontSize: 16,
              letterSpacing: 1.0,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Session Info
                _buildInfoSection('SESSION INFO', [
                  'Session ID: ${widget.sessionId}',
                  'Expected Players: ${widget.expectedPlayers}',
                  'Status: $sessionStatus',
                ]),
                const SizedBox(height: 15),

                // Roles
                _buildInfoSection('SELECTED ROLES',
                    widget.roleCounts.entries
                        .where((entry) => entry.value > 0)
                        .map((entry) => '${entry.key}: ${entry.value}')
                        .toList()
                ),
                const SizedBox(height: 15),

                // Game Rules
                if (widget.gameRules.isNotEmpty)
                  _buildInfoSection('ACTIVE RULES',
                      widget.gameRules.entries
                          .where((entry) => entry.value)
                          .map((entry) => entry.key)
                          .toList()
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'CLOSE',
                style: TextStyle(
                  color: AppColors.primaryOrange,
                  fontFamily: 'AlfaSlabOne',
                  fontSize: 12,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoSection(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.primaryOrange,
            fontFamily: 'AlfaSlabOne',
            fontSize: 12,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 4),
          child: Text(
            '• $item',
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 12,
            ),
          ),
        )),
      ],
    );
  }
}