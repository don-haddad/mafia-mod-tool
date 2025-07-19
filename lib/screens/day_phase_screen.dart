import 'package:flutter/material.dart';
import '../components/buttons/primary_button.dart';
import '../components/app_colors.dart';
import '../components/app_text_styles.dart';
import '../services/session_service_v2.dart';
import 'vote_phase_screen.dart';
import 'vigilante_screen.dart';
import 'package:flutter_svg/flutter_svg.dart';

class DayPhaseScreen extends StatefulWidget {
  final String sessionId;
  final int dayNumber;

  const DayPhaseScreen({
    super.key,
    required this.sessionId,
    required this.dayNumber,
  });

  @override
  State<DayPhaseScreen> createState() => _DayPhaseScreenState();
}

class _DayPhaseScreenState extends State<DayPhaseScreen> {
  List<Map<String, dynamic>> players = [];
  Set<String> nominatedPlayers = {}; // Track nominated players
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
        setState(() {
          players = allPlayers;
          alivePlayersCount = players.where((player) => player['isAlive'] ?? true).length;
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

  void _togglePlayerNomination(String playerName) {
    setState(() {
      if (nominatedPlayers.contains(playerName)) {
        nominatedPlayers.remove(playerName);
      } else {
        nominatedPlayers.add(playerName);
      }
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

  Future<void> _proceedToVotePhase() async {
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

      // Update nomination status in Firebase
      List<Map<String, dynamic>> updatedPlayers = players.map((player) {
        return {
          ...player,
          'isNominated': nominatedPlayers.contains(player['name']),
        };
      }).toList();

      await SessionServiceV2.updatePlayersNomination(
        sessionId: widget.sessionId,
        updatedPlayers: updatedPlayers,
        dayNumber: widget.dayNumber,
      );

      if (!mounted) return;

      // Close loading dialog
      Navigator.pop(context);

      // Navigate to Vote Phase
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VotePhaseScreen(
            sessionId: widget.sessionId,
            dayNumber: widget.dayNumber,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error proceeding to vote phase: $e');
      if (!mounted) return;

      // Close loading dialog
      Navigator.pop(context);
      _showError('Error proceeding to vote phase: $e');
    }
  }
  // Check if vigilante exists, is alive, and hasn't used ability
  Future<bool> _shouldShowTargetButton() async {
    try {
      final sessionData = await SessionServiceV2.getActiveSession(widget.sessionId);
      if (sessionData == null) return false;

      // Check 1: Does vigilante role exist in game?
      final roleCounts = Map<String, dynamic>.from(sessionData['roleCounts'] ?? {});
      final hasVigilanteRole = (roleCounts['vigilante'] ?? 0) > 0;
      if (!hasVigilanteRole) return false;

      // Check 2: Has vigilante ability been used?
      final vigilanteUsed = sessionData['vigilanteUsed'] ?? false;
      if (vigilanteUsed) return false;

      // Check 3: Is vigilante player alive?
      final players = List<Map<String, dynamic>>.from(sessionData['players'] ?? []);
      final vigilanteAlive = players.any((player) =>
      (player['role'] ?? '') == 'vigilante' &&
          (player['isAlive'] ?? false)
      );

      return vigilanteAlive;
    } catch (e) {
      debugPrint('Error checking target button availability: $e');
      return false;
    }
  }

  void _navigateToVigilanteScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VigilanteScreen(
          sessionId: widget.sessionId,
          dayNumber: widget.dayNumber,
          sourceScreen: 'day_phase',
        ),
      ),
    );
  }

  Widget _buildTargetButton() {
    return Container(
      width: 60, // Same height as primary button
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.primaryGradient, // Use same gradient as primary buttons
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            spreadRadius: 3,
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(30), // Half of width/height for perfect circle
          onTap: _navigateToVigilanteScreen,
          child: Center(
            child: SvgPicture.asset(
              'assets/icon/Eliminate.svg',
              width: 50,
              height: 50,
            ),
          ),
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
        automaticallyImplyLeading: false,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: Text(
          'DAY ${widget.dayNumber}',
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
            child: Text(
              'Select players to nominate for elimination',
              style: AppTextStyles.bodyText.copyWith(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),

          // Player list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _getAlivePlayers().length,
              itemBuilder: (context, index) {
                final player = _getAlivePlayers()[index];
                final playerName = player['name'] ?? 'Unknown';
                final isNominated = nominatedPlayers.contains(playerName);

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _togglePlayerNomination(playerName),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isNominated
                              ? AppColors.primaryOrange.withValues(alpha: 0.3)
                              : Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isNominated
                                ? AppColors.primaryOrange
                                : Colors.white.withValues(alpha: 0.3),
                            width: isNominated ? 2 : 1,
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
                            if (isNominated)
                              Icon(
                                Icons.how_to_vote,
                                color: AppColors.primaryOrange,
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

          // Bottom buttons
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: FutureBuilder<bool>(
              future: _shouldShowTargetButton(),
              builder: (context, snapshot) {
                final showTargetButton = snapshot.data ?? false;

                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Primary Vote button (centered)
                    PrimaryButton(
                      text: 'VOTE DAY ${widget.dayNumber}',
                      width: 240, // Reduced from 280
                      fontSize: 22,
                      onPressed: _proceedToVotePhase,
                    ),

                    // Target button (only show if vigilante available)
                    if (showTargetButton) ...[
                      const SizedBox(width: 20), // 20px spacing
                      _buildTargetButton(),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getAlivePlayers() {
    return players.where((player) => player['isAlive'] ?? true).toList();
  }
}