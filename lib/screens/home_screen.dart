import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'dart:async';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../utils/constants.dart';
import 'wallet_screen.dart';
import 'referral_screen.dart';
import 'profile_screen.dart';
import 'feed_screen.dart';
import 'coin_purchase_screen.dart';
import 'leaderboard_screen.dart';
import 'notifications_screen.dart';
import 'transaction_history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  Map<String, dynamic>? _dashboardData;
  Map<String, dynamic>? _miningStatus;
  bool _isLoading = true;
  int _currentIndex = 0;

  // Socket service for real-time updates
  final SocketService _socketService = SocketService.instance;
  StreamSubscription<MiningData>? _miningSubscription;
  StreamSubscription<bool>? _connectionSubscription;

  // Real-time mining data from socket
  MiningData? _realTimeMiningData;
  bool _isSocketConnected = false;
  Timer? _miningTimer;

  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _rotationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initSocket();
    _startMiningTimer();
    _loadData();
  }

  void _initSocket() {
    // Clear any stale data and connect fresh
    _realTimeMiningData = null;

    // Connect to socket (will get fresh data for current user)
    _socketService.connect().catchError((e) {
      debugPrint('Socket connection error in HomeScreen: $e');
    });

    // Listen for mining updates
    _miningSubscription = _socketService.miningUpdates.listen((data) {
      if (mounted) {
        setState(() {
          _realTimeMiningData = data;
        });
      }
    });

    // Listen for connection status
    _connectionSubscription =
        _socketService.connectionStatus.listen((connected) {
      if (mounted) {
        setState(() {
          _isSocketConnected = connected;
        });
      }
    });
  }

  void _initAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _rotationController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _miningTimer?.cancel();
    _pulseController.dispose();
    _rotationController.dispose();
    _miningSubscription?.cancel();
    _connectionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadData({bool showLoading = true}) async {
    if (showLoading) {
      setState(() => _isLoading = true);
    }
    try {
      final dashboard = await ApiService.getDashboard();
      final mining = await ApiService.getMiningStatus();

      // Fetch check-in status separately to ensure data consistency
      Map<String, dynamic>? checkinStatus;
      try {
        checkinStatus = await ApiService.getCheckinStatus();
      } catch (e) {
        debugPrint('Check-in status fetch error: $e');
      }

      if (mounted) {
        setState(() {
          // Dashboard data is nested inside 'dashboard' key from API response
          _dashboardData = dashboard['dashboard'] ?? dashboard;
          _miningStatus = mining;

          // Merge check-in data if available (handle nested structures)
          // Merge check-in data if available (handle nested structures)
          if (checkinStatus != null && _dashboardData != null) {
            final dynamic rawData = checkinStatus['data'] ??
                checkinStatus['checkIn'] ??
                checkinStatus;

            if (rawData is Map<String, dynamic>) {
              final Map<String, dynamic> currentCheckin =
                  (_dashboardData!['checkin'] as Map<String, dynamic>?) ??
                      <String, dynamic>{};

              _dashboardData!['checkin'] = <String, dynamic>{
                ...currentCheckin,
                ...rawData
              };

              // Also update user object for backward compatibility
              if (_dashboardData!['user'] != null) {
                final Map<String, dynamic> userCheckin =
                    (_dashboardData!['user']['dailyCheckIn']
                            as Map<String, dynamic>?) ??
                        <String, dynamic>{};

                _dashboardData!['user']['dailyCheckIn'] = <String, dynamic>{
                  ...userCheckin,
                  ...rawData
                };
              }
            }
          }

          _isLoading = false;

          // Initialize real-time data from API if socket hasn't connected yet
          if (_realTimeMiningData == null && _miningStatus != null) {
            _realTimeMiningData = MiningData.fromApi(_miningStatus!);
          }
        });
      }
      // Request socket update
      _socketService.requestMiningStatus();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('Error loading data: $e', isError: true);
      }
    }
  }

  // Silent background refresh - no loading indicator
  Future<void> _refreshInBackground() async {
    try {
      final dashboard = await ApiService.getDashboard();
      final mining = await ApiService.getMiningStatus();

      // Fetch check-in status separately
      Map<String, dynamic>? checkinStatus;
      try {
        checkinStatus = await ApiService.getCheckinStatus();
      } catch (e) {
        debugPrint('Background check-in status fetch error: $e');
      }

      if (mounted) {
        setState(() {
          _dashboardData = dashboard['dashboard'] ?? dashboard;
          _miningStatus = mining;

          // Merge check-in data if available (handle nested structures)
          if (checkinStatus != null && _dashboardData != null) {
            final dynamic rawData = checkinStatus['data'] ??
                checkinStatus['checkIn'] ??
                checkinStatus;

            if (rawData is Map<String, dynamic>) {
              final Map<String, dynamic> currentCheckin =
                  (_dashboardData!['checkin'] as Map<String, dynamic>?) ??
                      <String, dynamic>{};

              _dashboardData!['checkin'] = <String, dynamic>{
                ...currentCheckin,
                ...rawData
              };

              // Also update user object for backward compatibility
              if (_dashboardData!['user'] != null) {
                final Map<String, dynamic> userCheckin =
                    (_dashboardData!['user']['dailyCheckIn']
                            as Map<String, dynamic>?) ??
                        <String, dynamic>{};

                _dashboardData!['user']['dailyCheckIn'] = <String, dynamic>{
                  ...userCheckin,
                  ...rawData
                };
              }
            }
          }

          // Initialize real-time data from API if socket hasn't connected yet
          if (_realTimeMiningData == null && _miningStatus != null) {
            _realTimeMiningData = MiningData.fromApi(_miningStatus!);
          }
        });
      }
      _socketService.requestMiningStatus();
    } catch (e) {
      // Silent fail for background refresh
      debugPrint('Background refresh error: $e');
    }
  }

  void _showSnackBar(String message,
      {bool isError = false, bool isSuccess = false}) {
    // Clean up exception messages
    String cleanMessage = message.replaceAll('Exception: ', '');
    if (isError && cleanMessage.startsWith('Error: ')) {
      cleanMessage = cleanMessage.substring(7);
    }

    // Dismiss any existing snackbars first to avoid queuing
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline
                  : isSuccess
                      ? Icons.check_circle_outline
                      : Icons.info_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                cleanMessage,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError
            ? const Color(0xFFFF4757)
            : isSuccess
                ? const Color(0xFF00D4AA)
                : const Color(0xFF3D5AFE),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _startMiningTimer() {
    _miningTimer?.cancel();
    _miningTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final currentData = _realTimeMiningData;
      if (currentData != null && currentData.status == 'mining') {
        setState(() {
          // Decrement time
          final newTime = currentData.timeRemaining - 1;

          if (newTime < 0) {
            // Timer finished
            _realTimeMiningData = MiningData(
              status: 'complete',
              coinsEarned: currentData.coinsEarned,
              timeRemaining: 0,
              progress: 100.0,
              currentSession: currentData.currentSession,
            );
            _refreshInBackground(); // Sync with server
            return;
          }

          // Increment coins
          final nextRates = _miningStatus?['nextSessionRates'] ?? {};
          final coinsPerHour = _safeDouble(nextRates['totalRate'], 0.25);
          final coinsPerSecond = coinsPerHour / 3600;

          final newCoins = currentData.coinsEarned + coinsPerSecond;

          // Calculate progress
          double newProgress = currentData.progress;
          // Use API session data to calculate accurate progress if available
          if (_miningStatus != null &&
              _miningStatus!['currentSession'] != null &&
              _miningStatus!['currentSession'] is Map) {
            final session = _miningStatus!['currentSession'];
            final startTime =
                DateTime.tryParse(session['startTime']?.toString() ?? '');
            final endTime =
                DateTime.tryParse(session['endTime']?.toString() ?? '');

            if (startTime != null && endTime != null) {
              final totalSeconds = endTime.difference(startTime).inSeconds;
              if (totalSeconds > 0) {
                final elapsed = totalSeconds - newTime;
                newProgress = (elapsed / totalSeconds * 100).clamp(0.0, 100.0);
              }
            }
          }

          // Decrement boost timer if active
          if (_miningStatus != null && _miningStatus!['boostStatus'] != null) {
            final boostStatus = Map<String, dynamic>.from(_miningStatus!['boostStatus']);
            final currentRemaining = _safeInt(boostStatus['boostTimeRemaining'], 0);
            if (currentRemaining > 0) {
              boostStatus['boostTimeRemaining'] = currentRemaining - 1;
              if (currentRemaining - 1 <= 0) {
                boostStatus['isBoostActive'] = false;
              }
              _miningStatus = {..._miningStatus!, 'boostStatus': boostStatus};
            }
          }

          _realTimeMiningData = MiningData(
            status: 'mining',
            coinsEarned: newCoins,
            timeRemaining: newTime,
            progress: newProgress,
            currentSession: currentData.currentSession,
          );
        });
      }
    });
  }

  Future<void> _handleMining() async {
    HapticFeedback.mediumImpact();

    // Use socket data first (real-time), then fallback to API data
    final socketStatus = _realTimeMiningData?.status;
    final apiStatus = _miningStatus?['status'] ?? 'idle';
    final status = socketStatus ?? apiStatus;

    debugPrint(
        'Mining action - Socket status: $socketStatus, API status: $apiStatus, Using: $status');

    if (status == 'idle') {
      // Optimistic UI - immediately show mining state
      setState(() {
        _miningStatus = {...?_miningStatus, 'status': 'mining'};
        _realTimeMiningData = MiningData(
          status: 'mining',
          coinsEarned: 0,
          timeRemaining: 86400,
          progress: 0,
        );
      });

      try {
        await ApiService.startMining();
        _showSnackBar('Mining started! ⛏️', isSuccess: true);
        // Refresh in background without loading
        _refreshInBackground();
      } catch (e) {
        // Revert on error
        setState(() {
          _miningStatus = {...?_miningStatus, 'status': 'idle'};
          _realTimeMiningData = MiningData.idle();
        });
        _showSnackBar('Error: $e', isError: true);
      }
    } else if (status == 'complete') {
      // Optimistic UI - immediately show idle state with coins added
      final coinsEarned = _realTimeMiningData?.coinsEarned ?? 0;
      setState(() {
        _miningStatus = {...?_miningStatus, 'status': 'idle'};
        _realTimeMiningData = MiningData.idle();
      });

      try {
        await ApiService.claimMining();
        _showSnackBar('🎉 +${coinsEarned.toStringAsFixed(2)} coins claimed!',
            isSuccess: true);
        // Refresh in background without loading
        _refreshInBackground();
      } catch (e) {
        // Revert on error
        setState(() {
          _miningStatus = {...?_miningStatus, 'status': 'complete'};
        });
        _showSnackBar('Error: $e', isError: true);
      }
    } else {
      _showSnackBar('Mining in progress...');
    }
  }

  Future<void> _handleBoostMining(String boostType) async {
    final settings = _miningStatus?['settings'] ?? {};
    final boostStatus = _miningStatus?['boostStatus'] ?? {};
    final boostCost = _safeDouble(settings['boostCost'] ?? boostStatus['boostCost'], 50);
    final boostPercent = _safeInt(settings['boostBonusPercent'] ?? boostStatus['boostBonusPercent'], 50);
    final boostDuration = _safeInt(settings['boostDurationMinutes'] ?? boostStatus['boostDurationMinutes'], 30);
    
    final boostName = '+$boostPercent% Base Rate for ${boostDuration}m';
    final costText = boostCost > 0 ? '${boostCost.toStringAsFixed(0)} OLR' : 'Free';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1D1F33),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title:
            const Text('⚡ Boost Mining Rate?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Boost base mining rate by $boostName?\n\nCost: $costText',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD700),
            ),
            child: const Text('Boost Now!', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      HapticFeedback.mediumImpact();

      // Show immediate feedback
      _showSnackBar('⚡ Applying boost...', isSuccess: true);

      try {
        final result = await ApiService.boostMining(boostType: boostType);

        // Check if mining was completed by the boost
        final miningCompleted = result['miningCompleted'] == true;

        if (miningCompleted) {
          final coinsEarned = result['coinsEarned'] ?? 0;
          _showSnackBar('🎉 Mining completed! +$coinsEarned coins earned!',
              isSuccess: true);

          // Update UI to show idle state
          setState(() {
            _miningStatus = {...?_miningStatus, 'status': 'idle'};
            _realTimeMiningData = MiningData.idle();
          });
        } else {
          final coinsSpent = _safeDouble(result['coinsSpent'], 0);
          final boostMsg = result['message'] ?? '🚀 Speed boosted 1.5x!';
          
          if (coinsSpent > 0) {
            _showSnackBar('$boostMsg (Spent: $coinsSpent OLR)', isSuccess: true);
          } else {
            _showSnackBar(boostMsg, isSuccess: true);
          }
        }

        _refreshInBackground();
      } catch (e) {
        _showSnackBar('Error: $e', isError: true);
      }
    }
  }

  Future<void> _handleDailyCheckIn() async {
    HapticFeedback.mediumImpact();

    // Optimistic UI - immediately show as checked in
    final currentStreak = _dashboardData?['checkin']?['streak'] ??
        _dashboardData?['user']?['dailyCheckIn']?['streak'] ??
        0;

    setState(() {
      if (_dashboardData != null) {
        _dashboardData!['checkin'] = {
          ...?_dashboardData!['checkin'],
          'hasCheckedIn': true,
          'streak': currentStreak + 1,
        };
      }
    });

    try {
      final result = await ApiService.dailyCheckIn();
      final dynamic rawData = result['data'] ?? result;
      final Map<String, dynamic> data =
          (rawData is Map<String, dynamic>) ? rawData : result;
      final bonusObj = data['bonus'];
      double bonusCoins = 1.0;
      double nextDayBonus = 1.0;

      if (bonusObj is Map) {
        bonusCoins = _safeDouble(bonusObj['coins'], 1.0);
        nextDayBonus = _safeDouble(bonusObj['nextDayBonus'], 1.0);
      } else if (bonusObj is num) {
        bonusCoins = bonusObj.toDouble();
      }

      // Show beautiful popup instead of snackbar
      _showDailyRewardDialog(currentStreak + 1, bonusCoins, nextDayBonus);
      // Refresh in background
      _refreshInBackground();
    } catch (e) {
      // Revert on error
      setState(() {
        if (_dashboardData != null) {
          _dashboardData!['checkin'] = {
            ...?_dashboardData!['checkin'],
            'hasCheckedIn': false,
            'streak': currentStreak,
          };
        }
      });
      _showSnackBar('Error: $e', isError: true);
    }
  }

  void _showDailyRewardDialog(int day, double coins, double nextBonus) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1D1F33),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.card_giftcard,
                  color: Color(0xFFFFD700),
                  size: 48,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Day $day Streak! 🔥',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '+$coins Olaro Coins',
                style: const TextStyle(
                  color: Color(0xFF00D4AA),
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Come back tomorrow for +$nextBonus coins!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                    shadowColor: AppColors.primary.withValues(alpha: 0.5),
                  ),
                  child: const Text(
                    'Awesome!',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildHomeContent(),
          FeedScreen(key: FeedScreen.globalKey),
          WalletScreen(key: WalletScreen.globalKey),
          ReferralScreen(key: ReferralScreen.globalKey),
          ProfileScreen(key: ProfileScreen.globalKey),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHomeContent() {
    return _isLoading
        ? _buildLoadingState()
        : RefreshIndicator(
            onRefresh: _loadData,
            color: AppColors.primary,
            backgroundColor: AppColors.cardDark,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                _buildAppBar(),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildMiningSection(),
                        const SizedBox(height: 20),
                        _buildQuickActions(),
                        const SizedBox(height: 20),
                        _buildStatsSection(),
                        const SizedBox(height: 20),
                        _buildDailyRewards(),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _rotationController,
            builder: (context, child) {
              return Transform.rotate(
                angle: _rotationController.value * 2 * math.pi,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Image.asset(
                      'assets/images/olaro_transparent.png',
                      width: 40,
                      height: 40,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          const Text(
            'Loading...',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    final user = _dashboardData?['user'];
    final name = user?['name'] ?? 'User';
    final avatar = user?['avatar'];

    return SliverAppBar(
      expandedHeight: 120,
      floating: true,
      pinned: true,
      backgroundColor: const Color(0xFF0A0E21),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1D1F33), Color(0xFF0A0E21)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ),
      title: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
              ),
              border: Border.all(color: const Color(0xFFFFD700), width: 2),
            ),
            child: avatar != null && avatar.toString().isNotEmpty
                ? ClipOval(
                    child: Image.network(
                      avatar,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  )
                : Center(
                    child: Text(
                      name.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Welcome back,',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: _loadData,
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
        ),
        IconButton(
          onPressed: () {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()));
          },
          icon: Stack(
            children: [
              const Icon(Icons.notifications_none_rounded, color: Colors.white),
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildMiningSection() {
    // Use real-time socket data if available, otherwise fallback to API data
    final socketData = _realTimeMiningData;

    // Determine status from socket or API
    final status = socketData?.status ?? _miningStatus?['status'] ?? 'idle';
    final isActive = status == 'mining';
    final canClaim = status == 'complete';

    // Get real-time values from socket
    double progress = socketData?.progress ?? 0.0;
    double coinsEarned = socketData?.coinsEarned ?? 0.0;
    int timeRemaining = socketData?.timeRemaining ?? 0;

    // Fallback calculation if socket not connected
    if (socketData == null && _miningStatus != null) {
      final currentSession = _miningStatus?['currentSession'];
      if (isActive && currentSession != null) {
        final startTime = DateTime.tryParse(currentSession['startTime'] ?? '');
        final endTime = DateTime.tryParse(currentSession['endTime'] ?? '');
        final expectedCoins =
            ((currentSession['expectedCoins'] ?? 0) as num).toDouble();

        if (startTime != null && endTime != null) {
          final totalDuration = endTime.difference(startTime).inSeconds;
          final elapsed = DateTime.now().difference(startTime).inSeconds;
          progress = (elapsed / totalDuration * 100).clamp(0.0, 100.0);
          coinsEarned = (progress / 100) * expectedCoins;
          timeRemaining = (endTime.difference(DateTime.now()).inSeconds)
              .clamp(0, totalDuration);
        }
      } else if (canClaim && currentSession != null) {
        coinsEarned =
            ((currentSession['expectedCoins'] ?? 0) as num).toDouble();
        progress = 100;
      }
    }

    final nextRates = _miningStatus?['nextSessionRates'] ?? {};
    final coinsPerHour = _safeDouble(nextRates['totalRate'], 0.25);
    final baseRate = _safeDouble(nextRates['baseRate'], 0.25);
    final referralRate = _safeDouble(nextRates['referralRate'], 0);
    final levelBoost = _safeDouble(nextRates['levelBoost'], 0);

    // Get user level from mining stats
    final userStats = _miningStatus?['stats'] ?? {};
    final int userLevel = _safeInt(userStats['level'], 1);

    // Format time remaining
    final hours = (timeRemaining ~/ 3600);
    final minutes = ((timeRemaining % 3600) ~/ 60);
    final seconds = (timeRemaining % 60);
    final timeString =
        '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isActive
              ? [
                  const Color(0xFF00D4AA).withValues(alpha: 0.2),
                  const Color(0xFF1D1F33)
                ]
              : [const Color(0xFF1D1F33), const Color(0xFF252A3D)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isActive
              ? const Color(0xFF00D4AA).withValues(alpha: 0.3)
              : Colors.transparent,
        ),
      ),
      child: Column(
        children: [
          // Connection status indicator
          if (_isSocketConnected) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF00D4AA),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'LIVE',
                  style: TextStyle(
                    color: Color(0xFF00D4AA),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          // Header with Activity Balance when mining
          if (isActive || canClaim) ...[
            const Text(
              'Activity Balance',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 8),
            // Coins earned counter (increases in real-time from server)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  coinsEarned.toStringAsFixed(0),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '.${(coinsEarned % 1 * 10000).toInt().toString().padLeft(4, '0')}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Rate breakdown chip row when mining
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildMiniRateChip('Base', baseRate, const Color(0xFF00D4AA)),
                const SizedBox(width: 6),
                if (referralRate > 0) ...[
                  _buildMiniRateChip(
                      'Ref', referralRate, const Color(0xFFFF8C00)),
                  const SizedBox(width: 6),
                ],
                if (levelBoost > 0) ...[
                  _buildMiniRateChip(
                      'Lvl $userLevel', levelBoost, const Color(0xFF3D5AFE)),
                  const SizedBox(width: 6),
                ],
                _buildMiniRateChip(
                    'Total', coinsPerHour, const Color(0xFFFFD700),
                    isTotal: true),
              ],
            ),
            const SizedBox(height: 12),
            // Time remaining countdown
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.access_time,
                    color: canClaim
                        ? const Color(0xFFFFD700)
                        : const Color(0xFF00D4AA),
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    canClaim ? 'Ready to claim!' : timeString,
                    style: TextStyle(
                      color: canClaim
                          ? const Color(0xFFFFD700)
                          : const Color(0xFF00D4AA),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Mining Hub',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.circle, color: Colors.grey, size: 8),
                      SizedBox(width: 6),
                      Text('Idle',
                          style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
          ],
          // Mining control buttons row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Main mining button
              GestureDetector(
                onTap: _handleMining,
                child: AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: isActive && !canClaim
                          ? 1.0
                          : _pulseAnimation.value * 0.95 + 0.05,
                      child: Container(
                        width: canClaim ? 120 : (isActive ? 100 : 130),
                        height: canClaim ? 120 : (isActive ? 100 : 130),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: canClaim
                                ? [
                                    const Color(0xFFFFD700),
                                    const Color(0xFFFF8C00)
                                  ]
                                : isActive
                                    ? [
                                        const Color(0xFF00D4AA),
                                        const Color(0xFF00A388)
                                      ]
                                    : [
                                        const Color(0xFF3D5AFE),
                                        const Color(0xFF304FFE)
                                      ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (canClaim
                                      ? const Color(0xFFFFD700)
                                      : isActive
                                          ? const Color(0xFF00D4AA)
                                          : const Color(0xFF3D5AFE))
                                  .withValues(alpha: 0.4),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              canClaim
                                  ? Icons.redeem
                                  : isActive
                                      ? Icons.memory
                                      : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: canClaim ? 40 : (isActive ? 32 : 40),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              canClaim
                                  ? 'CLAIM'
                                  : (isActive ? 'Mining' : 'START'),
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: canClaim ? 16 : 14,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          // Boost buttons - only show when mining is active
          if (isActive && !canClaim) ...[
            const SizedBox(height: 24),
            Builder(
              builder: (context) {
                final boostStatus = _miningStatus?['boostStatus'] ?? {};
                final isBoostActive = boostStatus['isBoostActive'] == true;
                final boostTimeRemainingSecs = _safeInt(boostStatus['boostTimeRemaining'], 0);
                final boostBonusPercent = _safeInt(boostStatus['boostBonusPercent'], 50);
                final boostCost = _safeDouble(_miningStatus?['settings']?['boostCost'] ?? boostStatus['boostCost'], 50);

                if (isBoostActive) {
                  final mins = boostTimeRemainingSecs ~/ 60;
                  final secs = boostTimeRemainingSecs % 60;
                  final timeStr = '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF8E2DE2).withValues(alpha: 0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.flash_on, color: Color(0xFFFFD700), size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '⚡ BOOST ACTIVE (+$boostBonusPercent% Speed)',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Expires in: $timeStr',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    const Text(
                      '⚡ BOOST OPTIONS',
                      style: TextStyle(
                        color: Color(0xFFFFD700),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: _buildBoostButton(
                            'Speed Boost (+$boostBonusPercent%)',
                            Icons.flash_on,
                            const Color(0xFFFF8C00),
                            () => _handleBoostMining('speed'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Cost: ${boostCost > 0 ? '${boostCost.toStringAsFixed(0)} OLR' : 'Free'} (Active for 30 mins)',
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ],
                );
              },
            ),
          ],
          // Show mining rate breakdown when idle
          if (!isActive && !canClaim) ...[
            const SizedBox(height: 16),
            _buildRateBreakdown(
                baseRate, referralRate, levelBoost, coinsPerHour, userLevel),
          ],
        ],
      ),
    );
  }

  Widget _buildRateBreakdown(double baseRate, double referralRate,
      double levelBoost, double totalRate, int level) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          // Header with level badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.speed, color: Color(0xFFFFD700), size: 20),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Mining Rate Breakdown',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3D5AFE), Color(0xFF304FFE)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, color: Colors.white, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      'Level $level',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Rate breakdown rows
          _buildRateRow('Base Rate', baseRate, Icons.memory, Colors.grey),
          const SizedBox(height: 8),
          _buildRateRow('Referral Bonus', referralRate, Icons.people,
              const Color(0xFFFF8C00)),
          const SizedBox(height: 8),
          _buildRateRow('Level Bonus', levelBoost, Icons.trending_up,
              const Color(0xFF3D5AFE)),
          const SizedBox(height: 12),
          // Divider
          Container(
            height: 1,
            color: Colors.grey.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 12),
          // Total rate
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.rocket_launch, color: Color(0xFFFFD700), size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Total Rate',
                    style: TextStyle(
                      color: Color(0xFFFFD700),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${totalRate.toStringAsFixed(2)} OLR/hr',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          // Info text
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF00D4AA).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    color: Color(0xFF00D4AA), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Invite friends & level up to earn more!',
                    style: TextStyle(
                      color: const Color(0xFF00D4AA).withValues(alpha: 0.9),
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRateRow(String label, double rate, IconData icon, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 13,
              ),
            ),
          ],
        ),
        Text(
          '+${rate.toStringAsFixed(2)} OLR/hr',
          style: TextStyle(
            color: rate > 0 ? Colors.white : Colors.grey,
            fontSize: 13,
            fontWeight: rate > 0 ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildMiniRateChip(String label, double rate, Color color,
      {bool isTotal = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isTotal ? color : color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isTotal ? Colors.black : color,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            rate.toStringAsFixed(2),
            style: TextStyle(
              color: isTotal ? Colors.black : Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoostButton(
      String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.3),
              color.withValues(alpha: 0.1)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
            child: _buildActionCard(
                'Buy Coins', Icons.shopping_cart, AppColors.primary, () {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const CoinPurchaseScreen()));
        })),
        const SizedBox(width: 12),
        Expanded(
            child: _buildActionCard(
                'Leaderboard', Icons.leaderboard, AppColors.warning, () {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const LeaderboardScreen()));
        })),
        const SizedBox(width: 12),
        Expanded(
            child: _buildActionCard('History', Icons.history, AppColors.success,
                () {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const TransactionHistoryScreen()));
        })),
      ],
    );
  }

  Widget _buildActionCard(
      String title, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF1D1F33),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 10),
            Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: const Color(0xFF1D1F33),
          borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Your Stats',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                  child: _buildStatCard(
                      'Total Mined',
                      _formatNumber(_dashboardData?['wallets']?['mining']
                              ?['totalMined'] ??
                          _dashboardData?['user']?['totalMined'] ??
                          0),
                      Icons.memory,
                      const Color(0xFF00D4AA))),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildStatCard(
                      'Referrals',
                      '${_dashboardData?['referrals']?['total'] ?? 0}',
                      Icons.people,
                      const Color(0xFFFF8C00))),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _buildStatCard(
                      'Check-in Streak',
                      '${_dashboardData?['checkin']?['streak'] ?? 0} days',
                      Icons.local_fire_department,
                      const Color(0xFFFF4757))),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildStatCard(
                      'Mining Sessions',
                      '${_dashboardData?['user']?['level'] ?? 1}',
                      Icons.trending_up,
                      const Color(0xFF3D5AFE))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildDailyRewards() {
    final hasCheckedIn = _dashboardData?['checkin']?['hasCheckedIn'] ??
        _dashboardData?['user']?['dailyCheckIn']?['hasCheckedInToday'] ??
        false;
    final streak = _dashboardData?['checkin']?['streak'] ??
        _dashboardData?['user']?['dailyCheckIn']?['streak'] ??
        0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: hasCheckedIn
              ? [const Color(0xFF1D1F33), const Color(0xFF1D1F33)]
              : [
                  const Color(0xFFFFD700).withValues(alpha: 0.15),
                  const Color(0xFF1D1F33)
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasCheckedIn
              ? const Color(0xFF00D4AA).withValues(alpha: 0.3)
              : const Color(0xFFFFD700).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: hasCheckedIn
                    ? [const Color(0xFF00D4AA), const Color(0xFF00A388)]
                    : [const Color(0xFFFFD700), const Color(0xFFFF8C00)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(hasCheckedIn ? Icons.check_circle : Icons.card_giftcard,
                color: Colors.white, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Daily Reward',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  hasCheckedIn
                      ? 'Claimed! Streak: $streak days 🔥'
                      : 'Claim your daily bonus now!',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
          ),
          if (!hasCheckedIn)
            ElevatedButton(
              onPressed: _handleDailyCheckIn,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD700),
                foregroundColor: Colors.black,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Claim',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF00D4AA).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check, color: Color(0xFF00D4AA), size: 18),
                  SizedBox(width: 4),
                  Text('Done',
                      style: TextStyle(
                          color: Color(0xFF00D4AA),
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1D1F33),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, -5))
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.home_rounded, 'Home'),
              _buildNavItem(1, Icons.article_rounded, 'Feed'),
              _buildNavItem(2, Icons.account_balance_wallet_rounded, 'Wallet'),
              _buildNavItem(3, Icons.people_rounded, 'Referral'),
              _buildNavItem(4, Icons.person_rounded, 'Profile'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();

        // Refresh the target screen when switching tabs (silent refresh)
        if (_currentIndex != index) {
          switch (index) {
            case 1: // Feed
              FeedScreen.globalKey.currentState?.refreshFeeds();
              break;
            case 2: // Wallet
              WalletScreen.globalKey.currentState?.refreshWallet();
              break;
            case 3: // Referral
              ReferralScreen.globalKey.currentState?.refreshReferrals();
              break;
            case 4: // Profile
              ProfileScreen.globalKey.currentState?.refreshProfile();
              break;
          }
        }

        setState(() => _currentIndex = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: isSelected ? AppColors.primary : Colors.grey, size: 26),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.primary : Colors.grey,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Safe type conversion helpers
  double _safeDouble(dynamic value, double defaultValue) {
    if (value == null) return defaultValue;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? defaultValue;
  }

  int _safeInt(dynamic value, int defaultValue) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? defaultValue;
  }

  String _formatNumber(dynamic number) {
    if (number == null) return '0';
    final num = double.tryParse(number.toString()) ?? 0;
    if (num >= 1000000) return '${(num / 1000000).toStringAsFixed(2)}M';
    if (num >= 1000) return '${(num / 1000).toStringAsFixed(2)}K';
    return num.toStringAsFixed(2);
  }
}
