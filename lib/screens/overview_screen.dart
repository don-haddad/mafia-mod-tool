import 'package:flutter/material.dart';
import '../components/buttons/primary_button.dart';
import '../components/app_colors.dart';
import '../components/app_text_styles.dart';
import '../components/role_details_dialog.dart';
import '../data/role.dart';
import '../services/session_service.dart';
import 'night_phase_screen.dart';

class OverviewScreen extends StatefulWidget {
  final String sessionId;
  final List<Map<String, dynamic>> players; // Players with assigned roles
  final List<Role> allRoles; // All available roles for dialog
  final Map<String, bool> gameRules; // Game rules from setup

  const OverviewScreen({
    super.key,
    required this.sessionId,
    required this.players,
    required this.allRoles,
    required this.gameRules,
  });

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {

  // Get role object from role name
  Role? _getRoleFromName(String roleName) {
    try {
      return widget.allRoles.firstWhere((role) => role.name == roleName);
    } catch (e) {
      return null;
    }
  }

  // Get role color based on team
  Color _getRoleColor(Team team) {
    switch (team) {
      case Team.town:
        return Colors.blue;
      case Team.scum:
        return Colors.red;
      case Team.independent:
        return Colors.purple;
    }
  }

  // Count alive players
  int get alivePlayersCount {
    return widget.players.where((player) => player['isAlive'] ?? true).length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkGray,
      appBar: AppBar(
        backgroundColor: AppColors.darkGray,
        foregroundColor: AppColors.white,
        elevation: 0, // Remove shadow
        surfaceTintColor: Colors.transparent, // Prevent color changes
        scrolledUnderElevation: 0, // Prevent elevation when scrolled under
        automaticallyImplyLeading: false, // No back button
        title: Text(
          'OVERVIEW',
          style: AppTextStyles.screenTitle,
        ),
        centerTitle: true,
      ),
      body: Column(
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

          // Scrollable players list
          Expanded(
            child: widget.players.isEmpty
                ? Center(
              child: Text(
                'No players found',
                style: AppTextStyles.bodyText,
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: widget.players.length,
              itemBuilder: (context, index) {
                final player = widget.players[index];
                final playerName = player['name'] ?? 'Unknown';
                final roleName = player['role'] ?? 'citizen';
                final role = _getRoleFromName(roleName);
                final isAlive = player['isAlive'] ?? true;

                return _buildPlayerCard(
                  playerName: playerName,
                  role: role,
                  isAlive: isAlive,
                );
              },
            ),
          ),

          // Bottom buttons
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // End Game button (left)
                Expanded(
                  child: PrimaryButton(
                    text: 'END GAME',
                    height: 50,
                    fontSize: 18,
                    onPressed: _onEndGame,
                  ),
                ),
                const SizedBox(width: 16),
                // Night 1 button (right)
                Expanded(
                  child: PrimaryButton(
                    text: 'NIGHT 1',
                    height: 50,
                    fontSize: 18,
                    onPressed: _onStartNight1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerCard({
    required String playerName,
    required Role? role,
    required bool isAlive,
  }) {
    final roleDisplayName = role?.displayName ?? 'Unknown Role';
    final roleColor = role != null ? _getRoleColor(role.team) : Colors.grey;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: isAlive ? 0.1 : 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: roleColor.withValues(alpha: isAlive ? 0.5 : 0.2),
          width: 2,
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
                color: isAlive ? AppColors.white : AppColors.white.withValues(alpha: 0.5),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Role (tappable)
          Expanded(
            flex: 2,
            child: GestureDetector(
              onTap: role != null ? () => _showRoleDetails(role) : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: roleColor.withValues(alpha: isAlive ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: roleColor.withValues(alpha: isAlive ? 0.6 : 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Expanded(
                      child: Text(
                        roleDisplayName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isAlive ? roleColor : roleColor.withValues(alpha: 0.5),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    if (role != null) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.info_outline,
                        size: 14,
                        color: isAlive ? roleColor : roleColor.withValues(alpha: 0.5),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showRoleDetails(Role role) {
    RoleDetailsDialog.show(context, role);
  }

  void _onEndGame() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.darkGray,
        title: const Text(
          'END GAME',
          style: TextStyle(
            color: AppColors.white,
            fontFamily: 'AlfaSlabOne',
            fontSize: 18,
          ),
        ),
        content: const Text(
          'Are you sure you want to end the game?\nThis will return you to the main menu.',
          style: TextStyle(color: AppColors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'CANCEL',
              style: TextStyle(
                color: AppColors.primaryOrange,
                fontFamily: 'AlfaSlabOne',
                fontSize: 12,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog first
              await _endGameAndNavigateHome();
            },
            child: const Text(
              'END GAME',
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
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator.adaptive(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryOrange),
          ),
        ),
      );

      // End the game in Firebase
      await SessionService.endGame(widget.sessionId);

      if (!mounted) return;

      // Close loading dialog
      Navigator.pop(context);

      // Navigate back to main menu (pop all screens to get back to home)
      Navigator.popUntil(context, (route) => route.isFirst);

      debugPrint('Game ended successfully, returned to main menu');
    } catch (e) {
      debugPrint('Error ending game: $e');

      if (!mounted) return;

      // Close loading dialog
      Navigator.pop(context);

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error ending game: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _onStartNight1() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NightPhaseScreen(
          sessionId: widget.sessionId,
          selectedRoles: widget.allRoles,
          nightNumber: 1,
          previousNightTargets: null, // First night has no restrictions
          gameRules: widget.gameRules,
        ),
      ),
    );
  }
}