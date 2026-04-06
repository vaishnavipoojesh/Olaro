import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:shared_preferences/shared_preferences.dart';

class MiningData {
  final String status; // 'idle', 'mining', 'complete'
  final double coinsEarned;
  final int timeRemaining; // seconds
  final double progress;
  final Map<String, dynamic>? currentSession;

  MiningData({
    required this.status,
    required this.coinsEarned,
    required this.timeRemaining,
    required this.progress,
    this.currentSession,
  });

  factory MiningData.fromJson(Map<String, dynamic> json) {
    return MiningData(
      status: json['status'] ?? 'idle',
      coinsEarned: (json['coinsEarned'] ?? 0).toDouble(),
      timeRemaining: json['timeRemaining'] ?? 0,
      progress: (json['progress'] ?? 0).toDouble(),
      currentSession: json['currentSession'],
    );
  }

  factory MiningData.idle() {
    return MiningData(
      status: 'idle',
      coinsEarned: 0,
      timeRemaining: 0,
      progress: 0,
    );
  }

  factory MiningData.fromApi(Map<String, dynamic> apiResponse) {
    final status = apiResponse['status'] ?? 'idle';
    final currentSession = apiResponse['currentSession'];

    // Default values
    double coinsEarned = 0;
    int timeRemaining = 0;
    double progress = 0;
    Map<String, dynamic>? sessionData;

    try {
      if (currentSession != null && currentSession is Map) {
        sessionData = Map<String, dynamic>.from(currentSession);

        if (status == 'mining') {
          final startTime =
              DateTime.tryParse(sessionData['startTime']?.toString() ?? '');
          final endTime =
              DateTime.tryParse(sessionData['endTime']?.toString() ?? '');
          final expectedCoins = (sessionData['expectedCoins'] is num)
              ? (sessionData['expectedCoins'] as num).toDouble()
              : double.tryParse(
                      sessionData['expectedCoins']?.toString() ?? '0') ??
                  0.0;

          if (startTime != null && endTime != null) {
            final totalDuration = endTime.difference(startTime).inSeconds;
            // Use local time for calculation as API doesn't return server time
            final now = DateTime.now();
            final elapsed = now.difference(startTime).inSeconds;

            if (totalDuration > 0) {
              progress = (elapsed / totalDuration * 100).clamp(0.0, 100.0);
              coinsEarned = (progress / 100) * expectedCoins;
              timeRemaining =
                  (endTime.difference(now).inSeconds).clamp(0, totalDuration);
            }
          }
        } else if (status == 'complete') {
          coinsEarned = (sessionData['expectedCoins'] is num)
              ? (sessionData['expectedCoins'] as num).toDouble()
              : double.tryParse(
                      sessionData['expectedCoins']?.toString() ?? '0') ??
                  0.0;
          progress = 100.0;
          timeRemaining = 0;
        }
      }
    } catch (e) {
      debugPrint('Error parsing mining API data: $e');
    }

    return MiningData(
      status: status,
      coinsEarned: coinsEarned,
      timeRemaining: timeRemaining,
      progress: progress,
      currentSession: sessionData,
    );
  }
}

class SocketService {
  static SocketService? _instance;
  static SocketService get instance => _instance ??= SocketService._();

  io.Socket? _socket;
  bool _isConnected = false;
  bool _isAuthenticated = false;

  // Stream controllers for broadcasting updates
  StreamController<MiningData> _miningUpdateController =
      StreamController<MiningData>.broadcast();
  StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();
  StreamController<Map<String, dynamic>> _walletUpdateController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<MiningData> get miningUpdates => _miningUpdateController.stream;
  Stream<bool> get connectionStatus => _connectionController.stream;
  Stream<Map<String, dynamic>> get walletUpdates =>
      _walletUpdateController.stream;

  bool get isConnected => _isConnected;
  bool get isAuthenticated => _isAuthenticated;

  SocketService._();

  /// Initialize and connect to socket server
  Future<void> connect() async {
    if (_socket != null && _isConnected) {
      debugPrint('Socket already connected');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null) {
      debugPrint('No auth token, cannot connect socket');
      return;
    }

    // Server URL - same as API but without /api
    const serverUrl = 'http://72.62.167.180:5002';

    _socket = io.io(
      serverUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(10)
          .setReconnectionDelay(1000)
          .build(),
    );

    _setupEventListeners(token);
    _socket!.connect();
  }

  void _setupEventListeners(String token) {
    _socket!.onConnect((_) {
      debugPrint('Socket connected');
      _isConnected = true;
      _connectionController.add(true);

      // Authenticate with token
      _socket!.emit('authenticate', token);
    });

    _socket!.onDisconnect((_) {
      debugPrint('Socket disconnected');
      _isConnected = false;
      _isAuthenticated = false;
      _connectionController.add(false);
    });

    _socket!.onConnectError((error) {
      debugPrint('Socket connection error: $error');
      _isConnected = false;
      _connectionController.add(false);
    });

    _socket!.onError((error) {
      debugPrint('Socket error: $error');
    });

    // Authentication response
    _socket!.on('auth-error', (data) {
      debugPrint('Socket auth error: $data');
      _isAuthenticated = false;
    });

    // Initial mining status after auth
    _socket!.on('mining-status', (data) {
      debugPrint('Received mining status: $data');
      _isAuthenticated = true;
      if (data != null) {
        final miningData = MiningData.fromJson(Map<String, dynamic>.from(data));
        _miningUpdateController.add(miningData);
      }
    });

    // Real-time mining updates (every second)
    _socket!.on('mining-update', (data) {
      if (data != null) {
        final miningData = MiningData.fromJson(Map<String, dynamic>.from(data));
        _miningUpdateController.add(miningData);
      }
    });

    // Mining complete event
    _socket!.on('mining-complete', (data) {
      debugPrint('Mining complete!');
      if (data != null) {
        final miningData = MiningData.fromJson(Map<String, dynamic>.from(data));
        _miningUpdateController.add(miningData);
      }
    });

    // Wallet update event (for when coins are claimed or spent)
    _socket!.on('wallet-update', (data) {
      debugPrint('Wallet updated: $data');
      if (data != null) {
        _walletUpdateController.add(Map<String, dynamic>.from(data));
      }
    });
  }

  /// Request current mining status
  void requestMiningStatus() {
    if (_isConnected && _isAuthenticated) {
      _socket!.emit('get-mining-status');
    }
  }

  /// Disconnect from socket server and clear all cached data
  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
    _isAuthenticated = false;
    _connectionController.add(false);

    // Send idle status to clear any cached mining data in listeners
    _miningUpdateController.add(MiningData.idle());
  }

  /// Full reset - call this on logout to clear everything
  void reset() {
    debugPrint('SocketService: Full reset for logout');
    disconnect();

    // Close old controllers and create new ones to clear all listeners' cached data
    _miningUpdateController.close();
    _connectionController.close();
    _walletUpdateController.close();

    // Create fresh controllers
    _miningUpdateController = StreamController<MiningData>.broadcast();
    _connectionController = StreamController<bool>.broadcast();
    _walletUpdateController =
        StreamController<Map<String, dynamic>>.broadcast();
  }

  /// Reconnect with new token (after login)
  Future<void> reconnect() async {
    debugPrint('SocketService: Reconnecting with new token');
    disconnect();
    await Future.delayed(const Duration(milliseconds: 500));
    await connect();
  }

  /// Dispose resources
  void dispose() {
    disconnect();
    _miningUpdateController.close();
    _connectionController.close();
    _walletUpdateController.close();
    _instance = null;
  }
}
