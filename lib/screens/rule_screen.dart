import 'package:flutter/material.dart';
import '../components/app_colors.dart';
import '../components/buttons/primary_button.dart';
import '../data/role.dart';
import 'qr_screen.dart';
import '../components/app_text_styles.dart';

class RuleScreen extends StatefulWidget {
  final String sessionId;
  final int expectedPlayers;
  final List<Role> selectedRoles;
  final Map<String, int> roleCounts;

  const RuleScreen({
    super.key,
    required this.sessionId,
    required this.expectedPlayers,
    required this.selectedRoles,
    required this.roleCounts,
  });

  @override
  State<RuleScreen> createState() => _RuleScreenState();
}

class _RuleScreenState extends State<RuleScreen> {
  // Map to store rule states (rule name -> enabled/disabled)
  Map<String, bool> ruleStates = {};

  // Define your game rules here
  final List<GameRule> allRules = [
    GameRule(
      name: 'Mafia Night Skip',
      description: 'Allow mafia members to skip a night phase',
      defaultValue: false,
      isAlwaysAvailable: true,
    ),
    GameRule(
      name: 'Reveal Roles on Death',
      description: 'Show player roles when they are eliminated',
      defaultValue: false,
      isAlwaysAvailable: true,
    ),
    GameRule(
      name: 'Super Grandma',
      description: 'Grandma\'s kill overrides any protection.',
      defaultValue: false,
      requiredRoles: ['grandma_with_gun'], // Use the actual role name, not display name
      isAlwaysAvailable: false,
    ),
    GameRule(
      name: 'Serial Killer Night Skip',
      description: 'Allow serial killer to skip a night phase',
      defaultValue: false,
      requiredRoles: ['serial_killer'], // Use the actual role name, not display name
      isAlwaysAvailable: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initializeRuleStates();
  }

  void _initializeRuleStates() {
    // Initialize rule states with default values
    for (var rule in allRules) {
      ruleStates[rule.name] = rule.defaultValue;
    }
  }

  List<GameRule> get availableRules {
    return allRules.where((rule) {
      if (rule.isAlwaysAvailable) return true;

      // Check if required roles are selected
      if (rule.requiredRoles != null) {
        return rule.requiredRoles!.any((requiredRole) =>
            widget.selectedRoles.any((role) => role.name == requiredRole)); // Use role.name instead of role.displayName
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkGray, // Match your app's style
      appBar: AppBar(
        backgroundColor: AppColors.darkGray,
        foregroundColor: AppColors.white,
        elevation: 0, // Remove shadow
        surfaceTintColor: Colors.transparent, // Prevent color changes
        scrolledUnderElevation: 0, // Prevent elevation when scrolled under
        title: const Text(
          'GAME RULES',
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
            // Header
            Text(
              'CONFIGURE RULES',
              style: AppTextStyles.sectionHeader.copyWith(
                fontSize: 24,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 20),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    ...availableRules.map((rule) => _buildRuleToggle(rule)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),
            PrimaryButton(
              text: 'CREATE GAME',
              width: 280,
              fontSize: 22,
              onPressed: _onContinuePressed,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRuleToggle(GameRule rule) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primaryOrange.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rule.name,
                  style: AppTextStyles.sectionHeaderSmall.copyWith(
                    fontSize: 16,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  rule.description,
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 12,
                    color: AppColors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Switch.adaptive(
            value: ruleStates[rule.name] ?? rule.defaultValue,
            onChanged: (value) {
              setState(() {
                ruleStates[rule.name] = value;
              });
            },
            activeColor: AppColors.primaryOrange,
            activeTrackColor: AppColors.primaryOrange.withValues(alpha: 0.5),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.grey[600],
          ),
        ],
      ),
    );
  }

  void _onContinuePressed() {
    // Navigate to QR screen with selected rules
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QRScreen(
          sessionId: widget.sessionId,
          expectedPlayers: widget.expectedPlayers,
          gameRules: ruleStates,
          selectedRoles: widget.selectedRoles,
          roleCounts: widget.roleCounts,
        ),
      ),
    );
  }
}

// Data class for game rules
class GameRule {
  final String name;
  final String description;
  final bool defaultValue;
  final bool isAlwaysAvailable;
  final List<String>? requiredRoles;

  GameRule({
    required this.name,
    required this.description,
    required this.defaultValue,
    required this.isAlwaysAvailable,
    this.requiredRoles,
  });
}