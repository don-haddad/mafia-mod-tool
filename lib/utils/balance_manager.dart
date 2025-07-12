import '../data/role.dart';

class BalanceManager {
  // Game balance configuration
  static const int minTotalPlayers = 4;
  static const int maxTotalPlayers = 30;
  static const double minScumRatio = 0.20; // 20%
  static const double maxScumRatio = 0.35; // 35%
  static const double idealScumRatio = 0.25; // 25%

  /// Checks if the current role distribution is balanced
  static bool isBalanced(Map<String, int> roleCounts) {
    final analysis = analyzeDistribution(roleCounts);

    // Basic requirements
    if (analysis.totalPlayers < minTotalPlayers) return false;
    if (analysis.totalPlayers > maxTotalPlayers) return false;
    if (analysis.scumCount == 0) return false;
    if (roleCounts['detective'] == 0) return false;

    // Ratio requirements
    if (analysis.scumRatio < minScumRatio || analysis.scumRatio > maxScumRatio) {
      return false;
    }

    // Minimum town requirement (must have at least some town members)
    if (analysis.townCount < 2) return false;

    return true;
  }

  /// Analyzes the current role distribution
  static DistributionAnalysis analyzeDistribution(Map<String, int> roleCounts) {
    int townCount = 0;
    int scumCount = 0;
    int independentCount = 0;

    for (Role role in RoleManager.availableRoles) {
      int count = roleCounts[role.name] ?? 0;
      switch (role.team) {
        case Team.town:
          townCount += count;
          break;
        case Team.scum:
          scumCount += count;
          break;
        case Team.independent:
          independentCount += count;
          break;
      }
    }

    int totalPlayers = townCount + scumCount + independentCount;
    double scumRatio = totalPlayers > 0 ? scumCount / totalPlayers : 0.0;
    double townRatio = totalPlayers > 0 ? townCount / totalPlayers : 0.0;

    return DistributionAnalysis(
      totalPlayers: totalPlayers,
      townCount: townCount,
      scumCount: scumCount,
      independentCount: independentCount,
      scumRatio: scumRatio,
      townRatio: townRatio,
    );
  }

  /// Generates a suggested balanced distribution for a target player count
  static Map<String, int> getSuggestedBalance(int targetPlayerCount) {
    // Clamp to valid range
    targetPlayerCount = targetPlayerCount.clamp(minTotalPlayers, maxTotalPlayers);

    Map<String, int> suggested = {};

    // Calculate scum count based on ideal ratio
    int scumCount = (targetPlayerCount * idealScumRatio).round();
    if (scumCount < 1) scumCount = 1;
    if (scumCount >= targetPlayerCount - 1) scumCount = targetPlayerCount - 2;

    // Always have 1 detective
    int detectiveCount = 1;

    // Add doctor if enough players
    int doctorCount = targetPlayerCount >= 7 ? 1 : 0;

    // Remaining players are citizens
    int citizenCount = targetPlayerCount - scumCount - detectiveCount - doctorCount;

    // Ensure minimum citizen count
    if (citizenCount < 1) {
      citizenCount = 1;
      // Adjust other roles if needed
      if (targetPlayerCount - citizenCount - detectiveCount < 1) {
        doctorCount = 0;
      }
      scumCount = targetPlayerCount - citizenCount - detectiveCount - doctorCount;
    }

    suggested['mafia'] = scumCount;
    suggested['detective'] = detectiveCount;
    suggested['doctor'] = doctorCount;
    suggested['citizen'] = citizenCount;

    return suggested;
  }

  /// Gets specific balance issues for user feedback
  static List<BalanceIssue> getBalanceIssues(Map<String, int> roleCounts) {
    List<BalanceIssue> issues = [];
    final analysis = analyzeDistribution(roleCounts);

    if (analysis.totalPlayers < minTotalPlayers) {
      issues.add(BalanceIssue(
        type: BalanceIssueType.tooFewPlayers,
        message: 'Need at least $minTotalPlayers players (currently ${analysis.totalPlayers})',
      ));
    }

    if (analysis.totalPlayers > maxTotalPlayers) {
      issues.add(BalanceIssue(
        type: BalanceIssueType.tooManyPlayers,
        message: 'Maximum $maxTotalPlayers players allowed (currently ${analysis.totalPlayers})',
      ));
    }

    if (analysis.scumCount == 0) {
      issues.add(BalanceIssue(
        type: BalanceIssueType.noScum,
        message: 'Need at least 1 Mafia member',
      ));
    }

    if (roleCounts['detective'] == 0) {
      issues.add(BalanceIssue(
        type: BalanceIssueType.noDetective,
        message: 'Need at least 1 Detective',
      ));
    }

    if (analysis.scumRatio > maxScumRatio) {
      issues.add(BalanceIssue(
        type: BalanceIssueType.tooManyScum,
        message: 'Too many Mafia members (${(analysis.scumRatio * 100).toInt()}% vs max ${(maxScumRatio * 100).toInt()}%)',
      ));
    }

    if (analysis.scumRatio < minScumRatio && analysis.scumCount > 0) {
      issues.add(BalanceIssue(
        type: BalanceIssueType.tooFewScum,
        message: 'Too few Mafia members (${(analysis.scumRatio * 100).toInt()}% vs min ${(minScumRatio * 100).toInt()}%)',
      ));
    }

    if (analysis.townCount < 2) {
      issues.add(BalanceIssue(
        type: BalanceIssueType.tooFewTown,
        message: 'Need at least 2 Town members',
      ));
    }

    return issues;
  }
}

/// Analysis result for role distribution
class DistributionAnalysis {
  final int totalPlayers;
  final int townCount;
  final int scumCount;
  final int independentCount;
  final double scumRatio;
  final double townRatio;

  const DistributionAnalysis({
    required this.totalPlayers,
    required this.townCount,
    required this.scumCount,
    required this.independentCount,
    required this.scumRatio,
    required this.townRatio,
  });
}

/// Represents a specific balance issue
class BalanceIssue {
  final BalanceIssueType type;
  final String message;

  const BalanceIssue({
    required this.type,
    required this.message,
  });
}

/// Types of balance issues
enum BalanceIssueType {
  tooFewPlayers,
  tooManyPlayers,
  noScum,
  noDetective,
  tooManyScum,
  tooFewScum,
  tooFewTown,
}