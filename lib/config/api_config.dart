/// API Configuration
/// Centralized location for all API endpoints
class ApiConfig {
  // Base URL
  // Base URL
  static const String rootUrl = 'https://api.olaroclub.online';
  static const String baseUrl = '$rootUrl/api';

  // ==================== AUTH ENDPOINTS ====================
  static const String googleSignIn = '$baseUrl/auth/google';
  static const String getCurrentUser = '$baseUrl/auth/me';
  static const String logout = '$baseUrl/auth/logout';

  // ==================== USER ENDPOINTS ====================
  static const String userProfile = '$baseUrl/users/profile';
  static const String uploadAvatar = '$baseUrl/user/avatar';
  static const String userDashboard = '$baseUrl/users/dashboard';
  static const String userStats = '$baseUrl/users/stats';
  static const String userActivity = '$baseUrl/users/activity';
  static const String dailyCheckIn = '$baseUrl/users/daily-checkin';
  static const String redeemCode = '$baseUrl/users/redeem-code';
  static const String changePassword = '$baseUrl/users/password';
  static const String deleteAccount = '$baseUrl/users/account';

  // ==================== MINING ENDPOINTS ====================
  static const String miningStatus = '$baseUrl/mining/status';
  static const String startMining = '$baseUrl/mining/start';
  static const String claimMining = '$baseUrl/mining/claim';
  static const String cancelMining = '$baseUrl/mining/cancel';
  static const String miningHistory = '$baseUrl/mining/history';
  static const String miningLeaderboard = '$baseUrl/mining/leaderboard';
  static const String boostMining = '$baseUrl/mining/boost';
  static const String rewardsBreakdown = '$baseUrl/mining/rewards';

  // ==================== WALLET ENDPOINTS ====================
  static const String wallet = '$baseUrl/wallet';
  static const String miningWallet = '$baseUrl/wallet/mining';
  static const String purchaseWallet = '$baseUrl/wallet/purchase';
  static const String walletSummary = '$baseUrl/wallet/summary';
  static const String internalTransfer = '$baseUrl/wallet/internal-transfer';
  static const String withdrawalAddress = '$baseUrl/wallet/withdrawal-address';
  static const String withdraw = '$baseUrl/wallet/withdraw';
  static const String transactions = '$baseUrl/wallet/transactions';

  // ==================== COIN ENDPOINTS ====================
  static const String coinPackages = '$baseUrl/coins/packages';
  static const String coinRate = '$baseUrl/coins/rate';
  static const String coinBalance = '$baseUrl/coins/balance';
  static const String coinTransactions = '$baseUrl/coins/me/transactions';
  static const String purchaseCoins = '$baseUrl/coins/purchase';
  static const String coinPurchases = '$baseUrl/coins/purchases';
  static const String transferCoins = '$baseUrl/coins/transfer';
  static const String paymentInfo = '$baseUrl/coins/payment-info';
  static const String submitTransaction = '$baseUrl/coins/submit-transaction';
  static const String createPaymentLink = '$baseUrl/coins/create-payment-link';
  static const String cryptoDeposit = '$baseUrl/coins/crypto-deposit';
  static const String cryptoNetworks = '$baseUrl/coins/crypto-networks';

  // ==================== REFERRAL ENDPOINTS ====================
  static const String referrals = '$baseUrl/referrals';
  static const String referralShare = '$baseUrl/referrals/share';
  static const String referralEarnings = '$baseUrl/referrals/earnings';
  static const String pingReferrals = '$baseUrl/referrals/ping';
  static const String referralSettings =
      '$baseUrl/referrals/public-refferal-settings';

  // ==================== NOTIFICATION ENDPOINTS ====================
  static const String notifications = '$baseUrl/notifications';
  static const String unreadNotificationCount =
      '$baseUrl/notifications/unread-count';
  static const String markAllNotificationsRead =
      '$baseUrl/notifications/read-all';

  // ==================== SETTINGS ENDPOINTS ====================
  static const String settings = '$baseUrl/settings';
  static const String socialLinks = '$baseUrl/settings/social';
  static const String maintenance = '$baseUrl/settings/maintenance';

  // ==================== FEED ENDPOINTS ====================
  static const String activeFeeds = '$baseUrl/admin/feed/active';

  // ==================== BANNER ENDPOINTS ====================
  static const String activeBanners = '$baseUrl/admin/banners/active';

  // ==================== KYC ENDPOINTS ====================
  static const String kycStatus = '$baseUrl/kyc/status';
  static const String kycSubmit = '$baseUrl/kyc/submit';
  static const String kycResubmit = '$baseUrl/kyc/resubmit';

  // ==================== DYNAMIC ENDPOINTS ====================
  // Endpoints that require path parameters

  /// Get transaction by ID
  /// Usage: ApiConfig.getTransaction('transaction_id')
  static String getTransaction(String id) => '$baseUrl/wallet/transactions/$id';

  /// Submit payment proof for a purchase
  /// Usage: ApiConfig.submitPaymentProof('transaction_id')
  static String submitPaymentProof(String transactionId) =>
      '$baseUrl/coins/purchase/$transactionId/proof';

  /// Cancel a coin purchase
  /// Usage: ApiConfig.cancelPurchase('transaction_id')
  static String cancelPurchase(String transactionId) =>
      '$baseUrl/coins/purchase/$transactionId/cancel';

  /// Validate referral code
  /// Usage: ApiConfig.validateReferralCode('code')
  static String validateReferralCode(String code) =>
      '$baseUrl/referrals/validate/$code';

  /// Mark notification as read
  /// Usage: ApiConfig.markNotificationRead('notification_id')
  static String markNotificationRead(String id) =>
      '$baseUrl/notifications/$id/read';

  /// Delete notification
  /// Usage: ApiConfig.deleteNotification('notification_id')
  static String deleteNotification(String id) => '$baseUrl/notifications/$id';

  /// Get single public post
  /// Usage: ApiConfig.getSinglePublicPost('feed_id')
  static String getSinglePublicPost(String feedId) =>
      '$baseUrl/community/post/$feedId';

  /// Get public feed
  static const String publicFeed = '$baseUrl/community/public';

  /// Like feed item
  /// Usage: ApiConfig.likeFeed('feed_id')
  static String likeFeed(String feedId) => '$baseUrl/community/$feedId/like';

  /// Comment on feed item
  /// Usage: ApiConfig.commentFeed('feed_id')
  static String commentFeed(String feedId) =>
      '$baseUrl/community/$feedId/comment';

  /// Share feed item
  /// Usage: ApiConfig.shareFeed('feed_id')
  static String shareFeed(String feedId) => '$baseUrl/community/$feedId/share';

  /// Record banner view
  /// Usage: ApiConfig.recordBannerView('banner_id')
  static String recordBannerView(String bannerId) =>
      '$baseUrl/admin/banners/$bannerId/view';

  /// Record banner click
  /// Usage: ApiConfig.recordBannerClick('banner_id')
  static String recordBannerClick(String bannerId) =>
      '$baseUrl/admin/banners/$bannerId/click';

  /// Get KYC details by ID
  /// Usage: ApiConfig.getKYCDetails('kyc_id')
  static String getKYCDetails(String id) => '$baseUrl/kyc/getKYCDetails/$id';

  // ==================== QUERY PARAMETERS HELPERS ====================

  /// Build URL with query parameters
  /// Usage: ApiConfig.withParams(ApiConfig.userActivity, {'page': '1'})
  static String withParams(String endpoint, Map<String, String> params) {
    if (params.isEmpty) return endpoint;
    final query = params.entries.map((e) => '${e.key}=${e.value}').join('&');
    return '$endpoint?$query';
  }
}
