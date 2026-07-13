import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';

class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});

  // Static key to access referral screen state from outside
  static final GlobalKey<ReferralScreenState> globalKey =
      GlobalKey<ReferralScreenState>();

  @override
  State<ReferralScreen> createState() => ReferralScreenState();
}

class ReferralScreenState extends State<ReferralScreen> {
  Map<String, dynamic>? _referralData;
  Map<String, dynamic>? _shareData;
  Map<String, dynamic>? _referralSettings;
  List<dynamic> _referrals = [];
  bool _isLoading = true;

  // Public method to refresh from outside
  void refreshReferrals() {
    if (mounted && !_isLoading) {
      _loadData(showLoading: false);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({bool showLoading = true}) async {
    if (showLoading) {
      setState(() => _isLoading = true);
    }
    try {
      final referrals = await ApiService.getReferrals();
      final share = await ApiService.getShareLink();
      final settings = await ApiService.getReferralSettings();
      if (mounted) {
        setState(() {
          _referralData = referrals;
          _referrals = referrals['referrals'] ?? [];
          _shareData = share;
          _referralSettings = settings;
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

  void _copyReferralCode() {
    final code = _shareData?['referralCode'] ?? '';
    if (code.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: code));
      _showSnackBar('Referral code copied!', isSuccess: true);
      HapticFeedback.mediumImpact();
    }
  }

  void _copyShareLink() {
    final link = _shareData?['shareLink'] ?? '';
    if (link.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: link));
      _showSnackBar('Share link copied!', isSuccess: true);
      HapticFeedback.mediumImpact();
    }
  }

  Future<void> _pingReferral(String userId, String userName) async {
    if (userId.isEmpty) {
      _showSnackBar('Invalid user ID', isError: true);
      return;
    }
    
    HapticFeedback.mediumImpact();

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );

    try {
      final result = await ApiService.pingInactiveReferrals(userId);
      if (mounted) Navigator.pop(context); // Close loading
      _showSnackBar(result['message'] ?? 'Pinged $userName!',
          isSuccess: true);
    } catch (e) {
      if (mounted) Navigator.pop(context); // Close loading
      final errorMsg = e.toString().replaceAll('Exception: ', '');
      _showSnackBar(errorMsg, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.cardDark,
        title: const Text('Referrals', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stats Card
                    _buildStatsCard(),
                    const SizedBox(height: 20),

                    // Referral Code Card
                    _buildReferralCodeCard(),
                    const SizedBox(height: 20),

                    // Share Link Card
                    _buildShareLinkCard(),
                    const SizedBox(height: 20),

                    // How it works
                    _buildHowItWorks(),
                    const SizedBox(height: 24),

                    // Referral List
                    const Text('Your Referrals', style: AppTextStyles.heading3),
                    const SizedBox(height: 12),
                    _buildReferralsList(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatsCard() {
    final stats = _referralData?['stats'] ?? {};
    final totalReferrals =
        stats['totalReferrals'] ?? stats['directReferrals'] ?? 0;
    final activeReferrals =
        stats['activeCount'] ?? stats['activeReferrals'] ?? 0;
    final inactiveReferrals =
        stats['inactiveCount'] ?? (totalReferrals - activeReferrals);
    final totalEarnings =
        (stats['totalEarned'] ?? stats['totalEarnings'] ?? 0).toDouble();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF8C00), Color(0xFFFFD700)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.warning.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.people, color: Colors.white, size: 48),
          const SizedBox(height: 12),
          const Text(
            'Total Earnings',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            '${totalEarnings.toStringAsFixed(2)} OLR',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatItem('Total', totalReferrals.toString(), Icons.group),
              Container(width: 1, height: 40, color: Colors.white24),
              _buildStatItem(
                  'Active', activeReferrals.toString(), Icons.check_circle),
              Container(width: 1, height: 40, color: Colors.white24),
              _buildStatItem(
                  'Inactive', inactiveReferrals.toString(), Icons.schedule),
            ],
          ),
          // Bulk ping button removed since backend requires individual user pings.
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 8),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  Widget _buildReferralCodeCard() {
    final code = _shareData?['referralCode'] ?? 'N/A';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.qr_code, color: AppColors.primary, size: 24),
              SizedBox(width: 12),
              Text('Your Referral Code', style: AppTextStyles.heading3),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.cardLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    code,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _copyReferralCode,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.copy, color: Colors.black, size: 24),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShareLinkCard() {
    final link = _shareData?['shareLink'] ?? '';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.share, color: AppColors.success, size: 24),
              SizedBox(width: 12),
              Text('Share Link', style: AppTextStyles.heading3),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.cardLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    link.isEmpty ? 'No link available' : link,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: _copyShareLink,
                  child: const Icon(Icons.copy,
                      color: AppColors.success, size: 20),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildShareButton(
                    'WhatsApp', Icons.chat, const Color(0xFF25D366)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildShareButton(
                    'Telegram', Icons.send, const Color(0xFF0088CC)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildShareButton('More', Icons.share, Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShareButton(String label, IconData icon, Color color) {
    return GestureDetector(
      onTap: _copyShareLink, // In real app, implement actual sharing
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildHowItWorks() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb_outline, color: AppColors.warning, size: 24),
              SizedBox(width: 12),
              Text('How it Works', style: AppTextStyles.heading3),
            ],
          ),
          const SizedBox(height: 16),
          _buildStep('1', 'Share your referral code or link with friends'),
          const SizedBox(height: 12),
          _buildStep('2', 'They sign up using your code'),
          const SizedBox(height: 12),
          _buildStep('3',
              'You get ${_referralSettings?['directReferralBonus'] ?? 1} OLR and they get ${_referralSettings?['signupBonus'] ?? 1} OLR!'),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: AppColors.success.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.card_giftcard,
                    color: AppColors.success, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Earn ${_referralSettings?['directReferralBonus'] ?? 1} OLR coins for each successful referral!',
                    style: const TextStyle(
                        color: AppColors.success,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(String number, String text) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                  color: AppColors.primary, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text,
              style: const TextStyle(color: Colors.grey, fontSize: 13)),
        ),
      ],
    );
  }

  Widget _buildReferralsList() {
    if (_referrals.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          children: [
            Icon(Icons.people_outline, color: Colors.grey, size: 48),
            SizedBox(height: 12),
            Text('No referrals yet', style: TextStyle(color: Colors.grey)),
            SizedBox(height: 8),
            Text(
              'Share your code to start earning!',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _referrals.length,
      itemBuilder: (context, index) {
        final referral = _referrals[index];
        return _buildReferralItem(referral);
      },
    );
  }

  Widget _buildReferralItem(Map<String, dynamic> referral) {
    // Debug: debugPrint referral data
    debugPrint('Referral data: $referral');

    // Backend returns 'user' key containing referred user info
    final user = referral['user'];
    final name =
        (user != null && user['name'] != null) ? user['name'] : 'Unknown User';
    final email = (user != null && user['email'] != null) ? user['email'] : '';
    final avatar = (user != null) ? user['avatar'] : null;

    // Backend returns 'isActive' boolean
    final isActive = referral['isActive'] ?? false;

    // Backend returns 'coinsEarned' for the bonus amount
    final bonus = (referral['coinsEarned'] ?? 0).toDouble();

    // Use createdAt for join date
    final joinedAt = referral['createdAt'] ?? '';

    // Get first letter safely
    final firstLetter =
        name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';

    final userId = (user != null) 
        ? (user['_id']?.toString() ?? user['id']?.toString() ?? '')
        : (referral['_id']?.toString() ?? referral['id']?.toString() ?? '');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive
              ? AppColors.success.withValues(alpha: 0.3)
              : Colors.grey.withValues(alpha: 0.2),
        ),
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
            child: avatar != null && avatar.toString().isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      avatar,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(
                        child: Text(
                          firstLetter,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  )
                : Center(
                    child: Text(
                      firstLetter,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
                if (email.isNotEmpty)
                  Text(email,
                      style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 4),
                Text(
                  'Joined: ${_formatDate(joinedAt)}',
                  style: const TextStyle(color: Colors.grey, fontSize: 10),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.success.withValues(alpha: 0.15)
                      : Colors.grey.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isActive ? 'ACTIVE' : 'INACTIVE',
                  style: TextStyle(
                    color: isActive ? AppColors.success : Colors.grey,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (!isActive)
                GestureDetector(
                  onTap: () => _pingReferral(userId, name),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.notifications_active, size: 12, color: AppColors.primary),
                        SizedBox(width: 4),
                        Text('Ping', style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                )
              else
                Text(
                  '+${bonus.toStringAsFixed(0)} OLR',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateString) {
    if (dateString.isEmpty) return '';
    try {
      final date = DateTime.parse(dateString).toLocal();
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }
}
