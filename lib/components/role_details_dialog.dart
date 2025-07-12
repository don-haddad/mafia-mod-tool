import 'package:flutter/material.dart';
import '../data/role.dart';
import '../components/app_colors.dart';

class RoleDetailsDialog extends StatelessWidget {
  final Role role;

  const RoleDetailsDialog({
    super.key,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    Color roleColor = _getRoleColor(role.team);

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.darkGray,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: roleColor, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              spreadRadius: 5,
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with role name and team
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        role.displayName,
                        style: TextStyle(
                          fontSize: 24,
                          fontFamily: 'AlfaSlabOne',
                          color: roleColor,
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: roleColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: roleColor.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          _getTeamName(role.team),
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'AlfaSlabOne',
                            color: roleColor,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: AppColors.white),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Description
            _buildSection(
              'DESCRIPTION',
              role.description,
              Colors.white,
            ),
            const SizedBox(height: 20),

            // Abilities
            _buildSection(
              'ABILITIES',
              role.abilities,
              roleColor,
            ),
            const SizedBox(height: 20),

            // Win Condition
            _buildSection(
              'WIN CONDITION',
              role.winCondition,
              Colors.amber,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontFamily: 'AlfaSlabOne',
            color: color,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          content,
          style: const TextStyle(
            fontSize: 16,
            color: AppColors.white,
            height: 1.5,
          ),
        ),
      ],
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

  String _getTeamName(Team team) {
    switch (team) {
      case Team.town:
        return 'TOWN';
      case Team.scum:
        return 'SCUM';
      case Team.independent:
        return 'INDEPENDENT';
    }
  }

  static void show(BuildContext context, Role role) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => RoleDetailsDialog(role: role),
    );
  }
}