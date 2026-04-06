import 'package:flutter/material.dart';
import 'dart:async';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../utils/constants.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  // Static key to access wallet screen state from outside
  static final GlobalKey<WalletScreenState> globalKey =
      GlobalKey<WalletScreenState>();

  @override
  State<WalletScreen> createState() => WalletScreenState();
}

class WalletScreenState extends State<WalletScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  Map<String, dynamic>? _walletData;
  List<dynamic> _transactions = [];
  Map<String, dynamic>? _miningRates;
  double _fallbackBalance = 0.0;
  bool _isLoading = true;
  late TabController _tabController;

  // Socket for real-time updates
  final SocketService _socketService = SocketService.instance;
  StreamSubscription<Map<String, dynamic>>? _walletSubscription;

  // For AutomaticKeepAliveClientMixin
  @override
  bool get wantKeepAlive => true;

  // Public method to refresh from outside
  void refreshWallet() {
    if (mounted && !_isLoading) {
      _loadData(showLoading: false);
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
    _initSocketListener();
  }

  void _initSocketListener() {
    // Only listen for direct wallet updates (boost, claim, transfer)
    // Don't listen to mining updates - they fire every second!
    _walletSubscription = _socketService.walletUpdates.listen((data) {
      debugPrint('Wallet update received: $data');
      // Only refresh if not already loading
      if (!_isLoading && mounted) {
        _loadData(showLoading: false);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _walletSubscription?.cancel();
    super.dispose();
  }

  // Helper to safely convert dynamic values (String/Int/Double) to double
  double _safeDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      try {
        return double.parse(value);
      } catch (_) {
        return 0.0;
      }
    }
    return 0.0;
  }

  Future<void> _loadData({bool showLoading = true}) async {
    if (showLoading) {
      setState(() => _isLoading = true);
    }
    try {
      // 1. Get Balance (Public API)
      final balanceData = await ApiService.getCoinBalance();
      debugPrint('DEBUG: Wallet Data: $balanceData'); // Debug log

      // 2. Get Transactions (Public API)
      final transactionsData = await ApiService.getTransactions();

      // 3. Get Mining Status
      final mining = await ApiService.getMiningStatus();

      // 4. Get Dashboard (Fallback for balance sync issues)
      final dashboard = await ApiService.getDashboard();
      debugPrint('DEBUG: Dashboard Data: $dashboard');

      if (mounted) {
        setState(() {
          _walletData = balanceData['balance'];
          _transactions = transactionsData['transactions'] ?? [];
          _miningRates = mining['nextSessionRates'];

          // Store fallback balance from dashboard if available
          final user = dashboard['dashboard']?['user'] ?? dashboard['user'];
          if (user != null) {
            // Try to find balance in user object
            _fallbackBalance = _safeDouble(user['coinBalance']) != 0.0
                ? _safeDouble(user['coinBalance'])
                : _safeDouble(user['miningStats']?['totalCoins']);

            // If wallet API returned 0 but dashboard has value, use it
            if (_safeDouble(_walletData?['totalCoins']) == 0.0 &&
                _safeDouble(_walletData?['totalBalance']) == 0.0 &&
                _fallbackBalance > 0) {
              debugPrint('DEBUG: Using fallback balance: $_fallbackBalance');
              // Inject fallback into wallet data for display
              final newWalletData =
                  Map<String, dynamic>.from(_walletData ?? {});
              newWalletData['totalCoins'] = _fallbackBalance;
              // Also try to populate mining wallet if empty
              if (_safeDouble(newWalletData['miningWallet']?['balance']) ==
                  0.0) {
                newWalletData['miningWallet'] = {
                  ...(newWalletData['miningWallet'] ?? {}),
                  'balance': _safeDouble(user['miningStats']?['totalCoins'])
                };
              }
              _walletData = newWalletData;
            }
          }

          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        if (showLoading) {
          _showSnackBar('Error: $e', isError: true);
        }
      }
    }
  }

  void _showSnackBar(String message,
      {bool isError = false, bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? AppColors.error
            : isSuccess
                ? AppColors.success
                : AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.cardDark,
        title: const Text('Wallet', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadData(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Mining'),
            Tab(text: 'Purchase'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildWalletTab('mining'),
                _buildWalletTab('purchase'),
              ],
            ),
    );
  }

  Widget _buildOverviewTab() {
    // Backend returns nested objects: miningWallet, purchaseWallet, referralWallet
    final miningWallet = _walletData?['miningWallet'] ?? {};
    final purchaseWallet = _walletData?['purchaseWallet'] ?? {};
    final referralWallet = _walletData?['referralWallet'] ?? {};

    final miningBalance = _safeDouble(miningWallet['balance']);
    final purchaseBalance = _safeDouble(purchaseWallet['balance']);
    final referralBalance = _safeDouble(referralWallet['balance']);

    // Backend uses 'totalCoins', fallback to sum if not present
    final totalBalance = _safeDouble(_walletData?['totalCoins']) != 0.0
        ? _safeDouble(_walletData?['totalCoins'])
        : _safeDouble(_walletData?['totalBalance']) != 0.0
            ? _safeDouble(_walletData?['totalBalance'])
            : (miningBalance + purchaseBalance + referralBalance);

    // Mining rates
    final baseRate = _safeDouble(_miningRates?['baseRate'] ?? 0.25);
    final referralRate = _safeDouble(_miningRates?['referralRate']);
    final levelBoost = _safeDouble(_miningRates?['levelBoost']);

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Total Balance Card
            _buildTotalBalanceCard(totalBalance),
            const SizedBox(height: 20),

            // Mining Rates Section - Similar to image
            _buildMiningRatesSection(baseRate, referralRate, levelBoost),
            const SizedBox(height: 20),

            // Wallet Cards Row
            Row(
              children: [
                Expanded(
                    child: _buildWalletCard('Mining', miningBalance,
                        AppColors.success, Icons.memory)),
                const SizedBox(width: 12),
                Expanded(
                    child: _buildWalletCard('Purchase', purchaseBalance,
                        const Color(0xFF3D5AFE), Icons.shopping_cart)),
              ],
            ),
            const SizedBox(height: 12),
            _buildWalletCard(
                'Referral', referralBalance, AppColors.warning, Icons.people,
                fullWidth: true),
            const SizedBox(height: 24),

            // Quick Actions
            _buildQuickActions(),
            const SizedBox(height: 24),

            // Recent Transactions
            const Text('Recent Transactions', style: AppTextStyles.heading3),
            const SizedBox(height: 12),
            _buildTransactionsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildMiningRatesSection(
      double baseRate, double referralRate, double levelBoost) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Mining Rates',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // Base Level Card - Red/Orange
            Expanded(
              child: _buildRateLevelCard(
                rate: baseRate,
                label: 'Base Level',
                gradientColors: [
                  const Color(0xFFFF6B6B),
                  const Color(0xFFFF8E53)
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Referral Level Card - Yellow/Green
            Expanded(
              child: _buildRateLevelCard(
                rate: referralRate,
                label: 'Referral Level',
                gradientColors: [
                  const Color(0xFFFFE066),
                  const Color(0xFFD4E157)
                ],
                textColor: Colors.black87,
              ),
            ),
            const SizedBox(width: 10),
            // Boost Level Card - Green
            Expanded(
              child: _buildRateLevelCard(
                rate: levelBoost,
                label: 'Boost Level',
                gradientColors: [
                  const Color(0xFF4CAF50),
                  const Color(0xFF66BB6A)
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRateLevelCard({
    required double rate,
    required String label,
    required List<Color> gradientColors,
    Color textColor = Colors.white,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradientColors[0].withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                rate.toStringAsFixed(2),
                style: TextStyle(
                  color: textColor,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                ' h',
                style: TextStyle(
                  color: textColor.withValues(alpha: 0.8),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: textColor.withValues(alpha: 0.9),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildWalletTab(String type) {
    // Backend returns nested objects: miningWallet, purchaseWallet
    final walletData = type == 'mining'
        ? (_walletData?['miningWallet'] ?? {})
        : (_walletData?['purchaseWallet'] ?? {});

    final balance = (walletData['balance'] ?? 0).toDouble();
    final locked = (walletData['locked'] ?? 0).toDouble();
    final available =
        (walletData['available'] ?? (balance - locked)).toDouble();
    final color =
        type == 'mining' ? AppColors.success : const Color(0xFF3D5AFE);
    final icon = type == 'mining' ? Icons.memory : Icons.shopping_cart;
    final title = type == 'mining' ? 'Mining Wallet' : 'Purchase Wallet';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withValues(alpha: 0.3), AppColors.cardDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: 0.5)),
            ),
            child: Column(
              children: [
                Icon(icon, color: color, size: 48),
                const SizedBox(height: 12),
                Text(title, style: AppTextStyles.heading3),
                const SizedBox(height: 20),
                Text(
                  '${balance.toStringAsFixed(2)} CM',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildBalanceInfo('Available', available, Colors.white),
                    Container(
                        width: 1,
                        height: 40,
                        color: Colors.grey.withValues(alpha: 0.3)),
                    _buildBalanceInfo('Locked', locked, Colors.orange),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: _buildActionButton('Withdraw', Icons.arrow_upward, color,
                    () => _showWithdrawDialog(type)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton('Transfer', Icons.swap_horiz,
                    AppColors.warning, () => _showTransferDialog(type)),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Wallet Info
          _buildInfoCard(type),
        ],
      ),
    );
  }

  Widget _buildTotalBalanceCard(double total) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text('Total Balance',
              style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 8),
          Text(
            '${total.toStringAsFixed(2)} CM',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text('All Wallets Combined',
              style: TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildWalletCard(
      String title, double balance, Color color, IconData icon,
      {bool fullWidth = false}) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 4),
                Text(
                  '${balance.toStringAsFixed(2)} CM',
                  style: TextStyle(
                      color: color, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceInfo(String label, double value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          '${value.toStringAsFixed(2)} CM',
          style: TextStyle(
              color: color, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            'Withdraw',
            Icons.arrow_upward,
            Colors.grey,
            () => _showSnackBar('Withdrawals are currently disabled',
                isError: true),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionButton('Transfer', Icons.send,
              const Color(0xFF3D5AFE), () => _showTransferDialog('purchase')),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionButton('Internal', Icons.swap_horiz,
              AppColors.success, _showInternalTransferDialog),
        ),
      ],
    );
  }

  Widget _buildActionButton(
      String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionsList() {
    if (_transactions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        child: const Column(
          children: [
            Icon(Icons.receipt_long, color: Colors.grey, size: 48),
            SizedBox(height: 12),
            Text('No transactions yet', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _transactions.length > 5 ? 5 : _transactions.length,
      itemBuilder: (context, index) {
        final tx = _transactions[index];
        return _buildTransactionItem(tx);
      },
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> tx) {
    final type = tx['type'] ?? 'unknown';
    final amount = (tx['amount'] ?? 0).toDouble();
    final status = tx['status'] ?? 'pending';
    final createdAt = tx['createdAt'] ?? '';

    IconData icon;
    Color color;

    switch (type) {
      case 'mining_reward':
        icon = Icons.memory;
        color = AppColors.success;
        break;
      case 'purchase':
        icon = Icons.shopping_cart;
        color = const Color(0xFF3D5AFE);
        break;
      case 'withdrawal':
        icon = Icons.arrow_upward;
        color = AppColors.error;
        break;
      case 'referral_bonus':
        icon = Icons.people;
        color = AppColors.warning;
        break;
      case 'transfer':
        icon = Icons.swap_horiz;
        color = Colors.purple;
        break;
      default:
        icon = Icons.receipt;
        color = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type.replaceAll('_', ' ').toUpperCase(),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500),
                ),
                Text(
                  _formatDate(createdAt),
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${type == 'withdrawal' || type == 'transfer' ? '-' : '+'}${amount.toStringAsFixed(2)} CM',
                style: TextStyle(
                  color: type == 'withdrawal'
                      ? AppColors.error
                      : AppColors.success,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              _buildStatusBadge(status),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status) {
      case 'completed':
        color = AppColors.success;
        break;
      case 'pending':
        color = AppColors.warning;
        break;
      case 'failed':
      case 'rejected':
        color = AppColors.error;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.toUpperCase(),
        style:
            TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildInfoCard(String type) {
    final info = type == 'mining'
        ? 'Mining Wallet contains coins earned from mining sessions. These coins are auto-credited when mining cycle completes.'
        : 'Purchase Wallet contains coins bought through coin packages. Use these for transfers and withdrawals.';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.grey, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(info,
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  void _showWithdrawDialog(String walletType) {
    final amountController = TextEditingController();
    final addressController = TextEditingController();
    String selectedNetwork = 'BSC';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text('Withdraw Coins', style: AppTextStyles.heading2),
              const SizedBox(height: 20),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Amount',
                  labelStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: AppColors.cardLight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  suffixText: 'CM',
                  suffixStyle: const TextStyle(color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedNetwork,
                dropdownColor: AppColors.cardLight,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Network',
                  labelStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: AppColors.cardLight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: ['BSC', 'ETH', 'TRON', 'POLYGON'].map((network) {
                  return DropdownMenuItem(value: network, child: Text(network));
                }).toList(),
                onChanged: (value) {
                  setModalState(() => selectedNetwork = value!);
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: addressController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Wallet Address',
                  labelStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: AppColors.cardLight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final amount = double.tryParse(amountController.text);
                    if (amount == null || amount <= 0) {
                      _showSnackBar('Enter valid amount', isError: true);
                      return;
                    }
                    if (addressController.text.isEmpty) {
                      _showSnackBar('Enter wallet address', isError: true);
                      return;
                    }

                    Navigator.pop(context);
                    try {
                      await ApiService.requestWithdrawal(
                        amount: amount,
                        network: selectedNetwork,
                        address: addressController.text,
                        walletType: walletType,
                      );
                      _showSnackBar('Withdrawal requested!', isSuccess: true);
                      _loadData();
                    } catch (e) {
                      _showSnackBar('Error: $e', isError: true);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Request Withdrawal',
                      style: TextStyle(
                          color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTransferDialog(String walletType) {
    final amountController = TextEditingController();
    final emailController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        decoration: const BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Transfer Coins', style: AppTextStyles.heading2),
            const SizedBox(height: 20),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Recipient Email',
                labelStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: AppColors.cardLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(Icons.email, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Amount',
                labelStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: AppColors.cardLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                suffixText: 'CM',
                suffixStyle: const TextStyle(color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final amount = double.tryParse(amountController.text);
                  if (amount == null || amount <= 0) {
                    _showSnackBar('Enter valid amount', isError: true);
                    return;
                  }
                  if (emailController.text.isEmpty) {
                    _showSnackBar('Enter recipient email', isError: true);
                    return;
                  }

                  Navigator.pop(context);
                  try {
                    await ApiService.transferCoins(
                      recipientEmail: emailController.text,
                      amount: amount,
                      walletType: walletType,
                    );
                    _showSnackBar('Transfer successful!', isSuccess: true);
                    _loadData();
                  } catch (e) {
                    _showSnackBar('Error: $e', isError: true);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3D5AFE),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Transfer',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showInternalTransferDialog() {
    final amountController = TextEditingController();
    String fromWallet = 'mining';
    String toWallet = 'purchase';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text('Internal Transfer', style: AppTextStyles.heading2),
              const Text('Transfer between your wallets',
                  style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: fromWallet,
                      dropdownColor: AppColors.cardLight,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'From',
                        labelStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: AppColors.cardLight,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'mining', child: Text('Mining')),
                        DropdownMenuItem(
                            value: 'purchase', child: Text('Purchase')),
                      ],
                      onChanged: (value) {
                        setModalState(() {
                          fromWallet = value!;
                          toWallet =
                              fromWallet == 'mining' ? 'purchase' : 'mining';
                        });
                      },
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(Icons.arrow_forward, color: AppColors.primary),
                  ),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: toWallet,
                      dropdownColor: AppColors.cardLight,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'To',
                        labelStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: AppColors.cardLight,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'mining', child: Text('Mining')),
                        DropdownMenuItem(
                            value: 'purchase', child: Text('Purchase')),
                      ],
                      onChanged: (value) {
                        setModalState(() {
                          toWallet = value!;
                          fromWallet =
                              toWallet == 'mining' ? 'purchase' : 'mining';
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Amount',
                  labelStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: AppColors.cardLight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  suffixText: 'CM',
                  suffixStyle: const TextStyle(color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final amount = double.tryParse(amountController.text);
                    if (amount == null || amount <= 0) {
                      _showSnackBar('Enter valid amount', isError: true);
                      return;
                    }

                    Navigator.pop(context);
                    try {
                      await ApiService.internalTransfer(
                        fromWallet: fromWallet,
                        toWallet: toWallet,
                        amount: amount,
                      );
                      _showSnackBar('Transfer successful!', isSuccess: true);
                      _loadData();
                    } catch (e) {
                      _showSnackBar('Error: $e', isError: true);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Transfer',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String dateString) {
    if (dateString.isEmpty) return '';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }
}
