import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' as http_parser;
import '../config/api_config.dart';

class ApiService {
  static String? _authToken;

  // Set auth token after login
  static void setAuthToken(String token) {
    _authToken = token;
  }

  // Clear auth token on logout
  static void clearAuthToken() {
    _authToken = null;
  }

  // Get headers with auth token
  static Map<String, String> get _headers {
    final headers = {'Content-Type': 'application/json'};
    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    return headers;
  }

  // ==================== AUTH APIs ====================

  // Google Sign In
  static Future<Map<String, dynamic>> googleSignIn({
    required String idToken,
    String? referralCode,
  }) async {
    final response = await http.post(
      Uri.parse(ApiConfig.googleSignIn),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'idToken': idToken,
        if (referralCode != null && referralCode.isNotEmpty)
          'referralCode': referralCode,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      setAuthToken(data['token']);
      return data;
    } else {
      throw Exception(data['message'] ?? 'Google sign in failed');
    }
  }

  // Get current user profile
  static Future<Map<String, dynamic>> getCurrentUser() async {
    final response = await http.get(
      Uri.parse(ApiConfig.getCurrentUser),
      headers: _headers,
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to get user');
    }
  }

  // Logout
  static Future<void> logout() async {
    try {
      await http.post(
        Uri.parse(ApiConfig.logout),
        headers: _headers,
      );
    } finally {
      clearAuthToken();
    }
  }

  // ==================== USER APIs ====================

  // Get user profile
  static Future<Map<String, dynamic>> getProfile() async {
    final response = await http.get(
      Uri.parse(ApiConfig.userProfile),
      headers: _headers,
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to get profile');
    }
  }

  // Update user profile
  static Future<Map<String, dynamic>> updateProfile({
    String? name,
    String? phone,
  }) async {
    final response = await http.put(
      Uri.parse(ApiConfig.userProfile),
      headers: _headers,
      body: jsonEncode({
        if (name != null) 'name': name,
        if (phone != null) 'phone': phone,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to update profile');
    }
  }

  // Upload avatar
  static Future<Map<String, dynamic>> uploadAvatar(File imageFile) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiConfig.uploadAvatar),
      );

      request.headers['Authorization'] = 'Bearer $_authToken';

      // Get file extension
      final extension = imageFile.path.split('.').last.toLowerCase();
      final mimeType = extension == 'png' ? 'image/png' : 'image/jpeg';

      request.files.add(await http.MultipartFile.fromPath(
        'avatar',
        imageFile.path,
        contentType: http_parser.MediaType.parse(mimeType),
      ));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Failed to upload avatar');
      }
    } catch (e) {
      throw Exception('Upload failed: $e');
    }
  }

  // Get user dashboard
  static Future<Map<String, dynamic>> getDashboard() async {
    final response = await http.get(
      Uri.parse(ApiConfig.userDashboard),
      headers: _headers,
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to get dashboard');
    }
  }

  // Get user stats
  static Future<Map<String, dynamic>> getStats() async {
    final response = await http.get(
      Uri.parse(ApiConfig.userStats),
      headers: _headers,
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to get stats');
    }
  }

  // Get user activity
  static Future<Map<String, dynamic>> getActivity({int page = 1}) async {
    final response = await http.get(
      Uri.parse(ApiConfig.withParams(
          ApiConfig.userActivity, {'page': page.toString()})),
      headers: _headers,
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to get activity');
    }
  }

  // Daily check-in status
  static Future<Map<String, dynamic>> getCheckinStatus() async {
    final response = await http.get(
      Uri.parse(ApiConfig.dailyCheckIn),
      headers: _headers,
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to get check-in status');
    }
  }

  // Daily check-in
  static Future<Map<String, dynamic>> dailyCheckIn() async {
    final response = await http.post(
      Uri.parse(ApiConfig.dailyCheckIn),
      headers: _headers,
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Check-in failed');
    }
  }

  // Redeem promo code
  static Future<Map<String, dynamic>> redeemPromoCode(String code) async {
    final response = await http.post(
      Uri.parse(ApiConfig.redeemCode),
      headers: _headers,
      body: jsonEncode({'code': code}),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to redeem promo code');
    }
  }

  // Change password
  static Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final response = await http.put(
      Uri.parse(ApiConfig.changePassword),
      headers: _headers,
      body: jsonEncode({
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to change password');
    }
  }

  // Delete account
  static Future<Map<String, dynamic>> deleteAccount() async {
    final response = await http.delete(
      Uri.parse(ApiConfig.deleteAccount),
      headers: _headers,
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      clearAuthToken();
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to delete account');
    }
  }

  // ==================== MINING APIs ====================

  // Get mining status
  static Future<Map<String, dynamic>> getMiningStatus() async {
    final response = await http.get(
      Uri.parse(ApiConfig.miningStatus),
      headers: _headers,
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to get mining status');
    }
  }

  // Start mining
  static Future<Map<String, dynamic>> startMining() async {
    final response = await http.post(
      Uri.parse(ApiConfig.startMining),
      headers: _headers,
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to start mining');
    }
  }

  // Claim mining rewards
  static Future<Map<String, dynamic>> claimMining() async {
    final response = await http.post(
      Uri.parse(ApiConfig.claimMining),
      headers: _headers,
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to claim rewards');
    }
  }

  // Cancel mining
  static Future<Map<String, dynamic>> cancelMining() async {
    final response = await http.post(
      Uri.parse(ApiConfig.cancelMining),
      headers: _headers,
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to cancel mining');
    }
  }

  // Get mining history
  static Future<Map<String, dynamic>> getMiningHistory({int page = 1}) async {
    final response = await http.get(
      Uri.parse(ApiConfig.withParams(
          ApiConfig.miningHistory, {'page': page.toString()})),
      headers: _headers,
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to get mining history');
    }
  }

  // Get mining leaderboard
  static Future<Map<String, dynamic>> getMiningLeaderboard() async {
    final response = await http.get(
      Uri.parse(ApiConfig.miningLeaderboard),
      headers: _headers,
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to get leaderboard');
    }
  }

  // Boost mining
  static Future<Map<String, dynamic>> boostMining(
      {String boostType = 'speed'}) async {
    final response = await http.post(
      Uri.parse(ApiConfig.boostMining),
      headers: _headers,
      body: jsonEncode({'boostType': boostType}),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to boost mining');
    }
  }

  // Get rewards breakdown
  static Future<Map<String, dynamic>> getRewardsBreakdown() async {
    final response = await http.get(
      Uri.parse(ApiConfig.rewardsBreakdown),
      headers: _headers,
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to get rewards breakdown');
    }
  }

  // ==================== WALLET APIs ====================

  // Get wallet (all wallets combined)
  static Future<Map<String, dynamic>> getWallet() async {
    final response = await http.get(
      Uri.parse(ApiConfig.wallet),
      headers: _headers,
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to get wallet');
    }
  }

  // Get mining wallet only
  static Future<Map<String, dynamic>> getMiningWallet() async {
    final response = await http.get(
      Uri.parse(ApiConfig.miningWallet),
      headers: _headers,
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to get mining wallet');
    }
  }

  // Get purchase wallet only
  static Future<Map<String, dynamic>> getPurchaseWallet() async {
    final response = await http.get(
      Uri.parse(ApiConfig.purchaseWallet),
      headers: _headers,
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to get purchase wallet');
    }
  }

  // Get wallet summary
  static Future<Map<String, dynamic>> getWalletSummary() async {
    final response = await http.get(
      Uri.parse(ApiConfig.walletSummary),
      headers: _headers,
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to get wallet summary');
    }
  }

  // Internal transfer between wallets
  static Future<Map<String, dynamic>> internalTransfer({
    required String fromWallet,
    required String toWallet,
    required double amount,
  }) async {
    final response = await http.post(
      Uri.parse(ApiConfig.internalTransfer),
      headers: _headers,
      body: jsonEncode({
        'fromWallet': fromWallet,
        'toWallet': toWallet,
        'amount': amount,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Transfer failed');
    }
  }

  // Update withdrawal address
  static Future<Map<String, dynamic>> updateWithdrawalAddress({
    required String network,
    required String address,
  }) async {
    final response = await http.put(
      Uri.parse(ApiConfig.withdrawalAddress),
      headers: _headers,
      body: jsonEncode({
        'network': network,
        'address': address,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to update address');
    }
  }

  // Request withdrawal
  static Future<Map<String, dynamic>> requestWithdrawal({
    required double amount,
    required String network,
    required String address,
    String walletType = 'auto', // 'mining', 'purchase', or 'auto'
  }) async {
    final response = await http.post(
      Uri.parse(ApiConfig.withdraw),
      headers: _headers,
      body: jsonEncode({
        'amount': amount,
        'network': network,
        'address': address,
        'walletType': walletType,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Withdrawal request failed');
    }
  }

  // Get transactions
  static Future<Map<String, dynamic>> getTransactions({
    int page = 1,
    String? type,
    String? status,
  }) async {
    final params = {'page': page.toString()};
    if (type != null) params['type'] = type;
    if (status != null) params['status'] = status;

    final response = await http.get(
      Uri.parse(ApiConfig.withParams(ApiConfig.transactions, params)),
      headers: _headers,
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to get transactions');
    }
  }

  // Get single transaction
  static Future<Map<String, dynamic>> getTransaction(String id) async {
    final response = await http.get(
      Uri.parse(ApiConfig.getTransaction(id)),
      headers: _headers,
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to get transaction');
    }
  }

  // ==================== COIN APIs ====================

  // Get coin packages
  static Future<Map<String, dynamic>> getCoinPackages() async {
    final response = await http.get(
      Uri.parse(ApiConfig.coinPackages),
      headers: {'Content-Type': 'application/json'},
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to get coin packages');
    }
  }

  // Get coin rate
  static Future<Map<String, dynamic>> getCoinRate() async {
    final response = await http.get(
      Uri.parse(ApiConfig.coinRate),
      headers: {'Content-Type': 'application/json'},
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to get coin rate');
    }
  }

  // Get coin balance
  static Future<Map<String, dynamic>> getCoinBalance() async {
    final response = await http.get(
      Uri.parse(ApiConfig.coinBalance),
      headers: _headers,
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to get coin balance');
    }
  }

  // Get coin transactions
  static Future<Map<String, dynamic>> getCoinTransactions() async {
    final response = await http.get(
      Uri.parse(ApiConfig.coinTransactions),
      headers: _headers,
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to get coin transactions');
    }
  }

  // Purchase coins
  static Future<Map<String, dynamic>> purchaseCoins({
    required String packageId,
    required String paymentMethod,
  }) async {
    final response = await http.post(
      Uri.parse(ApiConfig.purchaseCoins),
      headers: _headers,
      body: jsonEncode({
        'packageId': packageId,
        'paymentMethod': paymentMethod,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Purchase failed');
    }
  }

  // Submit payment proof
  static Future<Map<String, dynamic>> submitPaymentProof({
    required String transactionId,
    required File proofImage,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse(ApiConfig.submitPaymentProof(transactionId)),
    );

    request.headers['Authorization'] = 'Bearer $_authToken';
    request.files.add(
        await http.MultipartFile.fromPath('paymentProof', proofImage.path));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to submit payment proof');
    }
  }

  // Cancel purchase
  static Future<Map<String, dynamic>> cancelPurchase(
      String transactionId) async {
    final response = await http.post(
      Uri.parse(ApiConfig.cancelPurchase(transactionId)),
      headers: _headers,
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to cancel purchase');
    }
  }

  // Get purchase history
  static Future<Map<String, dynamic>> getPurchaseHistory({int page = 1}) async {
    final response = await http.get(
      Uri.parse(ApiConfig.withParams(
          ApiConfig.coinPurchases, {'page': page.toString()})),
      headers: _headers,
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to get purchase history');
    }
  }

  // Transfer coins
  static Future<Map<String, dynamic>> transferCoins({
    required String recipientEmail,
    required double amount,
    String walletType = 'purchase', // 'mining' or 'purchase'
    String? note,
  }) async {
    final response = await http.post(
      Uri.parse(ApiConfig.transferCoins),
      headers: _headers,
      body: jsonEncode({
        'recipientEmail': recipientEmail,
        'amount': amount,
        'walletType': walletType,
        if (note != null) 'note': note,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Transfer failed');
    }
  }

  // Get payment info (QR code, Payment ID, etc.)
  static Future<Map<String, dynamic>> getPaymentInfo() async {
    final response = await http.get(
      Uri.parse(ApiConfig.paymentInfo),
      headers: _headers,
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to get payment info');
    }
  }

  // Create payment link
  static Future<Map<String, dynamic>> createPaymentLink({
    required double amount,
    String currency = 'USD',
    String? description,
  }) async {
    final response = await http.post(
      Uri.parse(ApiConfig.createPaymentLink),
      headers: _headers,
      body: jsonEncode({
        'amountUSD': amount,
        'currency': currency,
        if (description != null) 'description': description,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to create payment link');
    }
  }

  // Submit transaction ID for coin purchase
  static Future<Map<String, dynamic>> submitTransaction({
    required String transactionId,
    required double amount,
    String? paymentApp,
  }) async {
    final response = await http.post(
      Uri.parse(ApiConfig.submitTransaction),
      headers: _headers,
      body: jsonEncode({
        'transactionId': transactionId,
        'amount': amount,
        if (paymentApp != null) 'paymentApp': paymentApp,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to submit transaction');
    }
  }

  // ==================== REFERRAL APIs ====================

  // Get referrals
  static Future<Map<String, dynamic>> getReferrals() async {
    final response = await http.get(
      Uri.parse(ApiConfig.referrals),
      headers: _headers,
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to get referrals');
    }
  }

  // Get referral share link
  static Future<Map<String, dynamic>> getShareLink() async {
    final response = await http.get(
      Uri.parse(ApiConfig.referralShare),
      headers: _headers,
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to get share link');
    }
  }

  // Get referral settings
  static Future<Map<String, dynamic>> getReferralSettings() async {
    final response = await http.get(
      Uri.parse(ApiConfig.referralSettings),
      headers: _headers,
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to get referral settings');
    }
  }

  // Get referral earnings
  static Future<Map<String, dynamic>> getReferralEarnings() async {
    final response = await http.get(
      Uri.parse(ApiConfig.referralEarnings),
      headers: _headers,
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to get referral earnings');
    }
  }

  // Ping inactive referrals
  static Future<Map<String, dynamic>> pingInactiveReferrals() async {
    final response = await http.post(
      Uri.parse(ApiConfig.pingReferrals),
      headers: _headers,
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    } else if (response.statusCode == 429) {
      // Rate limited - return the message but not as error
      throw Exception(data['message'] ?? 'You can ping again in 12 hours');
    } else {
      throw Exception(data['message'] ?? 'Failed to ping referrals');
    }
  }

  // Validate referral code
  static Future<Map<String, dynamic>> validateReferralCode(String code) async {
    final response = await http.get(
      Uri.parse(ApiConfig.validateReferralCode(code)),
      headers: {'Content-Type': 'application/json'},
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Invalid referral code');
    }
  }

  // ==================== NOTIFICATION APIs ====================

  // Get notifications
  static Future<Map<String, dynamic>> getNotifications({int page = 1}) async {
    final response = await http.get(
      Uri.parse(ApiConfig.withParams(
          ApiConfig.notifications, {'page': page.toString(), 'limit': '20'})),
      headers: _headers,
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to get notifications');
    }
  }

  // Get unread notification count
  static Future<Map<String, dynamic>> getUnreadNotificationCount() async {
    final response = await http.get(
      Uri.parse(ApiConfig.unreadNotificationCount),
      headers: _headers,
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to get unread count');
    }
  }

  // Mark notification as read
  static Future<Map<String, dynamic>> markNotificationAsRead(String id) async {
    final response = await http.put(
      Uri.parse(ApiConfig.markNotificationRead(id)),
      headers: _headers,
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to mark as read');
    }
  }

  // Mark all notifications as read
  static Future<Map<String, dynamic>> markAllNotificationsAsRead() async {
    final response = await http.put(
      Uri.parse(ApiConfig.markAllNotificationsRead),
      headers: _headers,
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to mark all as read');
    }
  }

  // Delete notification
  static Future<Map<String, dynamic>> deleteNotification(String id) async {
    final response = await http.delete(
      Uri.parse(ApiConfig.deleteNotification(id)),
      headers: _headers,
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to delete notification');
    }
  }

  // ==================== SETTINGS APIs ====================

  // Get app settings
  static Future<Map<String, dynamic>> getSettings() async {
    final response = await http.get(
      Uri.parse(ApiConfig.settings),
      headers: {'Content-Type': 'application/json'},
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to get settings');
    }
  }

  // Get social links
  static Future<Map<String, dynamic>> getSocialLinks() async {
    final response = await http.get(
      Uri.parse(ApiConfig.socialLinks),
      headers: {'Content-Type': 'application/json'},
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to get social links');
    }
  }

  // Check maintenance mode
  static Future<Map<String, dynamic>> checkMaintenance() async {
    final response = await http.get(
      Uri.parse(ApiConfig.maintenance),
      headers: {'Content-Type': 'application/json'},
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to check maintenance');
    }
  }

  // ==================== FEED APIs ====================

  // Get active feed posts for home screen
  static Future<Map<String, dynamic>> getFeeds(
      {int page = 1, int limit = 10}) async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.withParams(ApiConfig.activeFeeds,
            {'page': page.toString(), 'limit': limit.toString()})),
        headers: {'Content-Type': 'application/json'},
      );

      // Check if response is HTML (error page) instead of JSON
      if (response.body.trim().startsWith('<!DOCTYPE') ||
          response.body.trim().startsWith('<html')) {
        throw Exception(
            'Server returned HTML instead of JSON. Check server URL.');
      }

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Failed to get feeds');
      }
    } catch (e) {
      // Return empty feeds on error to prevent crash
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Connection refused')) {
        throw Exception(
            'Cannot connect to server. Check your internet connection.');
      }
      rethrow;
    }
  }

  // Get public feed
  static Future<Map<String, dynamic>> getPublicFeed({int page = 1}) async {
    final response = await http.get(
      Uri.parse(ApiConfig.withParams(
          ApiConfig.publicFeed, {'page': page.toString()})),
      headers: _headers,
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to get public feed');
    }
  }

  // Like a feed post
  static Future<Map<String, dynamic>> likeFeed(String feedId) async {
    final url = Uri.parse(ApiConfig.likeFeed(feedId));
    final headers = _headers;
    debugPrint('DEBUG: Like Feed URL: $url');
    debugPrint('DEBUG: Like Feed Headers: $headers');

    final response = await http.post(
      url,
      headers: headers,
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to like feed');
    }
  }

  // Get comments by fetching single public post
  static Future<Map<String, dynamic>> getComments(String feedId) async {
    final response = await http.get(
      Uri.parse(ApiConfig.getSinglePublicPost(feedId)),
      headers:
          _headers, // Use headers in case the endpoint needs auth or consistent formatting
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data['data'] ?? {};
    } else {
      throw Exception(data['message'] ?? 'Failed to get comments');
    }
  }

  // Post a comment on a feed
  static Future<Map<String, dynamic>> postComment(
      String feedId, String comment) async {
    final response = await http.post(
      Uri.parse(ApiConfig.commentFeed(feedId)),
      headers: _headers,
      body: jsonEncode({'text': comment}),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 ||
        response.statusCode == 201 && data['success'] == true) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to post comment');
    }
  }

  // Share a feed post
  static Future<Map<String, dynamic>> shareFeed(String feedId) async {
    final response = await http.post(
      Uri.parse(ApiConfig.shareFeed(feedId)),
      headers: _headers,
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to share feed');
    }
  }

  // ==================== BANNER APIs ====================

  // Get active banners for home screen
  static Future<Map<String, dynamic>> getBanners() async {
    final response = await http.get(
      Uri.parse(ApiConfig.activeBanners),
      headers: {'Content-Type': 'application/json'},
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to get banners');
    }
  }

  // Record banner view
  static Future<void> recordBannerView(String bannerId) async {
    await http.post(
      Uri.parse(ApiConfig.recordBannerView(bannerId)),
      headers: {'Content-Type': 'application/json'},
    );
  }

  // Record banner click
  static Future<void> recordBannerClick(String bannerId) async {
    await http.post(
      Uri.parse(ApiConfig.recordBannerClick(bannerId)),
      headers: {'Content-Type': 'application/json'},
    );
  }

  // ==================== KYC APIs ====================

  // Get KYC status
  static Future<Map<String, dynamic>> getKycStatus() async {
    final response = await http.get(
      Uri.parse(ApiConfig.kycStatus),
      headers: _headers,
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to get KYC status');
    }
  }

  // Submit KYC documents
  static Future<Map<String, dynamic>> submitKyc({
    required String fullName,
    required String dateOfBirth,
    required String address,
    required String city,
    required String country,
    String? postalCode,
    required String documentType,
    required String documentNumber,
    File? documentFront,
    File? documentBack,
    File? selfie,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiConfig.kycSubmit),
      );

      request.headers['Authorization'] = 'Bearer $_authToken';

      // Add text fields
      request.fields['fullName'] = fullName;
      request.fields['dateOfBirth'] = dateOfBirth;
      request.fields['address'] = address;
      request.fields['city'] = city;
      request.fields['country'] = country;
      if (postalCode != null) request.fields['postalCode'] = postalCode;
      request.fields['documentType'] = documentType;
      request.fields['documentNumber'] = documentNumber;

      // Add document files if provided
      if (documentFront != null) {
        final extension = documentFront.path.split('.').last.toLowerCase();
        final mimeType = extension == 'png' ? 'image/png' : 'image/jpeg';
        request.files.add(await http.MultipartFile.fromPath(
          'documentFront',
          documentFront.path,
          contentType: http_parser.MediaType.parse(mimeType),
        ));
      }

      if (documentBack != null) {
        final extension = documentBack.path.split('.').last.toLowerCase();
        final mimeType = extension == 'png' ? 'image/png' : 'image/jpeg';
        request.files.add(await http.MultipartFile.fromPath(
          'documentBack',
          documentBack.path,
          contentType: http_parser.MediaType.parse(mimeType),
        ));
      }

      if (selfie != null) {
        final extension = selfie.path.split('.').last.toLowerCase();
        final mimeType = extension == 'png' ? 'image/png' : 'image/jpeg';
        request.files.add(await http.MultipartFile.fromPath(
          'selfie',
          selfie.path,
          contentType: http_parser.MediaType.parse(mimeType),
        ));
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Failed to submit KYC');
      }
    } catch (e) {
      throw Exception('KYC submission failed: $e');
    }
  }

  // Get KYC details by ID
  static Future<Map<String, dynamic>> getKycDetails(String id) async {
    final response = await http.get(
      Uri.parse(ApiConfig.getKYCDetails(id)),
      headers: _headers,
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to get KYC details');
    }
  }

  // Resubmit KYC after rejection
  static Future<Map<String, dynamic>> resubmitKyc({
    required String fullName,
    required String dateOfBirth,
    required String address,
    required String city,
    required String country,
    String? postalCode,
    required String documentType,
    required String documentNumber,
    File? documentFront,
    File? documentBack,
    File? selfie,
  }) async {
    try {
      final request = http.MultipartRequest(
        'PUT',
        Uri.parse(ApiConfig.kycResubmit),
      );

      request.headers['Authorization'] = 'Bearer $_authToken';

      // Add text fields
      request.fields['fullName'] = fullName;
      request.fields['dateOfBirth'] = dateOfBirth;
      request.fields['address'] = address;
      request.fields['city'] = city;
      request.fields['country'] = country;
      if (postalCode != null) request.fields['postalCode'] = postalCode;
      request.fields['documentType'] = documentType;
      request.fields['documentNumber'] = documentNumber;

      // Add document files if provided
      if (documentFront != null) {
        final extension = documentFront.path.split('.').last.toLowerCase();
        final mimeType = extension == 'png' ? 'image/png' : 'image/jpeg';
        request.files.add(await http.MultipartFile.fromPath(
          'documentFront',
          documentFront.path,
          contentType: http_parser.MediaType.parse(mimeType),
        ));
      }

      if (documentBack != null) {
        final extension = documentBack.path.split('.').last.toLowerCase();
        final mimeType = extension == 'png' ? 'image/png' : 'image/jpeg';
        request.files.add(await http.MultipartFile.fromPath(
          'documentBack',
          documentBack.path,
          contentType: http_parser.MediaType.parse(mimeType),
        ));
      }

      if (selfie != null) {
        final extension = selfie.path.split('.').last.toLowerCase();
        final mimeType = extension == 'png' ? 'image/png' : 'image/jpeg';
        request.files.add(await http.MultipartFile.fromPath(
          'selfie',
          selfie.path,
          contentType: http_parser.MediaType.parse(mimeType),
        ));
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Failed to resubmit KYC');
      }
    } catch (e) {
      throw Exception('KYC resubmission failed: $e');
    }
  }

  // Get available crypto networks
  static Future<Map<String, dynamic>> getCryptoNetworks() async {
    final response = await http.get(
      Uri.parse(ApiConfig.cryptoNetworks),
      headers: _headers,
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to get crypto networks');
    }
  }

  // Submit crypto deposit
  static Future<Map<String, dynamic>> submitCryptoDeposit({
    required String networkId,
    required double amountUSD,
    required String txHash,
  }) async {
    final response = await http.post(
      Uri.parse(ApiConfig.cryptoDeposit),
      headers: _headers,
      body: jsonEncode({
        'networkId': networkId,
        'amountUSD': amountUSD,
        'txHash': txHash,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to submit crypto deposit');
    }
  }
}
