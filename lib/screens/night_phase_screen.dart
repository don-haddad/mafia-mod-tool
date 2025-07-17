import 'package:flutter/material.dart';
import 'dart:async';
import '../components/buttons/primary_button.dart';
import '../components/app_colors.dart';
import '../components/app_text_styles.dart';
import '../data/role.dart';
import '../services/session_service_v2.dart'; // Updated import
import 'night_summary_screen.dart';

class NightPhaseScreen extends StatefulWidget {
  final String sessionId;
  final List<Role> selectedRoles;
  final int nightNumber;
  final Map<String, dynamic>? previousNightTargets; // For repeat restrictions
  final Map<String, bool> gameRules; // For Mafia Night Skip rule

  const NightPhaseScreen({
    super.key,
    required this.sessionId,
    required this.selectedRoles,
    required this.nightNumber,
    this.previousNightTargets,
    required this.gameRules,
  });

  @override
  State<NightPhaseScreen> createState() => _NightPhaseScreenState();
}

class _NightPhaseScreenState extends State<NightPhaseScreen> with TickerProviderStateMixin {
  int currentStageIndex = 0;
  Map<String, String?> nightActions = {}; // stage_key -> target_player_name
  late List<NightStage> nightStages;

  // ✅ Fresh game state from Firebase
  List<Map<String, dynamic>> players = [];
  bool isLoadingGameState = true;
  int mafiaExtraKills = 0;

  // Timer properties
  static const int countdownDuration = 3; // Easy to modify (10, 15, 20, 30 seconds)
  late AnimationController _timerController;
  late Animation<double> _timerAnimation;
  Timer? _countdownTimer;
  int _remainingSeconds = countdownDuration;
  bool _timerStarted = false;

  @override
  void initState() {
    super.initState();
    _loadFreshGameState(); // ✅ Fetch fresh data from Firebase first
  }

  // ✅ Load fresh game state from Firebase using SessionServiceV2
  Future<void> _loadFreshGameState() async {
    try {
      final sessionData = await SessionServiceV2.getActiveSession(widget.sessionId);
      if (sessionData != null && mounted) {
        setState(() {
          players = List<Map<String, dynamic>>.from(sessionData['players'] ?? []);
          mafiaExtraKills = sessionData['mafiaExtraKills'] ?? 0;
          isLoadingGameState = false;
        });

        // Initialize after data is loaded
        _buildNightStages();
        _initializeTimer();
      }
    } catch (e) {
      debugPrint('Error loading game state: $e');
      if (mounted) {
        setState(() {
          isLoadingGameState = false;
        });
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading game state: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Initialize timer animation
  void _initializeTimer() {
    _timerController = AnimationController(
      duration: Duration(seconds: countdownDuration),
      vsync: this,
    );

    _timerAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _timerController,
      curve: Curves.linear,
    ));

    // Start timer automatically when stage loads
    _startTimer();
  }

  // Start countdown timer
  void _startTimer() {
    if (_timerStarted) return;

    _timerStarted = true;
    _remainingSeconds = countdownDuration;
    _timerController.reset();
    _timerController.forward();

    _countdownTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _remainingSeconds--;
        if (_remainingSeconds <= 0) {
          timer.cancel();
          _timerStarted = false;
        }
      });
    });
  }

  // Reset timer when moving to next stage
  void _resetTimer() {
    _countdownTimer?.cancel();
    _timerController.reset();
    _timerStarted = false;
    _remainingSeconds = countdownDuration;
  }

  // Custom countdown timer widget
  Widget _buildCountdownTimer() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        children: [
          // Timer text
          Text(
            'Stage Timer: ${_remainingSeconds}s',
            style: AppTextStyles.bodyTextWhite.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),

          // Animated progress bar that depletes from both ends
          Container(
            width: double.infinity,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
            child: AnimatedBuilder(
              animation: _timerAnimation,
              builder: (context, child) {
                double progress = _timerAnimation.value;
                double barWidth = MediaQuery.of(context).size.width - 40;
                double centerPoint = barWidth / 2;
                double activeWidth = centerPoint * progress;

                return Stack(
                  children: [
                    // Left bar (depletes from left to center)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: activeWidth,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primaryOrange,
                              AppColors.primaryOrange.withValues(alpha: 0.7),
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    // Right bar (depletes from right to center)
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      width: activeWidth,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primaryOrange.withValues(alpha: 0.7),
                              AppColors.primaryOrange,
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Helper method for DRY instructions
  String _getInstructionsForRole(String roleName) {
    try {
      final role = widget.selectedRoles.firstWhere((r) => r.name == roleName);
      return role.nightInstructions;
    } catch (e) {
      return 'Choose your action'; // Fallback
    }
  }

  // Check if role player is alive for current stage
  bool _isRolePlayerAlive(String stageKey) {
    String roleName;

    // Map stage keys to role names
    switch (stageKey) {
      case 'mafia_eliminate':
      // For mafia stage, check if ANY scum member is alive
        return players.any((player) {
          if (!(player['isAlive'] ?? true)) return false;
          final playerRole = RoleManager.getRoleByName(player['role'] ?? '');
          return playerRole != null && playerRole.team == Team.scum;
        });
      case 'lawyer_defend':
        roleName = 'lawyer';
        break;
      case 'detective_action':
        roleName = 'detective';
        break;
      case 'doctor_action':
        roleName = 'doctor';
        break;
      case 'serial_killer_action':
        roleName = 'serial_killer';
        break;
      case 'interrogator_action':
        roleName = 'interrogator';
        break;
      default:
      // Extract role name from stage key (e.g., 'role_name_action' -> 'role_name')
        roleName = stageKey.replaceAll('_action', '');
        break;
    }

    // Check if player with this role is alive
    return players.any((player) =>
    (player['isAlive'] ?? true) && (player['role'] ?? '') == roleName
    );
  }

  // Check if current stage can proceed
  bool _canProceedToNextStage() {
    final currentStage = nightStages[currentStageIndex];
    final timerFinished = _remainingSeconds <= 0;
    final rolePlayerAlive = _isRolePlayerAlive(currentStage.stageKey);

    // Timer must always be finished
    if (!timerFinished) return false;

    // If role player is dead, only need timer
    if (!rolePlayerAlive) return true;

    // Check selection requirements
    bool hasSelection;
    if (currentStage.stageKey == 'mafia_eliminate' && mafiaExtraKills > 0) {
      // Mafia Wife bonus - need both targets selected OR both skipped
      hasSelection = (nightActions['mafia_target_1'] != null && nightActions['mafia_target_2'] != null);
    } else {
      // Normal single selection
      hasSelection = nightActions[currentStage.stageKey] != null;
    }

    // If role player is alive, need both timer AND selection
    return hasSelection;
  }

  // Build night stages using DRY principle
  void _buildNightStages() {
    nightStages = [];
    final rolesWithNightStages = RoleManager.getNightStageRoles(widget.selectedRoles);

    for (Role role in rolesWithNightStages) {
      if (role.name == 'lawyer') {
        // Lawyer participates in both Mafia stage and their own stage
        nightStages.add(NightStage(
          stageName: 'Lawyer Defense',
          roleDisplayName: role.displayName,
          instructions: _getInstructionsForRole('lawyer'),
          stageKey: 'lawyer_defend',
          cannotRepeatTarget: role.cannotRepeatTarget,
          isScumCombined: false,
        ));
      } else if (role.team == Team.scum && role.hasNightStage) {
        // Handle Mafia stage (combined for all scum)
        if (!nightStages.any((stage) => stage.stageKey == 'mafia_eliminate')) {
          // Dynamic instructions based on Mafia Wife bonus
          String mafiaInstructions = mafiaExtraKills > 0
              ? 'Wake up, and choose 2 players to eliminate'
              : _getInstructionsForRole('mafia');

          nightStages.add(NightStage(
            stageName: 'Mafia Elimination',
            roleDisplayName: 'MAFIA',
            instructions: mafiaInstructions,
            stageKey: 'mafia_eliminate',
            cannotRepeatTarget: true,
            isScumCombined: true,
          ));
        }
      } else {
        // All other roles get their own stage
        nightStages.add(NightStage(
          stageName: '${role.displayName} Action',
          roleDisplayName: role.displayName,
          instructions: role.nightInstructions,
          stageKey: '${role.name}_action',
          cannotRepeatTarget: role.cannotRepeatTarget,
          isScumCombined: false,
        ));
      }
    }

    // Sort stages by the role order we defined
    nightStages.sort((a, b) => _getStageOrder(a.stageKey).compareTo(_getStageOrder(b.stageKey)));
  }

  int _getStageOrder(String stageKey) {
    switch (stageKey) {
      case 'mafia_eliminate': return 1;
      case 'serial_killer_action': return 2;
      case 'lawyer_defend': return 3;
      case 'detective_action': return 4;
      case 'interrogator_action': return 5;
      case 'doctor_action': return 6;
      default: return 99; // Unknown stages go last
    }
  }

  // Get players available for current stage - returns empty if role is dead
  List<Map<String, dynamic>> _getAvailablePlayersForStage(String stageKey) {
    // If role player is dead, return empty list (no players to choose from)
    if (!_isRolePlayerAlive(stageKey)) {
      return [];
    }

    final alivePlayers = players.where((player) => player['isAlive'] ?? true).toList();

    // Special filtering for Mafia stage - exclude all scum members
    if (stageKey == 'mafia_eliminate') {
      return alivePlayers.where((player) {
        final roleName = player['role'] ?? '';
        final role = RoleManager.getRoleByName(roleName);

        // Exclude all scum team members
        return role != null && role.team != Team.scum;
      }).toList();
    }

    // ✅ Special filtering for Detective stage - exclude the current detective player
    if (stageKey == 'detective_action') {
      // Find the specific detective player who is performing the investigation
      final currentDetective = players.firstWhere(
            (player) => (player['isAlive'] ?? true) && (player['role'] ?? '') == 'detective',
        orElse: () => <String, dynamic>{},
      );

      return alivePlayers.where((player) {
        // Exclude the current detective from investigating themselves
        return player['name'] != currentDetective['name'];
      }).toList();
    }

    // Special filtering for Lawyer stage
    if (stageKey == 'lawyer_defend') {
      return alivePlayers.where((player) {
        final roleName = player['role'] ?? '';
        final role = RoleManager.getRoleByName(roleName);

        // Only include Scum members without investigation immunity
        return role != null &&
            role.team == Team.scum &&
            roleName != 'godfather' &&
            roleName != 'mafia_wife';
      }).toList();
    }

    return alivePlayers;
  }

  // Get role display name for player
  String _getPlayerRoleDisplay(Map<String, dynamic> player, String stageKey) {
    final playerName = player['name'] ?? 'Unknown';
    final roleName = player['role'] ?? '';

    // Hide roles for Detective stage
    if (stageKey == 'detective_action') {
      return playerName;
    }

    final role = RoleManager.getRoleByName(roleName);
    final roleDisplay = role?.displayName ?? 'Unknown';
    return '$playerName ($roleDisplay)';
  }

  // Check if player was targeted previous night (for graying out)
  bool _wasPlayerTargetedPreviousNight(String playerName, String stageKey) {
    if (widget.previousNightTargets == null) return false;

    // Map stage keys to previous night target keys
    String? targetKey;
    switch (stageKey) {
      case 'mafia_eliminate':
        targetKey = 'mafia_target';
        break;
      case 'detective_action':
        targetKey = 'detective_target';
        break;
      case 'doctor_action':
        targetKey = 'doctor_target';
        break;
      case 'lawyer_defend':
        targetKey = 'lawyer_target';
        break;
    // Add other roles as needed
    }

    if (targetKey == null) return false;
    return widget.previousNightTargets![targetKey] == playerName;
  }

  void _selectPlayer(String playerName) {
    final currentStage = nightStages[currentStageIndex];

    setState(() {
      if (currentStage.stageKey == 'mafia_eliminate' && mafiaExtraKills > 0) {
        // Handle Mafia Wife bonus - need 2 selections
        if (playerName == 'SKIP_TARGET_1') {
          nightActions['mafia_target_1'] = 'SKIP_NIGHT';
        } else if (playerName == 'SKIP_TARGET_2') {
          nightActions['mafia_target_2'] = 'SKIP_NIGHT';
        } else if (nightActions['mafia_target_1'] == null) {
          nightActions['mafia_target_1'] = playerName;
        } else if (nightActions['mafia_target_2'] == null) {
          nightActions['mafia_target_2'] = playerName;
        } else {
          // Both slots filled, replace the first one
          nightActions['mafia_target_1'] = playerName;
          nightActions['mafia_target_2'] = null;
        }
      } else {
        // Normal single selection
        if (playerName == 'SKIP_NIGHT') {
          nightActions[currentStage.stageKey] = 'SKIP_NIGHT';
        } else {
          nightActions[currentStage.stageKey] = playerName;
        }
      }
    });

    // Handle Detective investigation result
    if (nightStages[currentStageIndex].stageKey == 'detective_action') {
      _showDetectiveResult(playerName);
    }
  }

  void _showDetectiveResult(String targetPlayerName) {
    final targetPlayer = players.firstWhere((p) => p['name'] == targetPlayerName);
    final roleName = targetPlayer['role'] ?? '';
    final role = RoleManager.getRoleByName(roleName);

    String signalToDetective = 'TOWN';
    String reasoning = '';

    if (role != null) {
      if (roleName == 'godfather' || roleName == 'mafia_wife') {
        // Special immunity - appears as Town
        signalToDetective = 'TOWN';
        reasoning = '${role.displayName} appears as Town (Investigation Immunity)';
      } else if (role.team == Team.scum) {
        // Check if protected by Lawyer
        final lawyerTarget = nightActions['lawyer_defend'];
        if (lawyerTarget == targetPlayerName) {
          signalToDetective = 'TOWN';
          reasoning = '${role.displayName} protected by Lawyer';
        } else {
          signalToDetective = 'SCUM';
          reasoning = '${role.displayName} is Scum';
        }
      } else {
        signalToDetective = 'TOWN';
        reasoning = '${role.displayName} is Town';
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.darkGray,
        title: Text(
          'DETECTIVE INVESTIGATION',
          style: AppTextStyles.sectionHeaderSmall.copyWith(fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Target: $targetPlayerName',
              style: AppTextStyles.bodyTextWhite,
            ),
            const SizedBox(height: 10),
            Text(
              'Actual Role: ${role?.displayName ?? 'Unknown'}',
              style: AppTextStyles.bodyTextWhite.copyWith(fontSize: 14),
            ),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: signalToDetective == 'SCUM'
                    ? Colors.red.withValues(alpha: 0.2)
                    : Colors.blue.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: signalToDetective == 'SCUM' ? Colors.red : Colors.blue,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Signal to Detective: $signalToDetective',
                    style: AppTextStyles.bodyTextWhite.copyWith(
                      fontWeight: FontWeight.bold,
                      color: signalToDetective == 'SCUM' ? Colors.red : Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    reasoning,
                    style: AppTextStyles.bodyTextWhite.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'UNDERSTOOD',
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
              _endGameAndNavigateHome(); // Call async method
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

  Future<void> _endGameAndNavigateHome() async {
    try {
      // Abort the game using SessionServiceV2 (this deletes it immediately)
      await SessionServiceV2.abortGame(widget.sessionId);

      if (!mounted) return;

      // Navigate back to main menu (pop all screens to get back to home)
      Navigator.popUntil(context, (route) => route.isFirst);

      debugPrint('Game aborted successfully, returned to main menu');
    } catch (e) {
      debugPrint('Error aborting game: $e');

      if (!mounted) return;

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error aborting game: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _previousStage() {
    if (currentStageIndex > 0) {
      setState(() {
        currentStageIndex--;
      });
      _resetTimer();
      _startTimer();
    }
  }

  void _nextStage() {
    if (currentStageIndex < nightStages.length - 1) {
      setState(() {
        currentStageIndex++;
      });
      _resetTimer();
      _startTimer();
    }
  }

  void _endNight() {
    debugPrint('Night ${widget.nightNumber} ended');
    debugPrint('Night actions: $nightActions');
    debugPrint('Players at night start: $players');

    // Show night action dialog with submit/close options
    _showNightActionDialog();
  }

  // ✅ Updated night action dialog with SUBMIT/CLOSE
  void _showNightActionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.darkGray,
        title: Text(
          'NIGHT ${widget.nightNumber} ACTIONS',
          style: AppTextStyles.sectionHeaderSmall.copyWith(fontSize: 16),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Night Actions Taken:',
                style: AppTextStyles.bodyTextWhite.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              if (nightActions.isEmpty)
                Text(
                  'No actions were taken this night.',
                  style: AppTextStyles.bodyTextWhite.copyWith(fontSize: 14),
                )
              else
                ...nightActions.entries.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Text(
                    _formatNightAction(entry.key, entry.value),
                    style: AppTextStyles.bodyTextWhite.copyWith(fontSize: 14),
                  ),
                )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              // Return to last stage (where END NIGHT was clicked)
              setState(() {
                currentStageIndex = nightStages.length - 1;
              });
            },
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
              Navigator.pop(context); // Close dialog first
              _submitNightResults(); // Call async method
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

  // ✅ Format night actions for display
  String _formatNightAction(String stageKey, String? target) {
    if (target == null) return '$stageKey: No action';
    if (target == 'SKIP_NIGHT') return '$stageKey: Skipped';

    switch (stageKey) {
      case 'mafia_eliminate':
        return 'Mafia targeted: $target';
      case 'mafia_target_1':
        return 'Mafia targeted (1): $target';
      case 'mafia_target_2':
        return 'Mafia targeted (2): $target';
      case 'detective_action':
        return 'Detective investigated: $target';
      case 'doctor_action':
        return 'Doctor protected: $target';
      case 'serial_killer_action':
        return 'Serial Killer targeted: $target';
      case 'lawyer_defend':
        return 'Lawyer defended: $target';
      case 'interrogator_action':
        return 'Interrogator questioned: $target';
      default:
        return '$stageKey: $target';
    }
  }

  // ✅ Process night resolution and navigate to summary
  Future<void> _submitNightResults() async {
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

      // Process night actions and get results
      final resolutionResult = NightResolver.processNightActions(
        players: players,
        actions: nightActions,
        gameRules: widget.gameRules,
      );

      // ✅ Update Firebase with new player states AND night targets
      await SessionServiceV2.updatePlayersAfterNight(
        sessionId: widget.sessionId,
        updatedPlayers: resolutionResult.updatedPlayers,
        nightNumber: widget.nightNumber,
        nightTargets: nightActions, // ✅ SAVE CURRENT NIGHT TARGETS
      );

      if (!mounted) return;

      // Close loading dialog
      Navigator.pop(context);

      // Navigate to Night Summary Screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => NightSummaryScreen(
            sessionId: widget.sessionId,
            nightNumber: widget.nightNumber,
            eliminationResults: resolutionResult.eliminationResults,
          ),
        ),
      );

      debugPrint('Night ${widget.nightNumber} processed successfully');
    } catch (e) {
      debugPrint('Error processing night results: $e');

      if (!mounted) return;

      // Close loading dialog
      Navigator.pop(context);

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error processing night results: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _timerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Show loading screen while fetching game state
    if (isLoadingGameState) {
      return Scaffold(
        backgroundColor: AppColors.darkGray,
        appBar: AppBar(
          backgroundColor: AppColors.darkGray,
          foregroundColor: AppColors.white,
          title: Text(
            'NIGHT ${widget.nightNumber}',
            style: AppTextStyles.screenTitle,
          ),
          centerTitle: true,
        ),
        body: Center(
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
        ),
      );
    }

    // ✅ Show error if no stages available
    if (nightStages.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.darkGray,
        appBar: AppBar(
          backgroundColor: AppColors.darkGray,
          foregroundColor: AppColors.white,
          title: Text(
            'NIGHT ${widget.nightNumber}',
            style: AppTextStyles.screenTitle,
          ),
          centerTitle: true,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'No night stages available',
                style: AppTextStyles.bodyTextWhite,
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                text: 'BACK TO OVERVIEW',
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      );
    }

    final currentStage = nightStages[currentStageIndex];
    final isLastStage = currentStageIndex == nightStages.length - 1;
    final canProceed = _canProceedToNextStage();

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
          'NIGHT ${widget.nightNumber}',
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
      body: Column(
        children: [
          // Header bar with session ID and stage info
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
                  'Stage ${currentStageIndex + 1} of ${nightStages.length}',
                  style: AppTextStyles.bodyTextWhite.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Current stage info
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  currentStage.roleDisplayName,
                  style: AppTextStyles.sectionHeader.copyWith(fontSize: 28),
                ),
                const SizedBox(height: 10),
                Text(
                  currentStage.instructions,
                  style: AppTextStyles.bodyText.copyWith(fontSize: 18),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // Countdown timer
          _buildCountdownTimer(),

          // Player selection list
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _buildSelectionList().length,
              itemBuilder: (context, index) {
                final item = _buildSelectionList()[index];
                return item;
              },
            ),
          ),

          // Bottom buttons
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Previous button
                Expanded(
                  child: PrimaryButton(
                    text: 'PREVIOUS',
                    height: 50,
                    fontSize: 18,
                    onPressed: currentStageIndex > 0 ? _previousStage : null,
                  ),
                ),
                const SizedBox(width: 16),
                // Next/End Night button
                Expanded(
                  child: PrimaryButton(
                    text: isLastStage ? 'END NIGHT' : 'NEXT',
                    height: 50,
                    fontSize: 18,
                    onPressed: canProceed ? (isLastStage ? _endNight : _nextStage) : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSelectionList() {
    final currentStage = nightStages[currentStageIndex];
    final availablePlayers = _getAvailablePlayersForStage(currentStage.stageKey);
    List<Widget> items = [];

    // Handle selection display for Mafia Wife bonus
    String? selectedPlayer;
    List<String> selectedPlayers = [];

    if (currentStage.stageKey == 'mafia_eliminate' && mafiaExtraKills > 0) {
      // Mafia Wife bonus - track multiple selections
      if (nightActions['mafia_target_1'] != null) {
        selectedPlayers.add(nightActions['mafia_target_1']!);
      }
      if (nightActions['mafia_target_2'] != null) {
        selectedPlayers.add(nightActions['mafia_target_2']!);
      }
    } else {
      // Normal single selection
      selectedPlayer = nightActions[currentStage.stageKey];
      if (selectedPlayer != null) {
        selectedPlayers.add(selectedPlayer);
      }
    }

    // Only show players if role is alive
    if (availablePlayers.isNotEmpty) {
      // Add "Skip Night" options for Mafia stage if rule is active
      if (currentStage.stageKey == 'mafia_eliminate' &&
          (widget.gameRules['Mafia Night Skip'] ?? false)) {

        if (mafiaExtraKills > 0) {
          // Mafia Wife bonus - show individual skip options
          final target1Selected = nightActions['mafia_target_1'];
          final target2Selected = nightActions['mafia_target_2'];

          items.add(_buildPlayerTile(
            playerName: 'Skip Target 1',
            isSelected: target1Selected == 'SKIP_NIGHT',
            isDisabled: false,
            onTap: () => _selectPlayer('SKIP_TARGET_1'),
            isBold: true,
          ));

          items.add(_buildPlayerTile(
            playerName: 'Skip Target 2',
            isSelected: target2Selected == 'SKIP_NIGHT',
            isDisabled: false,
            onTap: () => _selectPlayer('SKIP_TARGET_2'),
            isBold: true,
          ));
        } else {
          // Normal skip
          final isSkipSelected = selectedPlayers.contains('SKIP_NIGHT');
          items.add(_buildPlayerTile(
            playerName: 'Skip Night',
            isSelected: isSkipSelected,
            isDisabled: false,
            onTap: () => _selectPlayer('SKIP_NIGHT'),
            isBold: true,
          ));
        }
      }

      // Add regular players
      for (final player in availablePlayers) {
        final playerDisplayName = _getPlayerRoleDisplay(player, currentStage.stageKey);
        final playerName = player['name'] ?? 'Unknown';
        final isSelected = selectedPlayers.contains(playerName);
        final wasTargetedPreviously = currentStage.cannotRepeatTarget &&
            _wasPlayerTargetedPreviousNight(playerName, currentStage.stageKey);

        items.add(_buildPlayerTile(
          playerName: playerDisplayName,
          isSelected: isSelected,
          isDisabled: wasTargetedPreviously,
          onTap: wasTargetedPreviously ? null : () => _selectPlayer(playerName),
        ));
      }
    }

    return items;
  }

  Widget _buildPlayerTile({
    required String playerName,
    required bool isSelected,
    required bool isDisabled,
    VoidCallback? onTap,
    bool isBold = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primaryOrange.withValues(alpha: 0.3)
                  : isDisabled
                  ? Colors.grey.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? AppColors.primaryOrange
                    : isDisabled
                    ? Colors.grey.withValues(alpha: 0.5)
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
                      fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                      color: isDisabled
                          ? AppColors.white.withValues(alpha: 0.5)
                          : AppColors.white,
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle,
                    color: AppColors.primaryOrange,
                    size: 24,
                  ),
                if (isDisabled && !isSelected)
                  Icon(
                    Icons.block,
                    color: Colors.grey.withValues(alpha: 0.7),
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Helper class to represent a night stage
class NightStage {
  final String stageName;
  final String roleDisplayName;
  final String instructions;
  final String stageKey; // For storing actions
  final bool cannotRepeatTarget;
  final bool isScumCombined; // Whether this stage includes multiple scum roles

  NightStage({
    required this.stageName,
    required this.roleDisplayName,
    required this.instructions,
    required this.stageKey,
    required this.cannotRepeatTarget,
    required this.isScumCombined,
  });
}