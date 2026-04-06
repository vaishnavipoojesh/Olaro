import re

# Read the file
with open(r'f:\coin_mining_project\coin_mining_project\lib\services\api_service.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Define all replacements
replacements = [
    # Mining
    (r"'\$baseUrl/mining/status'", "ApiConfig.miningStatus"),
    (r"'\$baseUrl/mining/start'", "ApiConfig.startMining"),
    (r"'\$baseUrl/mining/claim'", "ApiConfig.claimMining"),
    (r"'\$baseUrl/mining/cancel'", "ApiConfig.cancelMining"),
    (r"'\$baseUrl/mining/history\?page=\$page'", "ApiConfig.withParams(ApiConfig.miningHistory, {'page': page.toString()})"),
    (r"'\$baseUrl/mining/leaderboard'", "ApiConfig.miningLeaderboard"),
    (r"'\$baseUrl/mining/boost'", "ApiConfig.boostMining"),
    (r"'\$baseUrl/mining/rewards'", "ApiConfig.rewardsBreakdown"),
    
    # Wallet
    (r"'\$baseUrl/wallet'", "ApiConfig.wallet"),
    (r"'\$baseUrl/wallet/mining'", "ApiConfig.miningWallet"),
    (r"'\$baseUrl/wallet/purchase'", "ApiConfig.purchaseWallet"),
    (r"'\$baseUrl/wallet/summary'", "ApiConfig.walletSummary"),
    (r"'\$baseUrl/wallet/internal-transfer'", "ApiConfig.internalTransfer"),
    (r"'\$baseUrl/wallet/withdrawal-address'", "ApiConfig.withdrawalAddress"),
    (r"'\$baseUrl/wallet/withdraw'", "ApiConfig.withdraw"),
    (r"'\$baseUrl/wallet/transactions\?page=\$page", "ApiConfig.withParams(ApiConfig.transactions, {'page': page.toString()}"),
    (r"'\$baseUrl/wallet/transactions/\$id'", "ApiConfig.getTransaction(id)"),
    
    # Coins
    (r"'\$baseUrl/coins/packages'", "ApiConfig.coinPackages"),
    (r"'\$baseUrl/coins/rate'", "ApiConfig.coinRate"),
    (r"'\$baseUrl/coins/balance'", "ApiConfig.coinBalance"),
    (r"'\$baseUrl/coins/purchase'", "ApiConfig.purchaseCoins"),
    (r"'\$baseUrl/coins/purchase/\$transactionId/proof'", "ApiConfig.submitPaymentProof(transactionId)"),
    (r"'\$baseUrl/coins/purchase/\$transactionId/cancel'", "ApiConfig.cancelPurchase(transactionId)"),
    (r"'\$baseUrl/coins/purchases\?page=\$page'", "ApiConfig.withParams(ApiConfig.coinPurchases, {'page': page.toString()})"),
    (r"'\$baseUrl/coins/transfer'", "ApiConfig.transferCoins"),
    (r"'\$baseUrl/coins/payment-info'", "ApiConfig.paymentInfo"),
    (r"'\$baseUrl/coins/submit-transaction'", "ApiConfig.submitTransaction"),
    
    # Referrals
    (r"'\$baseUrl/referrals'", "ApiConfig.referrals"),
    (r"'\$baseUrl/referrals/share'", "ApiConfig.referralShare"),
    (r"'\$baseUrl/referrals/earnings'", "ApiConfig.referralEarnings"),
    (r"'\$baseUrl/referrals/ping'", "ApiConfig.pingReferrals"),
    (r"'\$baseUrl/referrals/validate/\$code'", "ApiConfig.validateReferralCode(code)"),
    
    # Notifications
    (r"'\$baseUrl/notifications\?page=\$page&limit=20'", "ApiConfig.withParams(ApiConfig.notifications, {'page': page.toString(), 'limit': '20'})"),
    (r"'\$baseUrl/notifications/unread-count'", "ApiConfig.unreadNotificationCount"),
    (r"'\$baseUrl/notifications/\$id/read'", "ApiConfig.markNotificationRead(id)"),
    (r"'\$baseUrl/notifications/read-all'", "ApiConfig.markAllNotificationsRead"),
    (r"'\$baseUrl/notifications/\$id'", "ApiConfig.deleteNotification(id)"),
    
    # Settings
    (r"'\$baseUrl/settings'", "ApiConfig.settings"),
    (r"'\$baseUrl/settings/social'", "ApiConfig.socialLinks"),
    (r"'\$baseUrl/settings/maintenance'", "ApiConfig.maintenance"),
    
    # Feed
    (r"'\$baseUrl/admin/feed/active\?page=\$page&limit=\$limit'", "ApiConfig.withParams(ApiConfig.activeFeeds, {'page': page.toString(), 'limit': limit.toString()})"),
    (r"'\$baseUrl/admin/feed/\$feedId/engage'", "ApiConfig.engageFeed(feedId)"),
    (r"'\$baseUrl/admin/feed/\$feedId/comments'", "ApiConfig.getFeedComments(feedId)"),
    
    # Banners
    (r"'\$baseUrl/admin/banners/active'", "ApiConfig.activeBanners"),
    (r"'\$baseUrl/admin/banners/\$bannerId/view'", "ApiConfig.recordBannerView(bannerId)"),
    (r"'\$baseUrl/admin/banners/\$bannerId/click'", "ApiConfig.recordBannerClick(bannerId)"),
]

# Apply all replacements
for pattern, replacement in replacements:
    content = re.sub(pattern, replacement, content)

# Fix any remaining malformed strings
content = re.sub(r"'\$baseUrlApiConfig\.", "ApiConfig.", content)

# Write back
with open(r'f:\coin_mining_project\coin_mining_project\lib\services\api_service.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("File updated successfully!")
