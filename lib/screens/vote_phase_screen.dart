import 'package:flutter/material.dart';
import '../components/buttons/primary_button.dart';
import '../components/app_colors.dart';
import '../components/app_text_styles.dart';
import '../services/session_service_v2.dart';
import '../data/role.dart'; // Add this import
import 'night_phase_screen.dart';

class VotePhaseScreen extends StatefulWidget {
  final String sessionId;
  final int dayNumber;

  const VotePhaseScreen({
    super.key,
    required this.sessionId,
    required this.dayNumber,
  });

  @override
  State<VotePhaseScreen> createState() => _VotePhaseScreenState();
}

class _VotePhaseScreenState extends State<VotePhaseScreen> {
  List<Map<String, dynamic>> players = [];
  List<Map<String, dynamic>> nominatedPlayers = [];
  String? selectedPlayerForElimination;
  bool isLoading = true;
  int alivePlayersCount = 0;
  int votesRequiredForElimination = 0;

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
        final nominated = allPlayers.where((player) => player['isNominated'] ?? false).toList();

        setState(() {
          players = allPlayers;
          nominatedPlayers = nominated;
          alivePlayersCount = alivePlayers.length;
          votesRequiredForElimination = (alivePlayersCount / 2).ceil();
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
              Navigator.pop(context);
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

  Future<void> _performAbortGame() async {
    try {
      await SessionServiceV2.abortGame(widget.sessionId);
      if (!mounted) return;
      Navigator.popUntil(context, (route) => route.isFirst);
    } catch (e) {
      debugPrint('Error aborting game: $e');
      if (!mounted) return;
      _showError('Error aborting game: $e');
    }
  }

  void _endDay() {
    // Show confirmation dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.darkGray,
        title: Text(
          'DAY ${widget.dayNumber} RESULTS',
          style: AppTextStyles.sectionHeaderSmall.copyWith(fontSize: 16),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (selectedPlayerForElimination != null) ...[
                Text(
                  'Player to be eliminated:',
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
              ] else ...[
                Text(
                  'No player will be eliminated.',
                  style: AppTextStyles.bodyTextWhite.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'CLOSE',
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
              _submitDayResults();
            },
            child: Text(
              'SUBMIT',
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

  Future<void> _submitDayResults() async {
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

      // Update player states
      List<Map<String, dynamic>> updatedPlayers = players.map((player) {
        Map<String, dynamic> updatedPlayer = Map.from(player);

        // Reset nomination status for all players
        updatedPlayer['isNominated'] = false;

        // Eliminate selected player if any
        if (selectedPlayerForElimination != null &&
            player['name'] == selectedPlayerForElimination) {
          updatedPlayer['isAlive'] = false;
        }

        return updatedPlayer;
      }).toList();

      // Check if eliminated player was Mafia Wife
      bool mafiaWifeEliminated = false;
      if (selectedPlayerForElimination != null) {
        final eliminatedPlayer = players.firstWhere(
              (player) => player['name'] == selectedPlayerForElimination,
          orElse: () => <String, dynamic>{},
        );

        if (eliminatedPlayer.isNotEmpty && eliminatedPlayer['role'] == 'mafia_wife') {
          mafiaWifeEliminated = true;
          debugPrint('Mafia Wife eliminated - bonus kills activated for next night');
        }
      }

      // Update Firebase
      await SessionServiceV2.updatePlayersAfterDay(
        sessionId: widget.sessionId,
        updatedPlayers: updatedPlayers,
        dayNumber: widget.dayNumber,
        eliminatedPlayer: selectedPlayerForElimination,
        mafiaWifeEliminated: mafiaWifeEliminated,
      );

      if (!mounted) return;

      // Close loading dialog
      Navigator.pop(context);

      // Get game phase data AND previous night targets for next night
      final gamePhaseData = await SessionServiceV2.getGamePhaseData(widget.sessionId);
      final previousNightTargets = await SessionServiceV2.getPreviousNightTargets(widget.sessionId);

      // Check if widget is still mounted after async operation
      if (!mounted) return;

      if (gamePhaseData != null) {
        // Convert selected roles from Map to Role objects
        final selectedRolesData = List<Map<String, dynamic>>.from(
            gamePhaseData['selectedRoles'] ?? []
        );

        // Navigate to next night phase with previous night targets
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => NightPhaseScreen(
              sessionId: widget.sessionId,
              selectedRoles: _convertToRoleObjects(selectedRolesData),
              nightNumber: widget.dayNumber + 1, // Next night
              previousNightTargets: previousNightTargets, // ✅ NOW PROPERLY LOADED
              gameRules: Map<String, bool>.from(gamePhaseData['gameRules'] ?? {}),
            ),
          ),
        );
      } else {
        _showError('Could not load game data for next night phase');
      }

      debugPrint('Day ${widget.dayNumber} completed successfully');
    } catch (e) {
      debugPrint('Error submitting day results: $e');
      if (!mounted) return;

      // Close loading dialog
      Navigator.pop(context);
      _showError('Error submitting day results: $e');
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
          'VOTE ${widget.dayNumber}',
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
            child: Column(
              children: [
                if (nominatedPlayers.isNotEmpty) ...[
                  Text(
                    'At least $votesRequiredForElimination votes required for elimination',
                    style: AppTextStyles.bodyText.copyWith(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Select player with majority vote to eliminate',
                    style: AppTextStyles.bodyText.copyWith(fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ] else ...[
                  Text(
                    'No players were nominated for elimination',
                    style: AppTextStyles.bodyText.copyWith(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),

          // Content area
          Expanded(
            child: nominatedPlayers.isEmpty
                ? Center(
              child: Container(
                padding: const EdgeInsets.all(30),
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.blue.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.how_to_vote_outlined,
                      size: 48,
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'NO ELIMINATIONS',
                      style: AppTextStyles.sectionHeader.copyWith(
                        fontSize: 20,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No one was eliminated on Day ${widget.dayNumber}',
                      style: AppTextStyles.bodyText.copyWith(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: nominatedPlayers.length,
              itemBuilder: (context, index) {
                final player = nominatedPlayers[index];
                final playerName = player['name'] ?? 'Unknown';
                final isSelected = selectedPlayerForElimination == playerName;

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
                            Expanded(
                              child: Text(
                                playerName,
                                style: AppTextStyles.sectionHeaderSmall.copyWith(
                                  fontSize: 18,
                                  color: AppColors.white,
                                ),
                              ),
                            ),
                            if (isSelected)
                              Icon(
                                Icons.close_rounded,
                                color: Colors.red,
                                size: 24,
                              ),
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
              text: 'END DAY',
              width: 280,
              fontSize: 22,
              onPressed: _endDay,
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to convert role data back to Role objects
  List<Role> _convertToRoleObjects(List<Map<String, dynamic>> rolesData) {
    return rolesData.map((roleData) {
      // Find the matching role from RoleManager
      final roleName = roleData['name'] ?? '';
      final role = RoleManager.getRoleByName(roleName);
      return role;
    }).where((role) => role != null).cast<Role>().toList();
  }
}