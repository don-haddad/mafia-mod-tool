import 'package:flutter/material.dart';
import '../components/buttons/primary_button.dart';
import '../components/app_colors.dart';
import '../components/app_text_styles.dart';
import '../data/role.dart';

class NightSummaryScreen extends StatelessWidget {
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
          'NIGHT ${nightNumber} RESULTS',
          style: AppTextStyles.screenTitle,
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Header section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primaryOrange.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'NIGHT ${nightNumber} SUMMARY',
                    style: AppTextStyles.sectionHeader.copyWith(fontSize: 24),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Announce these results to all players',
                    style: AppTextStyles.bodyText.copyWith(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Results section
            Expanded(
              child: eliminationResults.isEmpty
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
                itemCount: eliminationResults.length,
                itemBuilder: (context, index) {
                  final result = eliminationResults[index];
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

            const SizedBox(height: 20),

            // Bottom button
            PrimaryButton(
              text: 'DAY ${nightNumber + 1}',
              width: 280,
              fontSize: 22,
              onPressed: () => _navigateToDayPhase(context),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToDayPhase(BuildContext context) {
    // TODO: Navigate to day phase screen when implemented
    debugPrint('Navigate to Day ${nightNumber + 1}');

    // For now, show a placeholder dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.darkGray,
        title: Text(
          'DAY ${nightNumber + 1}',
          style: TextStyle(
            color: AppColors.white,
            fontFamily: 'AlfaSlabOne',
            fontSize: 18,
          ),
        ),
        content: Text(
          'Day phase not implemented yet.\nWill return to overview for now.',
          style: TextStyle(color: AppColors.white),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              // Return to overview screen (pop all the way back)
              Navigator.popUntil(context, (route) => route.isFirst);
            },
            child: Text(
              'CONTINUE',
              style: TextStyle(
                color: AppColors.primaryOrange,
                fontFamily: 'AlfaSlabOne',
                fontSize: 12,
              ),
            ),
          ),
        ],
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

    // Mafia elimination
    final mafiaTarget = actions['mafia_eliminate'];
    if (mafiaTarget != null && mafiaTarget != 'SKIP_NIGHT') {
      eliminationTargets.add(mafiaTarget);
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