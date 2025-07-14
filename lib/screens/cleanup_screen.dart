import 'package:flutter/material.dart';
import '../components/buttons/primary_button.dart';
import '../components/app_colors.dart';
import '../components/app_text_styles.dart';
import '../services/session_service_v2.dart';

class CleanupScreen extends StatefulWidget {
  const CleanupScreen({super.key});

  @override
  State<CleanupScreen> createState() => _CleanupScreenState();
}

class _CleanupScreenState extends State<CleanupScreen> {
  Map<String, int> _stats = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      final stats = await SessionServiceV2.getCleanupStats();
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Error loading stats: $e');
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _cleanupStaleSessions() async {
    setState(() => _isLoading = true);
    try {
      await SessionServiceV2.cleanupStaleSessions();
      _showSuccess('Stale sessions cleaned up successfully!');
      await _loadStats(); // Refresh stats
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Error cleaning up stale sessions: $e');
    }
  }

  Future<void> _cleanupOldSessions() async {
    // Show confirmation dialog first
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.darkGray,
        title: Text(
          'CLEANUP OLD SESSIONS',
          style: TextStyle(
            color: AppColors.white,
            fontFamily: 'AlfaSlabOne',
            fontSize: 16,
          ),
        ),
        content: Text(
          'This will delete completed sessions older than 90 days.\nAnalytics data will be preserved.\n\nContinue?',
          style: TextStyle(color: AppColors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
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
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'DELETE',
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

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      final deletedCount = await SessionServiceV2.cleanupOldCompletedSessions();
      _showSuccess('Deleted $deletedCount old completed sessions');
      await _loadStats(); // Refresh stats
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Error cleaning up old sessions: $e');
    }
  }

  Future<void> _emergencyCleanup() async {
    // Show strong confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.darkGray,
        title: Text(
          '⚠️ EMERGENCY CLEANUP',
          style: TextStyle(
            color: Colors.red,
            fontFamily: 'AlfaSlabOne',
            fontSize: 16,
          ),
        ),
        content: Text(
          'WARNING: This will delete ALL active and completed sessions!\n\nOnly analytics data will be preserved.\n\nThis action cannot be undone!\n\nAre you absolutely sure?',
          style: TextStyle(color: AppColors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
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
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'DELETE ALL',
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

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      final result = await SessionServiceV2.emergencyCleanupAll();
      _showSuccess('EMERGENCY CLEANUP: Deleted ${result['deletedActive']} active + ${result['deletedCompleted']} completed sessions');
      await _loadStats(); // Refresh stats
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Error in emergency cleanup: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkGray,
      appBar: AppBar(
        backgroundColor: AppColors.darkGray,
        foregroundColor: AppColors.white,
        title: Text(
          'DATABASE CLEANUP',
          style: AppTextStyles.screenTitle,
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator.adaptive(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryOrange),
            ),
            const SizedBox(height: 20),
            Text(
              'Processing...',
              style: AppTextStyles.bodyTextWhite,
            ),
          ],
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Stats Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primaryOrange.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DATABASE STATISTICS',
                    style: AppTextStyles.sectionHeader.copyWith(fontSize: 18),
                  ),
                  const SizedBox(height: 15),
                  _buildStatRow('Active Sessions:', _stats['activeSessions'] ?? 0),
                  _buildStatRow('Stale Sessions (24h+):', _stats['staleSessions'] ?? 0,
                      color: (_stats['staleSessions'] ?? 0) > 0 ? Colors.orange : null),
                  _buildStatRow('Completed Sessions:', _stats['completedSessions'] ?? 0),
                  _buildStatRow('Analytics Records:', _stats['analyticsRecords'] ?? 0,
                      color: Colors.green),
                  const SizedBox(height: 15),
                  Center(
                    child: TextButton(
                      onPressed: _loadStats,
                      child: Text(
                        'REFRESH STATS',
                        style: TextStyle(
                          color: AppColors.primaryOrange,
                          fontFamily: 'AlfaSlabOne',
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // Cleanup Buttons
            PrimaryButton(
              text: 'CLEANUP STALE SESSIONS',
              width: 300,
              fontSize: 14,
              onPressed: (_stats['staleSessions'] ?? 0) > 0 ? _cleanupStaleSessions : null,
            ),
            const SizedBox(height: 10),
            Text(
              'Removes sessions not updated for 24+ hours',
              style: AppTextStyles.bodyText.copyWith(fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),

            PrimaryButton(
              text: 'CLEANUP OLD COMPLETED',
              fontSize: 14,
              width: 300,
              onPressed: (_stats['completedSessions'] ?? 0) > 0 ? _cleanupOldSessions : null,
            ),
            const SizedBox(height: 10),
            Text(
              'Removes completed sessions older than 90 days\n(Analytics preserved)',
              style: AppTextStyles.bodyText.copyWith(fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),

            // Emergency Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.red.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.warning,
                    color: Colors.red,
                    size: 32,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'EMERGENCY CLEANUP',
                    style: AppTextStyles.sectionHeader.copyWith(
                      fontSize: 20,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Deletes ALL sessions (for testing only)',
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 12,
                      color: Colors.red.withValues(alpha: 0.8),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 15),
                  PrimaryButton(
                    text: 'EMERGENCY CLEANUP',
                    fontSize: 14,
                    width: 250,
                    onPressed: ((_stats['activeSessions'] ?? 0) > 0 ||
                        (_stats['completedSessions'] ?? 0) > 0)
                        ? _emergencyCleanup
                        : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, int value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.bodyTextWhite.copyWith(fontSize: 14),
          ),
          Text(
            value.toString(),
            style: AppTextStyles.bodyTextWhite.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color ?? AppColors.primaryOrange,
            ),
          ),
        ],
      ),
    );
  }
}