import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen>
    with SingleTickerProviderStateMixin {
  List<dynamic> _transactions = [];
  bool _isLoading = true;
  int _currentPage = 1;
  bool _hasMore = true;
  late TabController _tabController;
  String? _currentFilter;
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, dynamic>> _filters = [
    {'label': 'All', 'value': null},
    {'label': 'Mining', 'value': 'mining_reward'},
    {'label': 'Purchase', 'value': 'purchase'},
    {'label': 'Withdrawal', 'value': 'withdrawal'},
    {'label': 'Referral', 'value': 'referral_bonus'},
    {'label': 'Transfer', 'value': 'transfer'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _filters.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    _scrollController.addListener(_onScroll);
    _loadTransactions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    setState(() {
      _currentFilter = _filters[_tabController.index]['value'];
      _transactions = [];
      _currentPage = 1;
      _hasMore = true;
    });
    _loadTransactions();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (_hasMore && !_isLoading) {
        _loadMore();
      }
    }
  }

  Future<void> _loadTransactions() async {
    setState(() {
      _isLoading = true;
      _currentPage = 1;
    });
    try {
      final result =
          await ApiService.getTransactions(page: 1, type: _currentFilter);
      setState(() {
        _transactions = result['transactions'] ?? [];
        _hasMore = (result['pagination']?['hasMore'] ?? false);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error: $e', isError: true);
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore) return;

    try {
      final result = await ApiService.getTransactions(
          page: _currentPage + 1, type: _currentFilter);
      setState(() {
        _transactions.addAll(result['transactions'] ?? []);
        _currentPage++;
        _hasMore = (result['pagination']?['hasMore'] ?? false);
      });
    } catch (e) {
      _showSnackBar('Error loading more: $e', isError: true);
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
        title: const Text('Transaction History',
            style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTransactions,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          tabs: _filters.map((f) => Tab(text: f['label'])).toList(),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _loadTransactions,
              color: AppColors.primary,
              child: _transactions.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _transactions.length + (_hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _transactions.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                                child: CircularProgressIndicator(
                                    color: AppColors.primary)),
                          );
                        }
                        return _buildTransactionItem(_transactions[index]);
                      },
                    ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, color: Colors.grey[600], size: 64),
          const SizedBox(height: 16),
          const Text(
            'No Transactions',
            style: TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            _currentFilter != null
                ? 'No ${_filters[_tabController.index]['label'].toLowerCase()} transactions found'
                : 'Start mining or purchase coins to see transactions',
            style: const TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> tx) {
    final type = tx['type'] ?? 'unknown';
    final amount = (tx['amount'] ?? 0).toDouble();
    final coins = tx['coins']; // Can be positive or negative
    final status = tx['status'] ?? 'pending';
    final createdAt = tx['createdAt'] ?? '';
    final description = tx['description'] ?? _getTypeDescription(type);
    final metadata = tx['metadata'] ?? {};
    final walletType = metadata['walletType'] ?? '';

    // Determine if this is incoming (earned) or outgoing (spent)
    // Check coins field first (negative = spent), then fall back to type
    bool isIncoming;
    if (coins != null) {
      isIncoming = (coins as num) >= 0;
    } else {
      // Types that are outgoing (spending coins)
      isIncoming = !['withdrawal', 'transfer_out', 'boost'].contains(type);
      
      // Check description for boost purchases
      if (description.toLowerCase().contains('boost')) {
        isIncoming = false;
      }
    }

    IconData icon;
    Color color;

    switch (type) {
      case 'mining_reward':
        icon = Icons.memory;
        color = AppColors.success;
        break;
      case 'purchase':
        // Check if it's a boost purchase (spending) or coin purchase (buying)
        if (description.toLowerCase().contains('boost')) {
          icon = Icons.flash_on;
          color = AppColors.warning;
        } else {
          icon = Icons.shopping_cart;
          color = const Color(0xFF3D5AFE);
        }
        break;
      case 'withdrawal':
        icon = Icons.arrow_upward;
        color = AppColors.error;
        break;
      case 'referral_bonus':
      case 'referral':
        icon = Icons.people;
        color = AppColors.warning;
        break;
      case 'transfer':
      case 'transfer_in':
      case 'transfer_out':
        icon = Icons.swap_horiz;
        color = Colors.purple;
        break;
      case 'daily_checkin':
        icon = Icons.calendar_today;
        color = Colors.pink;
        break;
      case 'promo_code':
        icon = Icons.card_giftcard;
        color = Colors.teal;
        break;
      default:
        icon = Icons.receipt;
        color = Colors.grey;
    }

    return GestureDetector(
      onTap: () => _showTransactionDetails(tx),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          description,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Text(
                        '${isIncoming ? '+' : '-'}${amount.toStringAsFixed(2)} CM',
                        style: TextStyle(
                          color:
                              isIncoming ? AppColors.success : AppColors.error,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        _formatDate(createdAt),
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      if (walletType.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            walletType.toUpperCase(),
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 9),
                          ),
                        ),
                      ],
                      const Spacer(),
                      _buildStatusBadge(status),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
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
      case 'processing':
        color = const Color(0xFF3D5AFE);
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.toUpperCase(),
        style:
            TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _showTransactionDetails(Map<String, dynamic> tx) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Transaction Details', style: AppTextStyles.heading2),
            const SizedBox(height: 24),
            _buildDetailRow('Type', _getTypeDescription(tx['type'] ?? '')),
            _buildDetailRow(
                'Amount', '${(tx['amount'] ?? 0).toStringAsFixed(2)} CM'),
            _buildDetailRow('Status', (tx['status'] ?? '').toUpperCase()),
            if (tx['metadata']?['walletType'] != null)
              _buildDetailRow('Wallet',
                  tx['metadata']['walletType'].toString().toUpperCase()),
            if (tx['network'] != null)
              _buildDetailRow('Network', tx['network']),
            if (tx['address'] != null)
              _buildDetailRow(
                  'Address', '${tx['address'].substring(0, 10)}...'),
            _buildDetailRow('Date', _formatDate(tx['createdAt'] ?? '')),
            if (tx['transactionId'] != null)
              _buildDetailRow('TX ID',
                  '${tx['transactionId'].toString().substring(0, 12)}...'),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Close',
                    style: TextStyle(
                        color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  String _getTypeDescription(String type) {
    switch (type) {
      case 'mining_reward':
        return 'Mining Reward';
      case 'purchase':
        return 'Coin Purchase';
      case 'withdrawal':
        return 'Withdrawal';
      case 'referral_bonus':
        return 'Referral Bonus';
      case 'transfer':
      case 'transfer_in':
        return 'Coins Received';
      case 'transfer_out':
        return 'Coins Sent';
      case 'daily_checkin':
        return 'Daily Check-in';
      case 'promo_code':
        return 'Promo Code Reward';
      default:
        return type.replaceAll('_', ' ').toUpperCase();
    }
  }

  String _formatDate(String dateString) {
    if (dateString.isEmpty) return '';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }
}
