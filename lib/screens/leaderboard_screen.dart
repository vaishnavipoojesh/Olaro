import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  List<dynamic> _leaderboard = [];
  Map<String, dynamic>? _userRank;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    setState(() => _isLoading = true);
    try {
      final result = await ApiService.getMiningLeaderboard();
      setState(() {
        _leaderboard = result['leaderboard'] ?? [];
        _userRank = result['userRank'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.primary,
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
        title: const Text('Mining Leaderboard',
            style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLeaderboard,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _loadLeaderboard,
              color: AppColors.primary,
              child: Column(
                children: [
                  // Top 3 Podium
                  if (_leaderboard.length >= 3) _buildPodium(),

                  // User's Rank Card
                  if (_userRank != null) _buildUserRankCard(),

                  // Leaderboard List
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _leaderboard.length,
                      itemBuilder: (context, index) {
                        return _buildLeaderboardItem(
                            _leaderboard[index], index + 1);
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildPodium() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.cardDark, AppColors.background],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 2nd Place
          _buildPodiumItem(_leaderboard[1], 2, 100, Colors.grey),
          const SizedBox(width: 8),
          // 1st Place
          _buildPodiumItem(_leaderboard[0], 1, 130, AppColors.primary),
          const SizedBox(width: 8),
          // 3rd Place
          _buildPodiumItem(_leaderboard[2], 3, 80, const Color(0xFFCD7F32)),
        ],
      ),
    );
  }

  Widget _buildPodiumItem(
      Map<String, dynamic> user, int rank, double height, Color color) {
    final name = user['name'] ?? 'User';
    final avatar = user['avatar'];
    final coins = (user['totalMined'] ?? 0).toDouble();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 3),
                color: AppColors.cardDark,
              ),
              child: avatar != null && avatar.toString().isNotEmpty
                  ? ClipOval(child: Image.network(avatar, fit: BoxFit.cover))
                  : Center(
                      child: Text(
                        name.substring(0, 1).toUpperCase(),
                        style: TextStyle(
                            color: color,
                            fontSize: 24,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
            ),
            Positioned(
              bottom: -5,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$rank',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          name.length > 8 ? '${name.substring(0, 8)}...' : name,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
        Text(
          '${coins.toStringAsFixed(0)} CM',
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          width: 70,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withValues(alpha: 0.5)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          ),
          child: rank == 1
              ? const Icon(Icons.emoji_events, color: Colors.white, size: 30)
              : null,
        ),
      ],
    );
  }

  Widget _buildUserRankCard() {
    final rank = _userRank?['rank'] ?? 0;
    final totalMined = (_userRank?['totalMined'] ?? 0).toDouble();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary.withValues(alpha: 0.3), AppColors.cardDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                '#$rank',
                style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Your Rank',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
                Text(
                  '${totalMined.toStringAsFixed(2)} CM mined',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const Icon(Icons.trending_up, color: AppColors.success),
        ],
      ),
    );
  }

  Widget _buildLeaderboardItem(Map<String, dynamic> user, int rank) {
    final name = user['name'] ?? 'User';
    final avatar = user['avatar'];
    final coins = (user['totalMined'] ?? 0).toDouble();

    Color? rankColor;
    if (rank == 1) rankColor = AppColors.primary;
    if (rank == 2) rankColor = Colors.grey;
    if (rank == 3) rankColor = const Color(0xFFCD7F32);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: rankColor != null
            ? Border.all(color: rankColor.withValues(alpha: 0.3))
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color:
                  rankColor?.withValues(alpha: 0.2) ?? Colors.grey.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '$rank',
                style: TextStyle(
                  color: rankColor ?? Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.2),
            ),
            child: avatar != null && avatar.toString().isNotEmpty
                ? ClipOval(child: Image.network(avatar, fit: BoxFit.cover))
                : Center(
                    child: Text(
                      name.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(name,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w500)),
          ),
          Text(
            '${coins.toStringAsFixed(2)} CM',
            style: TextStyle(
                color: rankColor ?? Colors.grey, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
