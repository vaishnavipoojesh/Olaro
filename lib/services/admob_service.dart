import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdMobService {
  static final AdMobService _instance = AdMobService._internal();
  factory AdMobService() => _instance;
  AdMobService._internal();

  // Production & Test Ad Unit IDs
  static String get bannerAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-8112751915705580/2550777728'; // Production Banner Ad Unit ID
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/2934735716'; // iOS Test Banner
    }
    return '';
  }

  static String get interstitialAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-8112751915705580/9035854084'; // Android Interstitial / Rewarded Ad
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/4411468910'; // iOS Test Interstitial
    }
    return '';
  }

  static String get rewardedAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-8112751915705580/627633458'; // Production Android Rewarded Ad Unit ID
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/1712485313'; // iOS Test Rewarded
    }
    return '';
  }

  /// Helper to create and load a Banner Ad Widget
  static BannerAd createBannerAd({
    required Function() onAdLoaded,
    required Function(LoadAdError) onAdFailedToLoad,
    String? customAdUnitId,
  }) {
    return BannerAd(
      adUnitId: customAdUnitId ?? bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('AdMob Banner Ad Loaded');
          onAdLoaded();
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('AdMob Banner Ad Failed: $error');
          ad.dispose();
          onAdFailedToLoad(error);
        },
      ),
    )..load();
  }

  /// Helper to load an Interstitial Ad
  static void loadInterstitialAd({
    required Function(InterstitialAd) onAdLoaded,
    Function()? onAdFailed,
  }) {
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('AdMob Interstitial Loaded');
          onAdLoaded(ad);
        },
        onAdFailedToLoad: (error) {
          debugPrint('AdMob Interstitial Failed: $error');
          if (onAdFailed != null) onAdFailed();
        },
      ),
    );
  }

  /// Helper to load and show a Rewarded Video Ad
  static void showRewardedAd({
    required Function(RewardItem reward) onUserEarnedReward,
    Function()? onAdDismissedOrFailed,
  }) {
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              if (onAdDismissedOrFailed != null) onAdDismissedOrFailed();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              if (onAdDismissedOrFailed != null) onAdDismissedOrFailed();
            },
          );
          ad.show(
            onUserEarnedReward: (adWithoutView, reward) {
              onUserEarnedReward(reward);
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('AdMob Rewarded Ad Failed: $error');
          if (onAdDismissedOrFailed != null) onAdDismissedOrFailed();
        },
      ),
    );
  }
}
