enum Team {
  town,
  scum,
  independent,
}

class Role {
  final String name;
  final String displayName;
  final Team team;
  final int minCount;
  final int defaultCount;
  final int maxCount;
  final String portrait;
  final String description;
  final String abilities;
  final String winCondition;

  // Night stage properties
  final bool hasNightStage;
  final int nightStageOrder; // 0 = no night stage, 1-6 for order
  final String nightInstructions;
  final bool cannotRepeatTarget; // for "twice in a row" restrictions

  const Role({
    required this.name,
    required this.displayName,
    required this.team,
    required this.minCount,
    required this.defaultCount,
    required this.maxCount,
    required this.portrait,
    required this.description,
    required this.abilities,
    required this.winCondition,
    required this.hasNightStage,
    required this.nightStageOrder,
    required this.nightInstructions,
    required this.cannotRepeatTarget,
  });
}

class RoleManager {
  static const List<Role> availableRoles = [
    Role(
      name: 'mafia',
      displayName: 'MAFIA',
      team: Team.scum,
      minCount: 1,
      defaultCount: 2,
      maxCount: 5,
      portrait: 'assets/images/mafia_portrait.svg',
      description: 'Basic scum member who eliminates town',
      abilities: 'Can vote to eliminate one player each night. Cannot eliminate the same player twice in a row.',
      winCondition: 'Eliminate all Town members or achieve parity',
      hasNightStage: true,
      nightStageOrder: 1,
      nightInstructions: 'Wake up, and choose a player to eliminate',
      cannotRepeatTarget: true,
    ),
    Role(
      name: 'citizen',
      displayName: 'CITIZEN',
      team: Team.town,
      minCount: 2,
      defaultCount: 3,
      maxCount: 10,
      portrait: 'assets/images/citizen_portrait.svg',
      description: 'Basic town member with no special abilities',
      abilities: 'No special abilities. Can only vote during day phase.',
      winCondition: 'Eliminate all Scum and Independent threats',
      hasNightStage: false,
      nightStageOrder: 0,
      nightInstructions: '',
      cannotRepeatTarget: false,
    ),
    Role(
      name: 'detective',
      displayName: 'DETECTIVE',
      team: Team.town,
      minCount: 0,
      defaultCount: 1,
      maxCount: 2,
      portrait: 'assets/images/detective_portrait.svg',
      description: 'Can investigate players to learn their alignment',
      abilities: 'Each night, can investigate one player to learn if they are Town or Scum. Cannot detect Independents. Cannot investigate the same player twice in a row.',
      winCondition: 'Eliminate all Scum and Independent threats',
      hasNightStage: true,
      nightStageOrder: 4,
      nightInstructions: 'Wake up, and choose a player to investigate',
      cannotRepeatTarget: true,
    ),
    Role(
      name: 'doctor',
      displayName: 'DOCTOR',
      team: Team.town,
      minCount: 0,
      defaultCount: 1,
      maxCount: 2,
      portrait: 'assets/images/doctor_portrait.svg',
      description: 'Can protect players from elimination',
      abilities: 'Each night, can protect themselves or another player from being eliminated. Cannot protect the same player twice in a row.',
      winCondition: 'Eliminate all Scum and Independent threats',
      hasNightStage: true,
      nightStageOrder: 6,
      nightInstructions: 'Wake up, and choose a player to protect',
      cannotRepeatTarget: true,
    ),
    Role(
      name: 'grandma_with_gun',
      displayName: 'GRANDMA',
      team: Team.town,
      minCount: 0,
      defaultCount: 0,
      maxCount: 1,
      portrait: 'assets/images/grandma_portrait.svg',
      description: 'Elderly town member who defends herself fiercely at night',
      abilities: 'Automatically kills any player who visits her during the night phase. Can only be killed by vote. When Mafia team visits Grandma, a random Mafia member is killed. Grandma Kill Can not be protected.',
      winCondition: 'Eliminate all Scum and Independent threats',
      hasNightStage: false,
      nightStageOrder: 0,
      nightInstructions: '',
      cannotRepeatTarget: false,
    ),
    Role(
      name: 'vigilante',
      displayName: 'VIGILANTE',
      team: Team.town,
      minCount: 0,
      defaultCount: 0,
      maxCount: 1,
      portrait: 'assets/images/vigilante_portrait.svg',
      description: 'Town member with a single bullet gun.',
      abilities: 'Can choose to eliminate one player during day. Dies if target is Town.',
      winCondition: 'Eliminate all Scum and Independent threats',
      hasNightStage: false,
      nightStageOrder: 0,
      nightInstructions: '',
      cannotRepeatTarget: false,
    ),
    Role(
      name: 'serial_killer',
      displayName: 'SERIAL KILLER',
      team: Team.independent,
      minCount: 0,
      defaultCount: 0,
      maxCount: 1,
      portrait: 'assets/images/serial_killer_portrait.svg',
      description: 'Independent killer who must eliminate everyone',
      abilities: 'Each night, must eliminate one player. Town cannot win while Serial Killer is alive.',
      winCondition: 'Be the last player standing',
      hasNightStage: true,
      nightStageOrder: 2,
      nightInstructions: 'Wake up, and choose a player to eliminate',
      cannotRepeatTarget: true,
    ),
    Role(
      name: 'godfather',
      displayName: 'GODFATHER',
      team: Team.scum,
      minCount: 0,
      defaultCount: 0,
      maxCount: 1,
      portrait: 'assets/images/godfather_portrait.svg',
      description: 'Leader of the Mafia who appears innocent',
      abilities: 'Appears as Town to Detective investigations. Can override Mafia elimination votes.',
      winCondition: 'Eliminate all Town members or achieve parity',
      hasNightStage: false, // Godfather participates in Mafia stage
      nightStageOrder: 0,
      nightInstructions: '',
      cannotRepeatTarget: false,
    ),
    Role(
      name: 'lawyer',
      displayName: 'LAWYER',
      team: Team.scum,
      minCount: 0,
      defaultCount: 0,
      maxCount: 1,
      portrait: 'assets/images/lawyer_portrait.svg',
      description: 'Scum member who can protect other scum',
      abilities: 'Each night, can protect one Scum member from investigation. Cannot protect the same player twice in a row.',
      winCondition: 'Eliminate all Town members or achieve parity',
      hasNightStage: true,
      nightStageOrder: 3,
      nightInstructions: 'Wake up, and choose a player to defend',
      cannotRepeatTarget: true,
    ),
    Role(
      name: 'judge',
      displayName: 'JUDGE',
      team: Team.town,
      minCount: 0,
      defaultCount: 0,
      maxCount: 1,
      portrait: 'assets/images/judge_portrait.svg',
      description: 'Town member with enhanced voting power',
      abilities: 'Reveals role to override a vote during day phase',
      winCondition: 'Eliminate all Scum and Independent threats',
      hasNightStage: false,
      nightStageOrder: 0,
      nightInstructions: '',
      cannotRepeatTarget: false,
    ),
    Role(
      name: 'mafia_wife',
      displayName: 'MAFIA WIFE',
      team: Team.scum,
      minCount: 0,
      defaultCount: 0,
      maxCount: 1,
      portrait: 'assets/images/mafia_wife_portrait.svg',
      description: 'Scum member who becomes dangerous when widowed',
      abilities: 'If eliminated, Mafia gets two kills for next night. Appears as Town to Detective investigations.',
      winCondition: 'Eliminate all Town members or achieve parity',
      hasNightStage: false, // Participates in Mafia stage
      nightStageOrder: 0,
      nightInstructions: '',
      cannotRepeatTarget: false,
    ),
    Role(
      name: 'clown',
      displayName: 'CLOWN',
      team: Team.town,
      minCount: 0,
      defaultCount: 0,
      maxCount: 1,
      portrait: 'assets/images/clown_portrait.svg',
      description: 'Town member who causes chaos',
      abilities: 'Reveals role, and forces one player to reveal their role with them.',
      winCondition: 'Eliminate all Scum and Independent threats',
      hasNightStage: false,
      nightStageOrder: 0,
      nightInstructions: '',
      cannotRepeatTarget: false,
    ),
    Role(
      name: 'miller',
      displayName: 'MILLER',
      team: Team.town,
      minCount: 0,
      defaultCount: 0,
      maxCount: 2,
      portrait: 'assets/images/miller_portrait.svg',
      description: 'Town member who appears guilty to investigations',
      abilities: 'Appears as Scum to Detective investigations despite being Town.',
      winCondition: 'Eliminate all Scum and Independent threats',
      hasNightStage: false,
      nightStageOrder: 0,
      nightInstructions: '',
      cannotRepeatTarget: false,
    ),
    Role(
      name: 'interrogator',
      displayName: 'INTERROGATOR',
      team: Team.town,
      minCount: 0,
      defaultCount: 0,
      maxCount: 1,
      portrait: 'assets/images/interrogator_portrait.svg',
      description: 'Town member who can force information',
      abilities: 'Each night, can interrogate one player to learn their role. moderator can have signs designated ahead of time to quietly signal which role a player is.',
      winCondition: 'Eliminate all Scum and Independent threats',
      hasNightStage: true,
      nightStageOrder: 5,
      nightInstructions: 'Wake up, and choose a player to interrogate',
      cannotRepeatTarget: true,
    ),
  ];

  static Map<String, int> getDefaultRoleCounts() {
    Map<String, int> counts = {};
    for (Role role in availableRoles) {
      counts[role.name] = role.defaultCount;
    }
    return counts;
  }

  static int getTotalPlayerCount(Map<String, int> roleCounts) {
    return roleCounts.values.fold(0, (sum, count) => sum + count);
  }

  static Role? getRoleByName(String name) {
    try {
      return availableRoles.firstWhere((role) => role.name == name);
    } catch (e) {
      return null;
    }
  }

  static List<Role> getRolesByTeam(Team team) {
    return availableRoles.where((role) => role.team == team).toList();
  }

  // New helper methods for night stages
  static List<Role> getNightStageRoles(List<Role> selectedRoles) {
    return selectedRoles
        .where((role) => role.hasNightStage)
        .toList()
      ..sort((a, b) => a.nightStageOrder.compareTo(b.nightStageOrder));
  }

  static bool hasAnyNightStages(List<Role> selectedRoles) {
    return selectedRoles.any((role) => role.hasNightStage);
  }
}