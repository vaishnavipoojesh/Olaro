import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<dynamic> _notifications = [];
  bool _isLoading = true;
  int _currentPage = 1;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadNotifications();
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
      if (_hasMore && !_isLoading) {
        _loadMore();
      }
    }
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _currentPage = 1;
    });
    try {
      final result = await ApiService.getNotifications(page: 1);
      setState(() {
        _notifications = result['notifications'] ?? [];
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
      final result = await ApiService.getNotifications(page: _currentPage + 1);
      setState(() {
        _notifications.addAll(result['notifications'] ?? []);
        _currentPage++;
        _hasMore = (result['pagination']?['hasMore'] ?? false);
      });
    } catch (e) {
      _showSnackBar('Error loading more: $e', isError: true);
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

  Future<void> _markAsRead(String id) async {
    try {
      await ApiService.markNotificationAsRead(id);
      _loadNotifications();
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      await ApiService.markAllNotificationsAsRead();
      _showSnackBar('All marked as read', isSuccess: true);
      _loadNotifications();
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    }
  }

  Future<void> _deleteNotification(String id) async {
    try {
      await ApiService.deleteNotification(id);
      _showSnackBar('Notification deleted', isSuccess: true);
      _loadNotifications();
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.cardDark,
        title:
            const Text('Notifications', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'Mark all as read',
            onPressed: _markAllAsRead,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadNotifications,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _loadNotifications,
              color: AppColors.primary,
              child: _notifications.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _notifications.length + (_hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _notifications.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                                child: CircularProgressIndicator(
                                    color: AppColors.primary)),
                          );
                        }
                        return _buildNotificationItem(_notifications[index]);
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
          Icon(Icons.notifications_off, color: Colors.grey[600], size: 64),
          const SizedBox(height: 16),
          const Text(
            'No Notifications',
            style: TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'You\'re all caught up!',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(Map<String, dynamic> notification) {
    final title = notification['title'] ?? 'Notification';
    final message = notification['message'] ?? '';
    final type = notification['type'] ?? 'info';
    // Backend uses 'read' field, not 'isRead'
    final isRead = notification['read'] ?? notification['isRead'] ?? false;
    final createdAt = notification['createdAt'] ?? '';
    final id = notification['_id'] ?? '';

    IconData icon;
    Color color;

    switch (type) {
      case 'mining':
        icon = Icons.memory;
        color = AppColors.success;
        break;
      case 'referral':
        icon = Icons.people;
        color = AppColors.warning;
        break;
      case 'wallet':
      case 'withdrawal':
        icon = Icons.account_balance_wallet;
        color = const Color(0xFF3D5AFE);
        break;
      case 'kyc':
        icon = Icons.verified_user;
        color = Colors.purple;
        break;
      case 'promo':
        icon = Icons.card_giftcard;
        color = Colors.pink;
        break;
      case 'system':
        icon = Icons.settings;
        color = Colors.grey;
        break;
      default:
        icon = Icons.notifications;
        color = AppColors.primary;
    }

    return Dismissible(
      key: Key(id),
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _deleteNotification(id),
      child: GestureDetector(
        onTap: () {
          if (!isRead) _markAsRead(id);
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isRead ? AppColors.cardDark : AppColors.cardLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isRead ? Colors.transparent : color.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
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
                            title,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight:
                                  isRead ? FontWeight.normal : FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (!isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatTime(createdAt),
                      style: TextStyle(color: Colors.grey[600], fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(String dateString) {
    if (dateString.isEmpty) return '';
    try {
      final date = DateTime.parse(dateString).toLocal();
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }
}
