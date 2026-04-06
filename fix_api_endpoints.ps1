# PowerShell script to replace all baseUrl references with ApiConfig
$filePath = "f:\coin_mining_project\coin_mining_project\lib\services\api_service.dart"
$content = Get-Content $filePath -Raw

# Mining endpoints
$content = $content -replace "'\`$baseUrl/mining/status'", 'ApiConfig.miningStatus'
$content = $content -replace "'\`$baseUrl/mining/start'", 'ApiConfig.startMining'
$content = $content -replace "'\`$baseUrl/mining/claim'", 'ApiConfig.claimMining'
$content = $content -replace "'\`$baseUrl/mining/cancel'", 'ApiConfig.cancelMining'
$content = $content -replace "'\`$baseUrl/mining/history", 'ApiConfig.miningHistory'
$content = $content -replace "'\`$baseUrl/mining/leaderboard'", 'ApiConfig.miningLeaderboard'
$content = $content -replace "'\`$baseUrl/mining/boost'", 'ApiConfig.boostMining'
$content = $content -replace "'\`$baseUrl/mining/rewards'", 'ApiConfig.rewardsBreakdown'

# Wallet endpoints
$content = $content -replace "'\`$baseUrl/wallet'", 'ApiConfig.wallet'
$content = $content -replace "'\`$baseUrl/wallet/mining'", 'ApiConfig.miningWallet'
$content = $content -replace "'\`$baseUrl/wallet/purchase'", 'ApiConfig.purchaseWallet'
$content = $content -replace "'\`$baseUrl/wallet/summary'", 'ApiConfig.walletSummary'
$content = $content -replace "'\`$baseUrl/wallet/internal-transfer'", 'ApiConfig.internalTransfer'
$content = $content -replace "'\`$baseUrl/wallet/withdrawal-address'", 'ApiConfig.withdrawalAddress'
$content = $content -replace "'\`$baseUrl/wallet/withdraw'", 'ApiConfig.withdraw'
$content = $content -replace "'\`$baseUrl/wallet/transactions", 'ApiConfig.transactions'
$content = $content -replace "'\`$baseUrl/wallet/transactions/\`$id'", 'ApiConfig.getTransaction(id)'

# Coin endpoints
$content = $content -replace "'\`$baseUrl/coins/packages'", 'ApiConfig.coinPackages'
$content = $content -replace "'\`$baseUrl/coins/rate'", 'ApiConfig.coinRate'
$content = $content -replace "'\`$baseUrl/coins/balance'", 'ApiConfig.coinBalance'
$content = $content -replace "'\`$baseUrl/coins/purchase'", 'ApiConfig.purchaseCoins'
$content = $content -replace "'\`$baseUrl/coins/purchase/\`$transactionId/proof'", 'ApiConfig.submitPaymentProof(transactionId)'
$content = $content -replace "'\`$baseUrl/coins/purchase/\`$transactionId/cancel'", 'ApiConfig.cancelPurchase(transactionId)'
$content = $content -replace "'\`$baseUrl/coins/purchases", 'ApiConfig.coinPurchases'
$content = $content -replace "'\`$baseUrl/coins/transfer'", 'ApiConfig.transferCoins'
$content = $content -replace "'\`$baseUrl/coins/payment-info'", 'ApiConfig.paymentInfo'
$content = $content -replace "'\`$baseUrl/coins/submit-transaction'", 'ApiConfig.submitTransaction'

# Referral endpoints
$content = $content -replace "'\`$baseUrl/referrals'", 'ApiConfig.referrals'
$content = $content -replace "'\`$baseUrl/referrals/share'", 'ApiConfig.referralShare'
$content = $content -replace "'\`$baseUrl/referrals/earnings'", 'ApiConfig.referralEarnings'
$content = $content -replace "'\`$baseUrl/referrals/ping'", 'ApiConfig.pingReferrals'
$content = $content -replace "'\`$baseUrl/referrals/validate/\`$code'", 'ApiConfig.validateReferralCode(code)'

# Notification endpoints
$content = $content -replace "'\`$baseUrl/notifications", 'ApiConfig.notifications'
$content = $content -replace "'\`$baseUrl/notifications/unread-count'", 'ApiConfig.unreadNotificationCount'
$content = $content -replace "'\`$baseUrl/notifications/\`$id/read'", 'ApiConfig.markNotificationRead(id)'
$content = $content -replace "'\`$baseUrl/notifications/read-all'", 'ApiConfig.markAllNotificationsRead'
$content = $content -replace "'\`$baseUrl/notifications/\`$id'", 'ApiConfig.deleteNotification(id)'

# Settings endpoints
$content = $content -replace "'\`$baseUrl/settings'", 'ApiConfig.settings'
$content = $content -replace "'\`$baseUrl/settings/social'", 'ApiConfig.socialLinks'
$content = $content -replace "'\`$baseUrl/settings/maintenance'", 'ApiConfig.maintenance'

# Feed endpoints
$content = $content -replace "'\`$baseUrl/admin/feed/active", 'ApiConfig.activeFeeds'
$content = $content -replace "'\`$baseUrl/admin/feed/\`$feedId/engage'", 'ApiConfig.engageFeed(feedId)'
$content = $content -replace "'\`$baseUrl/admin/feed/\`$feedId/comments'", 'ApiConfig.getFeedComments(feedId)'

# Banner endpoints
$content = $content -replace "'\`$baseUrl/admin/banners/active'", 'ApiConfig.activeBanners'
$content = $content -replace "'\`$baseUrl/admin/banners/\`$bannerId/view'", 'ApiConfig.recordBannerView(bannerId)'
$content = $content -replace "'\`$baseUrl/admin/banners/\`$bannerId/click'", 'ApiConfig.recordBannerClick(bannerId)'

$content | Set-Content $filePath -NoNewline
Write-Host "API endpoints updated successfully!"
