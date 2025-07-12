import 'package:flutter/material.dart';
import '../utils/session_generator.dart';
import '../utils/balance_manager.dart';
import '../components/buttons/primary_button.dart';
import '../components/app_colors.dart';
import '../components/role_details_dialog.dart';
import '../data/role.dart';
import 'rule_screen.dart';

class HostScreen extends StatefulWidget {
  const HostScreen({super.key});

  @override
  State<HostScreen> createState() => _HostScreenState();
}

class _HostScreenState extends State<HostScreen> {
  String sessionId = '';
  Map<String, int> roleCounts = {};
  bool isBalanced = false;
  List<BalanceIssue> balanceIssues = [];
  Map<String, int> suggestedBalance = {};

  @override
  void initState() {
    super.initState();
    _generateSessionId();
    _initializeRoles();
  }

  void _generateSessionId() {
    sessionId = SessionGenerator.generateSessionId();
  }

  void _initializeRoles() {
    roleCounts = RoleManager.getDefaultRoleCounts();
    _checkBalance();
  }

  void _checkBalance() {
    isBalanced = BalanceManager.isBalanced(roleCounts);
    balanceIssues = BalanceManager.getBalanceIssues(roleCounts);
    if (!isBalanced) {
      int totalPlayers = RoleManager.getTotalPlayerCount(roleCounts);
      suggestedBalance = BalanceManager.getSuggestedBalance(totalPlayers);
    }
    setState(() {});
  }

  void _updateRoleCount(String roleName, int change) {
    Role role = RoleManager.availableRoles.firstWhere((r) => r.name == roleName);
    int currentCount = roleCounts[roleName] ?? 0;
    int newCount = currentCount + change;

    // Don't allow going below minimum
    if (newCount < role.minCount) return;
    if (newCount > role.maxCount) return;

    roleCounts[roleName] = newCount;
    _checkBalance();
  }

  int get totalPlayers => RoleManager.getTotalPlayerCount(roleCounts);

  // Helper method to get selected roles (roles with count > 0)
  List<Role> get selectedRoles {
    List<Role> roles = [];
    roleCounts.forEach((roleName, count) {
      if (count > 0) {
        Role role = RoleManager.availableRoles.firstWhere((r) => r.name == roleName);
        roles.add(role);
      }
    });
    return roles;
  }

  // New method to navigate to rule screen
  void _navigateToRuleScreen() {
    if (selectedRoles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one role before continuing'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RuleScreen(
          sessionId: sessionId,
          expectedPlayers: totalPlayers,
          selectedRoles: selectedRoles,
          roleCounts: roleCounts,
        ),
      ),
    );
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
        title: const Text(
          'HOST SETUP',
          style: TextStyle(
            fontFamily: 'AlfaSlabOne',
            letterSpacing: 2.0,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Total Players Display
            _buildTotalPlayersDisplay(),
            const SizedBox(height: 20),

            // Roles Header
            const Text(
              'ROLES',
              style: TextStyle(
                fontSize: 24,
                fontFamily: 'AlfaSlabOne',
                color: AppColors.white,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 20),

            // Roles List
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    ...RoleManager.availableRoles.map((role) => _buildRoleRow(role)),
                  ],
                ),
              ),
            ),

            // Balance Warning/Status
            if (!isBalanced) _buildBalanceWarning(),
            const SizedBox(height: 20),

            // Start Button - Updated to navigate to rule screen
            PrimaryButton(
              text: 'CONTINUE',
              width: 280,
              fontSize: 22,
              onPressed: isBalanced ? _navigateToRuleScreen : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalPlayersDisplay() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primaryOrange, width: 2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'TOTAL PLAYERS',
            style: TextStyle(
              fontSize: 24,
              fontFamily: 'AlfaSlabOne',
              color: AppColors.white,
              letterSpacing: 1.0,
            ),
          ),
          Text(
            '$totalPlayers',
            style: const TextStyle(
              fontSize: 28,
              fontFamily: 'AlfaSlabOne',
              color: AppColors.primaryOrange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleRow(Role role) {
    int count = roleCounts[role.name] ?? 0;
    Color roleColor = _getRoleColor(role.team);

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: roleColor.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        children: [
          // Role info (clickable)
          Expanded(
            child: GestureDetector(
              onTap: () => RoleDetailsDialog.show(context, role),
              child: Row(
                children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        role.displayName,
                        style: TextStyle(
                          fontSize: 18,
                          fontFamily: 'AlfaSlabOne',
                          color: roleColor,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: roleColor.withValues(alpha: 0.6),
                  ),
                ],
              ),
            ),
          ),

// Replace the existing Row widget in your _buildRoleRow method with this:
          Row(
            children: [
              // Decrement button using Material 3 IconButton.filledTonal
              IconButton.filledTonal(
                onPressed: count > role.minCount ? () => _updateRoleCount(role.name, -1) : null,
                icon: const Icon(Icons.remove),
                style: IconButton.styleFrom(
                  backgroundColor: roleColor.withValues(alpha: 0.12),
                  foregroundColor: roleColor,
                  disabledBackgroundColor: Colors.grey.withValues(alpha: 0.12),
                  disabledForegroundColor: Colors.grey,
                ),
              ),
              const SizedBox(width: 4),

              // Count display with matching Material 3 styling
              Container(
                width: 50,
                height: 48,
                decoration: BoxDecoration(
                  color: roleColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: roleColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),

              // Increment button using Material 3 IconButton.filledTonal
              IconButton.filledTonal(
                onPressed: count < role.maxCount ? () => _updateRoleCount(role.name, 1) : null,
                icon: const Icon(Icons.add),
                style: IconButton.styleFrom(
                  backgroundColor: roleColor.withValues(alpha: 0.12),
                  foregroundColor: roleColor,
                  disabledBackgroundColor: Colors.grey.withValues(alpha: 0.12),
                  disabledForegroundColor: Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceWarning() {
    if (balanceIssues.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning, color: Colors.red, size: 20),
              SizedBox(width: 10),
              Text(
                'GAME BALANCE ISSUES',
                style: TextStyle(
                  fontSize: 14,
                  fontFamily: 'AlfaSlabOne',
                  color: Colors.red,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // List all balance issues
          ...balanceIssues.map((issue) => Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: TextStyle(color: Colors.red, fontSize: 12)),
                Expanded(
                  child: Text(
                    issue.message,
                    style: const TextStyle(fontSize: 12, color: Colors.red),
                  ),
                ),
              ],
            ),
          )),

          const SizedBox(height: 15),
          Center(
            child: TextButton(
              onPressed: () {
                setState(() {
                  roleCounts = Map.from(suggestedBalance);
                  _checkBalance();
                });
              },
              child: const Text(
                'USE SUGGESTED BALANCE',
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'AlfaSlabOne',
                  color: Colors.red,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

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
}