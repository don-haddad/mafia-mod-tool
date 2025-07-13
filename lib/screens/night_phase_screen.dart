import 'package:flutter/material.dart';
import 'dart:async'; // ✅ Added for timer
import '../components/buttons/primary_button.dart';
import '../components/app_colors.dart';
import '../components/app_text_styles.dart';
import '../data/role.dart';

class NightPhaseScreen extends StatefulWidget {
  final String sessionId;
  final List<Map<String, dynamic>> players;
  final List<Role> selectedRoles;
  final int nightNumber;
  final Map<String, dynamic>? previousNightTargets; // For repeat restrictions
  final Map<String, bool> gameRules; // For Mafia Night Skip rule

  const NightPhaseScreen({
    super.key,
    required this.sessionId,
    required this.players,
    required this.selectedRoles,
    required this.nightNumber,
    this.previousNightTargets,
    required this.gameRules,
  });

  @override
  State<NightPhaseScreen> createState() => _NightPhaseScreenState();
}

class _NightPhaseScreenState extends State<NightPhaseScreen> with TickerProviderStateMixin { // ✅ Added TickerProviderStateMixin
  int currentStageIndex = 0;
  Map<String, String?> nightActions = {}; // stage_key -> target_player_name
  late List<NightStage> nightStages;

  // ✅ Timer properties
  static const int countdownDuration = 3; // Easy to modify (10, 15, 20, 30 seconds)
  late AnimationController _timerController;
  late Animation<double> _timerAnimation;
  Timer? _countdownTimer;
  int _remainingSeconds = countdownDuration;
  bool _timerStarted = false;

  @override
  void initState() {
    super.initState();
    _buildNightStages();
    _initializeTimer(); // ✅ Initialize timer
  }

  // ✅ Initialize timer animation
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

  // ✅ Start countdown timer
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

  // ✅ Reset timer when moving to next stage
  void _resetTimer() {
    _countdownTimer?.cancel();
    _timerController.reset();
    _timerStarted = false;
    _remainingSeconds = countdownDuration;
  }

  // ✅ Custom countdown timer widget
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
                double barWidth = MediaQuery.of(context).size.width - 40; // Account for horizontal margin
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

  // ✅ Helper method for DRY instructions
  String _getInstructionsForRole(String roleName) {
    try {
      final role = widget.selectedRoles.firstWhere((r) => r.name == roleName);
      return role.nightInstructions;
    } catch (e) {
      return 'Choose your action'; // Fallback
    }
  }

  // ✅ NEW: Check if role player is alive for current stage
  bool _isRolePlayerAlive(String stageKey) {
    String roleName;

    // Map stage keys to role names
    switch (stageKey) {
      case 'mafia_eliminate':
      // For mafia stage, check if ANY scum member is alive
        return widget.players.any((player) {
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
    return widget.players.any((player) =>
    (player['isAlive'] ?? true) && (player['role'] ?? '') == roleName
    );
  }

  // ✅ NEW: Check if current stage can proceed
  bool _canProceedToNextStage() {
    final currentStage = nightStages[currentStageIndex];
    final hasSelection = nightActions[currentStage.stageKey] != null;
    final timerFinished = _remainingSeconds <= 0;
    final rolePlayerAlive = _isRolePlayerAlive(currentStage.stageKey);

    // Timer must always be finished
    if (!timerFinished) return false;

    // If role player is dead, only need timer
    if (!rolePlayerAlive) return true;

    // If role player is alive, need both timer AND selection
    return hasSelection;
  }

  // ✅ Updated method using DRY principle
  void _buildNightStages() {
    nightStages = [];
    final rolesWithNightStages = RoleManager.getNightStageRoles(widget.selectedRoles);

    for (Role role in rolesWithNightStages) {
      if (role.name == 'lawyer') {
        // Lawyer participates in both Mafia stage and their own stage
        // But we only add the separate Lawyer stage here
        nightStages.add(NightStage(
          stageName: 'Lawyer Defense',
          roleDisplayName: role.displayName,
          instructions: _getInstructionsForRole('lawyer'), // ✅ DRY from role.dart
          stageKey: 'lawyer_defend',
          cannotRepeatTarget: role.cannotRepeatTarget,
          isScumCombined: false,
        ));
      } else if (role.team == Team.scum && role.hasNightStage) {
        // Handle Mafia stage (combined for all scum)
        if (!nightStages.any((stage) => stage.stageKey == 'mafia_eliminate')) {
          nightStages.add(NightStage(
            stageName: 'Mafia Elimination',
            roleDisplayName: 'MAFIA',
            instructions: _getInstructionsForRole('mafia'), // ✅ DRY from role.dart
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
          instructions: role.nightInstructions, // ✅ DRY from role.dart
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

  // ✅ UPDATED: Get players available for current stage - returns empty if role is dead
  List<Map<String, dynamic>> _getAvailablePlayersForStage(String stageKey) {
    // If role player is dead, return empty list (no players to choose from)
    if (!_isRolePlayerAlive(stageKey)) {
      return [];
    }

    final alivePlayers = widget.players.where((player) => player['isAlive'] ?? true).toList();

    // Special filtering for Mafia stage - exclude all scum members
    if (stageKey == 'mafia_eliminate') {
      return alivePlayers.where((player) {
        final roleName = player['role'] ?? '';
        final role = RoleManager.getRoleByName(roleName);

        // Exclude all scum team members
        return role != null && role.team != Team.scum;
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
    setState(() {
      nightActions[nightStages[currentStageIndex].stageKey] = playerName;
    });

    // Handle Detective investigation result
    if (nightStages[currentStageIndex].stageKey == 'detective_action') {
      _showDetectiveResult(playerName);
    }
  }

  void _selectMafiaSkip() {
    setState(() {
      nightActions[nightStages[currentStageIndex].stageKey] = 'SKIP_NIGHT';
    });
  }

  void _showDetectiveResult(String targetPlayerName) {
    final targetPlayer = widget.players.firstWhere((p) => p['name'] == targetPlayerName);
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
              Navigator.pop(context); // Close dialog
              // TODO: Add SessionService.endGame() call here
              Navigator.popUntil(context, (route) => route.isFirst);
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

  // ✅ Updated to reset timer
  void _previousStage() {
    if (currentStageIndex > 0) {
      setState(() {
        currentStageIndex--;
      });
      _resetTimer();
      _startTimer(); // Start timer for previous stage
    }
  }

  // ✅ Updated to reset timer
  void _nextStage() {
    if (currentStageIndex < nightStages.length - 1) {
      setState(() {
        currentStageIndex++;
      });
      _resetTimer();
      _startTimer(); // Start timer for next stage
    }
  }

  void _endNight() {
    // TODO: Navigate to Night Summary screen
    debugPrint('Night ${widget.nightNumber} ended');
    debugPrint('Night actions: $nightActions');

    // TODO: Navigate to NightSummaryScreen
    // Navigator.push(
    //   context,
    //   MaterialPageRoute(
    //     builder: (context) => NightSummaryScreen(
    //       sessionId: widget.sessionId,
    //       nightNumber: widget.nightNumber,
    //       nightActions: nightActions,
    //       players: widget.players,
    //     ),
    //   ),
    // );
  }

  // ✅ Dispose of timer resources
  @override
  void dispose() {
    _countdownTimer?.cancel();
    _timerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentStage = nightStages[currentStageIndex];
    final isLastStage = currentStageIndex == nightStages.length - 1;
    // ✅ NEW: Use new logic for button enabling
    final canProceed = _canProceedToNextStage();

    return Scaffold(
      backgroundColor: AppColors.darkGray,
      appBar: AppBar(
        backgroundColor: AppColors.darkGray,
        foregroundColor: AppColors.white,
        automaticallyImplyLeading: false,
        elevation: 0, // Remove shadow
        surfaceTintColor: Colors.transparent, // Prevent color changes
        scrolledUnderElevation: 0, // Prevent elevation when scrolled under
        title: Text(
          'NIGHT ${widget.nightNumber}',
          style: AppTextStyles.screenTitle,
        ),
        centerTitle: true,
        actions: [
          // Abort game button in top right
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

          // ✅ Countdown timer (placed under instructions)
          _buildCountdownTimer(),

          // Player selection list (pushed down 10 pixels with SizedBox)
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
                // ✅ UPDATED: Next/End Night button with new logic
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
    final selectedPlayer = nightActions[currentStage.stageKey];
    final availablePlayers = _getAvailablePlayersForStage(currentStage.stageKey);
    List<Widget> items = [];

    // ✅ Only show players if role is alive (availablePlayers will be empty if role is dead)
    if (availablePlayers.isNotEmpty) {
      // Add "Skip Night" option for Mafia stage if rule is active
      if (currentStage.stageKey == 'mafia_eliminate' &&
          (widget.gameRules['Mafia Night Skip'] ?? false)) {
        final isSkipSelected = selectedPlayer == 'SKIP_NIGHT';
        items.add(_buildPlayerTile(
          playerName: 'Skip Night',
          isSelected: isSkipSelected,
          isDisabled: false,
          onTap: _selectMafiaSkip,
          isBold: true,
        ));
      }

      // Add regular players
      for (final player in availablePlayers) {
        final playerDisplayName = _getPlayerRoleDisplay(player, currentStage.stageKey);
        final playerName = player['name'] ?? 'Unknown';
        final isSelected = selectedPlayer == playerName;
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
    // ✅ If availablePlayers is empty (role is dead), items list stays empty = no UI elements shown

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