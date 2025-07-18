import 'package:flutter/material.dart';
import '../components/buttons/primary_button.dart';
import '../components/app_colors.dart';
import '../components/app_text_styles.dart';
import '../services/session_service_v2.dart'; // Updated import
import 'day_phase_screen.dart';

class NightSummaryScreen extends StatefulWidget {
  final String sessionId;
  final int nightNumber;
  final List<NightResult> eliminationResults;

  const NightSummaryScreen({
    super.key,
    required this.sessionId,
    required this.nightNumber,
    required this.eliminationResults,
  });

  @override
  State<NightSummaryScreen> createState() => _NightSummaryScreenState();
}

class _NightSummaryScreenState extends State<NightSummaryScreen> {
  int alivePlayersCount = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGameState();
  }

  // Fetch fresh game state from Firebase using SessionServiceV2
  Future<void> _loadGameState() async {
    try {
      final sessionData = await SessionServiceV2.getActiveSession(widget.sessionId);
      if (sessionData != null && mounted) {
        final players = List<Map<String, dynamic>>.from(sessionData['players'] ?? []);
        setState(() {
          alivePlayersCount = players.where((player) => player['isAlive'] ?? true).length;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading game state: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _abortGame() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.darkGray,
        title: Text(
          'ABORT GAME',
          style: TextStyle(
            color: AppColors.white,
            fontFamily: 'AlfaSlabOne',
            fontSize: 16,
          ),
        ),
        content: Text(
          'Are you sure you want to abort the game?\nThis will return you to the main menu.',
          style: TextStyle(color: AppColors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'CANCEL',
              style: TextStyle(
                color: AppColors.primaryOrange,
                fontFamily: 'AlfaSlabOne',
                fontSize: 12,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog first
              _performAbortGame();
            },
            child: Text(
              'ABORT',
              style: TextStyle(
                color: Colors.red,
                fontFamily: 'AlfaSlabOne',
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Separate async method to handle the abort logic
  Future<void> _performAbortGame() async {
    try {
      await SessionServiceV2.abortGame(widget.sessionId);

      if (!mounted) return;
      Navigator.popUntil(context, (route) => route.isFirst);
    } catch (e) {
      debugPrint('Error aborting game: $e');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error aborting game: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkGray,
      appBar: AppBar(
        backgroundColor: AppColors.darkGray,
        foregroundColor: AppColors.white,
        automaticallyImplyLeading: false,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: Text(
          'NIGHT ${widget.nightNumber} SUMMARY',
          style: AppTextStyles.screenTitle,
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.close, color: Colors.red),
            onPressed: _abortGame,
            tooltip: 'Abort Game',
          ),
        ],
      ),
      body: isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator.adaptive(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryOrange),
            ),
            const SizedBox(height: 20),
            Text(
              'Loading game state...',
              style: AppTextStyles.bodyTextWhite,
            ),
          ],
        ),
      )
          : Column(
        children: [
          // Header bar with Session ID and Alive count (identical to overview_screen.dart)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              border: Border(
                bottom: BorderSide(
                  color: AppColors.primaryOrange.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Session ID: ${widget.sessionId}',
                  style: AppTextStyles.bodyTextWhite.copyWith(fontSize: 14),
                ),
                Text(
                  'Alive: $alivePlayersCount',
                  style: AppTextStyles.bodyTextWhite.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Simple instruction text (replaces the boxed header)
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(
              'Announce these results to all players',
              style: AppTextStyles.bodyText.copyWith(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),

          // Results section
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: widget.eliminationResults.isEmpty
                  ? Center(
                child: Container(
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.green.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.shield,
                        size: 48,
                        color: Colors.green,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'NO ELIMINATIONS',
                        style: AppTextStyles.sectionHeader.copyWith(
                          fontSize: 20,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No one was eliminated during the night',
                        style: AppTextStyles.bodyText.copyWith(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
                  : ListView.builder(
                itemCount: widget.eliminationResults.length,
                itemBuilder: (context, index) {
                  final result = widget.eliminationResults[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.red.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.close_rounded,
                          size: 32,
                          color: Colors.red,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                result.playerName,
                                style: AppTextStyles.sectionHeader.copyWith(
                                  fontSize: 20,
                                  color: Colors.red,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                result.description,
                                style: AppTextStyles.bodyText.copyWith(fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Bottom button - FIXED: Now shows correct day number
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: PrimaryButton(
              text: 'DAY ${widget.nightNumber}', // FIXED: Removed +1
              width: 280,
              fontSize: 22,
              onPressed: () => _navigateToDayPhase(context),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToDayPhase(BuildContext context) {
    // Navigate to Day Phase screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DayPhaseScreen(
          sessionId: widget.sessionId,
          dayNumber: widget.nightNumber, // Day number matches night number
        ),
      ),
    );
  }
}

// Data class for night elimination results
class NightResult {
  final String playerName;
  final String description;

  NightResult({
    required this.playerName,
    required this.description,
  });
}

// Night resolution service class
class NightResolver {
  static NightResolutionResult processNightActions({
    required List<Map<String, dynamic>> players,
    required Map<String, String?> actions,
    required Map<String, bool> gameRules,
  }) {
    List<NightResult> eliminationResults = [];
    List<Map<String, dynamic>> updatedPlayers = List.from(players);

    // Get all elimination attempts
    Set<String> eliminationTargets = {};

    // Mafia elimination - handle both normal and Mafia Wife bonus
    final mafiaTarget = actions['mafia_eliminate'];
    final mafiaTarget1 = actions['mafia_target_1'];
    final mafiaTarget2 = actions['mafia_target_2'];

    if (mafiaTarget != null && mafiaTarget != 'SKIP_NIGHT') {
      // Normal mafia elimination
      eliminationTargets.add(mafiaTarget);
    } else if (mafiaTarget1 != null || mafiaTarget2 != null) {
      // Mafia Wife bonus - check both targets
      if (mafiaTarget1 != null && mafiaTarget1 != 'SKIP_NIGHT') {
        eliminationTargets.add(mafiaTarget1);
      }
      if (mafiaTarget2 != null && mafiaTarget2 != 'SKIP_NIGHT') {
        eliminationTargets.add(mafiaTarget2);
      }
    }

    // Serial killer elimination
    final serialKillerTarget = actions['serial_killer_action'];
    if (serialKillerTarget != null && serialKillerTarget != 'SKIP_NIGHT') {
      eliminationTargets.add(serialKillerTarget);
    }

    // Get doctor protections
    Set<String> protectedPlayers = {};
    final doctorTarget = actions['doctor_action'];
    if (doctorTarget != null) {
      protectedPlayers.add(doctorTarget);
    }

    // Process eliminations with protection logic
    for (String targetName in eliminationTargets) {
      final targetPlayer = updatedPlayers.firstWhere(
            (player) => player['name'] == targetName,
        orElse: () => <String, dynamic>{},
      );

      if (targetPlayer.isNotEmpty) {
        final roleName = targetPlayer['role'] ?? '';

        // Check if protected by doctor (except Grandma)
        bool isProtected = protectedPlayers.contains(targetName) && roleName != 'grandma_with_gun';

        if (!isProtected) {
          // Player is eliminated
          targetPlayer['isAlive'] = false;
          eliminationResults.add(NightResult(
            playerName: targetName,
            description: 'was eliminated during the night',
          ));
        }
        // If protected, they survive silently (no announcement about protection)
      }
    }

    return NightResolutionResult(
      eliminationResults: eliminationResults,
      updatedPlayers: updatedPlayers,
    );
  }
}

// Result container for night resolution
class NightResolutionResult {
  final List<NightResult> eliminationResults;
  final List<Map<String, dynamic>> updatedPlayers;

  NightResolutionResult({
    required this.eliminationResults,
    required this.updatedPlayers,
  });
}