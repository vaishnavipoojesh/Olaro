import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';

class MiningHistoryScreen extends StatefulWidget {
  const MiningHistoryScreen({super.key});

  @override
  State<MiningHistoryScreen> createState() => _MiningHistoryScreenState();
}

class _MiningHistoryScreenState extends State<MiningHistoryScreen> {
  List<dynamic> _sessions = [];
  Map<String, dynamic>? _pagination;
  Map<String, dynamic>? _summary;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _currentPage = 1;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final result = await ApiService.getMiningHistory(page: 1);
      setState(() {
        _sessions = result['sessions'] ?? [];
        _pagination = result['pagination'];
        _summary = result['summary'];
        _currentPage = 1;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error: $e', isError: true);
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore) return;
    if (_pagination == null) return;
    // Backend returns 'pages' not 'totalPages'
    if (_currentPage >=
        (_pagination!['pages'] ?? _pagination!['totalPages'] ?? 1)) {
      return;
    }

    setState(() => _isLoadingMore = true);
    try {
      final result = await ApiService.getMiningHistory(page: _currentPage + 1);
      setState(() {
        _sessions.addAll(result['sessions'] ?? []);
        _pagination = result['pagination'];
        _currentPage++;
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() => _isLoadingMore = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.cardDark,
        title:
            const Text('Mining History', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHistory,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _loadHistory,
              color: AppColors.primary,
              child: _sessions.isEmpty
                  ? _buildEmptyState()
                  : Column(
                      children: [
                        // Stats Summary
                        _buildStatsSummary(),

                        // Sessions List
                        Expanded(
                          child: ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount:
                                _sessions.length + (_isLoadingMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == _sessions.length) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: CircularProgressIndicator(
                                        color: AppColors.primary),
                                  ),
                                );
                              }
                              return _buildSessionCard(_sessions[index]);
                            },
                          ),
                        ),
                      ],
                    ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.memory, color: AppColors.primary, size: 40),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Mining History',
            style: TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Start mining to see your history here',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSummary() {
    // Use summary from backend API response
    final totalSessions =
        _pagination?['total'] ?? _summary?['totalSessions'] ?? _sessions.length;
    final totalMined = (_summary?['totalCoins'] ?? 0) > 0
        ? (_summary!['totalCoins'] as num).toDouble()
        : _sessions.fold<double>(
            0,
            (sum, s) =>
                sum +
                ((s['coinsEarned'] ?? s['expectedCoins'] ?? 0) as num)
                    .toDouble());

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.2),
            AppColors.cardDark
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              'Total Sessions',
              totalSessions.toString(),
              Icons.history,
            ),
          ),
          Container(
              width: 1, height: 40, color: Colors.grey.withValues(alpha: 0.3)),
          Expanded(
            child: _buildStatItem(
              'Total Mined',
              '${totalMined.toStringAsFixed(2)} OLR',
              Icons.token,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  Widget _buildSessionCard(Map<String, dynamic> session) {
    final startTime =
        DateTime.tryParse(session['startTime'] ?? '')?.toLocal() ?? DateTime.now();
    final endTime = session['endTime'] != null
        ? DateTime.tryParse(session['endTime'])?.toLocal()
        : null;

    // For completed sessions use coinsEarned, for active use expectedCoins
    final status = session['status'] ?? 'completed';
    // If active, use expectedCoins. If completed/claimed, use coinsEarned
    final coins = (status.toLowerCase() == 'active'
            ? (session['expectedCoins'] ?? 0)
            : (session['coinsEarned'] ?? 0))
        .toDouble();

    // Calculate duration from startTime and endTime
    int durationMinutes = 0;
    if (endTime != null) {
      durationMinutes = endTime.difference(startTime).inMinutes;
    }

    // If duration is still 0 or negative, calculate from totalRate and coins earned
    if (durationMinutes <= 0 && coins > 0) {
      final totalRate = ((session['totalRate'] ?? 0.25) as num).toDouble();
      if (totalRate > 0) {
        // coins = rate * hours, so hours = coins / rate
        final hours = coins / totalRate;
        durationMinutes = (hours * 60).round();
      }
    }

    // Fallback: if still 0 for completed sessions, assume 24 hours (default cycle)
    if (durationMinutes <= 0 && status == 'completed') {
      durationMinutes = 24 * 60; // 24 hours in minutes
    }

    Color statusColor;
    IconData statusIcon;
    switch (status.toLowerCase()) {
      case 'active':
        statusColor = AppColors.warning;
        statusIcon = Icons.play_circle;
        break;
      case 'completed':
        statusColor = AppColors.success;
        statusIcon = Icons.check_circle;
        break;
      case 'claimed':
        statusColor = AppColors.primary;
        statusIcon = Icons.verified;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.circle;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.memory, color: statusColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('MMM dd, yyyy').format(startTime),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      DateFormat('hh:mm a').format(startTime),
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, color: statusColor, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      status.toUpperCase(),
                      style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: Colors.grey.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildDetailItem(
                    'Duration', _formatDuration(durationMinutes)),
              ),
              Expanded(
                child: _buildDetailItem(
                    'Coins Earned', '+${coins.toStringAsFixed(4)} OLR'),
              ),
              Expanded(
                child: _buildDetailItem(
                    'End Time',
                    endTime != null
                        ? DateFormat('hh:mm a').format(endTime)
                        : '-'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        const SizedBox(height: 4),
        Text(
          value,
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (mins == 0) return '$hours hr';
    return '$hours hr $mins min';
  }
}
