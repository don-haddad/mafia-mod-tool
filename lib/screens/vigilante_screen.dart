import 'package:flutter/material.dart';
import '../components/buttons/primary_button.dart';
import '../components/app_colors.dart';
import '../components/app_text_styles.dart';
import '../services/session_service_v2.dart';
import '../data/role.dart';
import 'day_phase_screen.dart';

class VigilanteScreen extends StatefulWidget {
  final String sessionId;
  final int dayNumber;
  final String sourceScreen; // 'day_phase' or 'vote_phase'

  const VigilanteScreen({
    super.key,
    required this.sessionId,
    required this.dayNumber,
    required this.sourceScreen,
  });

  @override
  State<VigilanteScreen> createState() => _VigilanteScreenState();
}

class _VigilanteScreenState extends State<VigilanteScreen> {
  List<Map<String, dynamic>> players = [];
  Map<String, dynamic>? vigilantePlayer;
  String? selectedPlayerForElimination;
  bool isLoading = true;
  int alivePlayersCount = 0;

  @override
  void initState() {
    super.initState();
    _loadGameState();
  }

  // Load fresh game state from Firebase
  Future<void> _loadGameState() async {
    try {
      final sessionData = await SessionServiceV2.getActiveSession(widget.sessionId);
      if (sessionData != null && mounted) {
        final allPlayers = List<Map<String, dynamic>>.from(sessionData['players'] ?? []);
        final alivePlayers = allPlayers.where((player) => player['isAlive'] ?? true).toList();

        // Find vigilante player
        final vigilante = await SessionServiceV2.getVigilantePlayer(widget.sessionId);

        setState(() {
          players = allPlayers;
          vigilantePlayer = vigilante;
          alivePlayersCount = alivePlayers.length;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading game state: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        _showError('Error loading game state: $e');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _selectPlayerForElimination(String playerName) {
    setState(() {
      selectedPlayerForElimination =
      selectedPlayerForElimination == playerName ? null : playerName;
    });
  }

  void _submitVigilanteAction() {
    if (selectedPlayerForElimination == null) {
      _showError('Please select a player to eliminate');
      return;
    }

    // Show confirmation dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.darkGray,
        title: Text(
          'VIGILANTE ELIMINATION',
          style: AppTextStyles.sectionHeaderSmall.copyWith(fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vigilante will eliminate:',
              style: AppTextStyles.bodyTextWhite.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              selectedPlayerForElimination!,
              style: AppTextStyles.bodyTextWhite.copyWith(
                fontSize: 18,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 15),
            Text(
              'This action cannot be undone and will restart the day phase.',
              style: AppTextStyles.bodyText.copyWith(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'CANCEL',
              style: TextStyle(
                color: Colors.grey,
                fontFamily: 'AlfaSlabOne',
                fontSize: 12,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _processVigilanteAction();
            },
            child: Text(
              'ELIMINATE',
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

  Future<void> _processVigilanteAction() async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: CircularProgressIndicator.adaptive(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryOrange),
          ),
        ),
      );

      // Process vigilante elimination
      final result = _processVigilanteElimination();

      // Update Firebase with new player states
      await SessionServiceV2.updateVigilanteAction(
        sessionId: widget.sessionId,
        updatedPlayers: result.updatedPlayers,
        dayNumber: widget.dayNumber,
        targetPlayer: selectedPlayerForElimination!,
        vigilanteDied: result.vigilanteDied,
      );

      // Reset day phase (clear nominations)
      await SessionServiceV2.resetDayPhaseAfterVigilante(
        sessionId: widget.sessionId,
        updatedPlayers: result.updatedPlayers,
        dayNumber: widget.dayNumber,
      );

      if (!mounted) return;

      // Close loading dialog
      Navigator.pop(context);

      // Show results dialog
      _showVigilanteResultsDialog(result);

    } catch (e) {
      debugPrint('Error processing vigilante action: $e');
      if (!mounted) return;

      // Close loading dialog
      Navigator.pop(context);
      _showError('Error processing vigilante action: $e');
    }
  }

  VigilanteActionResult _processVigilanteElimination() {
    List<Map<String, dynamic>> updatedPlayers = List.from(players);
    bool vigilanteDied = false;
    List<String> eliminatedPlayers = [];

    // Find target player and their role
    final targetPlayer = updatedPlayers.firstWhere(
          (player) => player['name'] == selectedPlayerForElimination,
    );

    final targetRole = RoleManager.getRoleByName(targetPlayer['role'] ?? '');

    // Step 1: Eliminate target player
    targetPlayer['isAlive'] = false;
    eliminatedPlayers.add(selectedPlayerForElimination!);

    // Step 2: Check if target was Town - if so, eliminate vigilante too
    if (targetRole != null && targetRole.team == Team.town) {
      vigilanteDied = true;

      // Find and eliminate vigilante (we know they exist)
      final vigilantePlayer = updatedPlayers.firstWhere(
            (player) => player['role'] == 'vigilante',
      );
      vigilantePlayer['isAlive'] = false;
      eliminatedPlayers.add(vigilantePlayer['name']);
    }

    return VigilanteActionResult(
      updatedPlayers: updatedPlayers,
      eliminatedPlayers: eliminatedPlayers,
      vigilanteDied: vigilanteDied,
      targetWasTown: targetRole?.team == Team.town,
    );
  }

  void _showVigilanteResultsDialog(VigilanteActionResult result) {
    // Get target role information for display
    final targetPlayer = players.firstWhere(
          (player) => player['name'] == selectedPlayerForElimination,
      orElse: () => <String, dynamic>{},
    );
    final targetRole = RoleManager.getRoleByName(targetPlayer['role'] ?? '');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.darkGray,
        title: Text(
          'VIGILANTE RESULTS',
          style: AppTextStyles.sectionHeaderSmall.copyWith(fontSize: 16),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Target elimination info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TARGET ELIMINATED:',
                      style: AppTextStyles.bodyTextWhite.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 5),
                    // Show target player name and role
                    Text(
                      '$selectedPlayerForElimination (${targetRole?.displayName ?? 'Unknown'})',
                      style: AppTextStyles.bodyTextWhite.copyWith(fontSize: 14),
                    ),
                    // Show vigilante if they died too
                    if (result.vigilanteDied) ...[
                      const SizedBox(height: 5),
                      Text(
                        '${vigilantePlayer?['name'] ?? 'Vigilante'} (Vigilante)',
                        style: AppTextStyles.bodyTextWhite.copyWith(fontSize: 14),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 15),

              // Game flow info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryOrange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primaryOrange),
                ),
                child: Text(
                  'Returning to Day ${widget.dayNumber} for fresh nominations.\n\nVigilante ability has been used and is no longer available.',
                  style: AppTextStyles.bodyText.copyWith(fontSize: 14),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              _returnToDayPhase();
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

  void _returnToDayPhase() {
    // Simple navigation: clear stack and go to day phase with SAME day number
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => DayPhaseScreen(
          sessionId: widget.sessionId,
          dayNumber: widget.dayNumber, // SAME day number, not incremented
        ),
      ),
          (route) => route.isFirst, // Only keep the home screen in stack
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkGray,
      appBar: AppBar(
        backgroundColor: AppColors.darkGray,
        foregroundColor: AppColors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: Text(
          'VIGILANTE ELIMINATION',
          style: AppTextStyles.screenTitle,
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context), // Simple pop back to previous screen
        ),
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
          // Header bar with Session ID and Alive count
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
                  'Session: ${widget.sessionId}',
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

          // Instructions
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(
              'Select a player to eliminate',
              style: AppTextStyles.bodyText.copyWith(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),

          // Player list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _getAvailablePlayers().length,
              itemBuilder: (context, index) {
                final player = _getAvailablePlayers()[index];
                final playerName = player['name'] ?? 'Unknown';
                final roleName = player['role'] ?? '';
                final role = RoleManager.getRoleByName(roleName);
                final roleDisplayName = role?.displayName ?? 'Unknown Role';
                final isSelected = selectedPlayerForElimination == playerName;

                // Get role color based on team
                Color roleColor = Colors.grey;
                if (role != null) {
                  switch (role.team) {
                    case Team.town:
                      roleColor = Colors.blue;
                      break;
                    case Team.scum:
                      roleColor = Colors.red;
                      break;
                    case Team.independent:
                      roleColor = Colors.purple;
                      break;
                  }
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _selectPlayerForElimination(playerName),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.red.withValues(alpha: 0.3)
                              : Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? Colors.red
                                : Colors.white.withValues(alpha: 0.3),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Player name
                            Expanded(
                              flex: 2,
                              child: Text(
                                playerName,
                                style: AppTextStyles.sectionHeaderSmall.copyWith(
                                  fontSize: 18,
                                  color: AppColors.white,
                                ),
                              ),
                            ),

                            const SizedBox(width: 12),

                            // Role display
                            Expanded(
                              flex: 2,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: roleColor.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: roleColor.withValues(alpha: 0.6),
                                  ),
                                ),
                                child: Text(
                                  roleDisplayName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: roleColor,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),

                            const SizedBox(width: 8),

                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Bottom button
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: PrimaryButton(
              text: 'SUBMIT',
              width: 280,
              fontSize: 22,
              onPressed: selectedPlayerForElimination != null ? _submitVigilanteAction : null,
            ),
          ),
        ],
      ),
    );
  }

  // Get alive players excluding vigilante themselves
  List<Map<String, dynamic>> _getAvailablePlayers() {
    final vigilanteName = vigilantePlayer?['name'] ?? '';
    return players.where((player) {
      final isAlive = player['isAlive'] ?? true;
      final isNotVigilante = player['name'] != vigilanteName;
      return isAlive && isNotVigilante;
    }).toList();
  }
}

// Data class for vigilante action result
class VigilanteActionResult {
  final List<Map<String, dynamic>> updatedPlayers;
  final List<String> eliminatedPlayers;
  final bool vigilanteDied;
  final bool targetWasTown;

  VigilanteActionResult({
    required this.updatedPlayers,
    required this.eliminatedPlayers,
    required this.vigilanteDied,
    required this.targetWasTown,
  });
}