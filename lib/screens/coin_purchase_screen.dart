import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';
import '../utils/constants.dart';

class CoinPurchaseScreen extends StatefulWidget {
  const CoinPurchaseScreen({super.key});

  @override
  State<CoinPurchaseScreen> createState() => _CoinPurchaseScreenState();
}

class _CoinPurchaseScreenState extends State<CoinPurchaseScreen> {
  Map<String, dynamic>? _paymentInfo;
  List<dynamic> _cryptoNetworks = [];
  bool _isLoading = true;

  // Payment Method Selection
  String _selectedPaymentMethod = 'UPI'; // 'UPI' or 'Crypto'

  // UPI Payment State
  final TextEditingController _upiAmountController = TextEditingController();
  final TextEditingController _upiTransactionIdController =
      TextEditingController();
  String? _paymentLink;
  double? _amountINR;
  bool _isGeneratingLink = false;
  bool _isSubmittingUpi = false;

  // Crypto Payment State
  final TextEditingController _cryptoAmountController = TextEditingController();
  final TextEditingController _cryptoTxHashController = TextEditingController();
  String? _selectedNetworkId;
  File? _screenshot;
  bool _isSubmittingCrypto = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _upiAmountController.dispose();
    _upiTransactionIdController.dispose();
    _cryptoAmountController.dispose();
    _cryptoTxHashController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    // 1. Get Payment Info (Coin Rate)
    try {
      final paymentInfo = await ApiService.getPaymentInfo();
      setState(() {
        _paymentInfo = paymentInfo['paymentInfo'];
      });
    } catch (e) {
      debugPrint('Error loading payment info: $e');
    }

    // 2. Get Crypto Networks
    try {
      final cryptoNetworks = await ApiService.getCryptoNetworks();
      debugPrint('Crypto networks response: $cryptoNetworks');

      if (mounted) {
        setState(() {
          _cryptoNetworks = cryptoNetworks['networks'] ?? [];
          if (_cryptoNetworks.isNotEmpty) {
            _selectedNetworkId = _cryptoNetworks[0]['_id'];
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading crypto networks: $e');
      if (mounted) {
        _showSnackBar('Error loading crypto networks: $e', isError: true);
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickScreenshot() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() => _screenshot = File(image.path));
        _showSnackBar('Screenshot selected', isSuccess: true);
      }
    } catch (e) {
      _showSnackBar('Error picking image: $e', isError: true);
    }
  }

  Future<void> _generateUpiLink() async {
    final amountText = _upiAmountController.text.trim();
    if (amountText.isEmpty) {
      _showSnackBar('Please enter amount to generate link', isError: true);
      return;
    }

    final amountInr = double.tryParse(amountText);
    if (amountInr == null || amountInr <= 0) {
      _showSnackBar('Please enter valid amount', isError: true);
      return;
    }

    final usdToInrRate = (_paymentInfo?['usdToInrRate'] ?? 83).toDouble();
    final amountUsd = amountInr / usdToInrRate;

    setState(() => _isGeneratingLink = true);

    try {
      final result = await ApiService.createPaymentLink(amount: amountUsd);
      setState(() {
        _paymentLink = result['paymentLink'];
        _amountINR = (result['amountINR'] as num).toDouble();
      });
      _showSnackBar('Payment link generated!', isSuccess: true);
    } catch (e) {
      _showSnackBar('Error generating link: $e', isError: true);
    } finally {
      setState(() => _isGeneratingLink = false);
    }
  }

  Future<void> _submitUpiTransaction() async {
    final amountText = _upiAmountController.text.trim();
    final transactionId = _upiTransactionIdController.text.trim();

    if (amountText.isEmpty) {
      _showSnackBar('Please enter amount', isError: true);
      return;
    }

    final amountInr = double.tryParse(amountText);
    if (amountInr == null || amountInr <= 0) {
      _showSnackBar('Please enter valid amount', isError: true);
      return;
    }

    if (transactionId.isEmpty) {
      _showSnackBar('Please enter Transaction ID', isError: true);
      return;
    }

    if (transactionId.length < 6) {
      _showSnackBar('Invalid Transaction ID', isError: true);
      return;
    }

    final usdToInrRate = (_paymentInfo?['usdToInrRate'] ?? 83).toDouble();
    final amountUsd = amountInr / usdToInrRate;

    setState(() => _isSubmittingUpi = true);

    try {
      final result = await ApiService.submitTransaction(
        transactionId: transactionId,
        amount: amountUsd,
      );

      _showSnackBar(result['message'] ?? 'Transaction submitted!',
          isSuccess: true);
      _upiAmountController.clear();
      _upiTransactionIdController.clear();
      setState(() => _paymentLink = null);
      _showSuccessDialog(result);
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    } finally {
      setState(() => _isSubmittingUpi = false);
    }
  }

  Future<void> _submitCryptoDeposit() async {
    final amountText = _cryptoAmountController.text.trim();
    final txHash = _cryptoTxHashController.text.trim();

    if (amountText.isEmpty) {
      _showSnackBar('Please enter amount', isError: true);
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      _showSnackBar('Please enter valid amount', isError: true);
      return;
    }

    if (_selectedNetworkId == null) {
      _showSnackBar('Please select a network', isError: true);
      return;
    }

    if (txHash.isEmpty) {
      _showSnackBar('Please enter transaction hash', isError: true);
      return;
    }

    if (txHash.length < 10) {
      _showSnackBar('Invalid transaction hash', isError: true);
      return;
    }

    setState(() => _isSubmittingCrypto = true);

    try {
      final result = await ApiService.submitCryptoDeposit(
        networkId: _selectedNetworkId!,
        amountUSD: amount,
        txHash: txHash,
      );

      _showSnackBar(result['message'] ?? 'Crypto deposit submitted!',
          isSuccess: true);
      _cryptoAmountController.clear();
      _cryptoTxHashController.clear();
      setState(() => _screenshot = null);
      _showSuccessDialog(result);
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    } finally {
      setState(() => _isSubmittingCrypto = false);
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

  void _showSuccessDialog(Map<String, dynamic> result) {
    final transaction = result['transaction'];
    final coins = transaction?['coins'] ?? 0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle,
                  color: AppColors.success, size: 48),
            ),
            const SizedBox(height: 20),
            const Text('Transaction Submitted!',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text('You will receive $coins coins after admin verification.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            const Text('Usually verified within 24 hours',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('OK',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final coinPricePerDollar =
        (_paymentInfo?['coinPricePerDollar'] ?? 10).toInt();
    final coinsPerINR = (_paymentInfo?['coinsPerINR'] ?? 1).toDouble();
    final usdToInrRate = (_paymentInfo?['usdToInrRate'] ?? 83).toDouble();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.cardDark,
        title: const Text('Buy Coins', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Purchase History',
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const PurchaseHistoryScreen())),
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
                    _buildCoinRateCard(coinPricePerDollar, coinsPerINR),
                    const SizedBox(height: 24),
                    _buildPaymentMethodSelector(),
                    const SizedBox(height: 24),
                    if (_selectedPaymentMethod == 'UPI')
                      ..._buildUpiSection(coinsPerINR, usdToInrRate)
                    else
                      ..._buildCryptoSection(coinPricePerDollar),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildCoinRateCard(num coinPricePerDollar, double coinsPerINR) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10))
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.currency_exchange,
                color: Colors.white, size: 40),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Exchange Rate',
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 4),
                Text('\$1 = $coinPricePerDollar OLR',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text('₹1 = ${coinsPerINR.toStringAsFixed(1)} OLR',
                    style: const TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildMethodOption('UPI', Icons.payment),
          ),
          Expanded(
            child: _buildMethodOption(
                'Crypto', Icons.account_balance_wallet_outlined),
          ),
        ],
      ),
    );
  }

  Widget _buildMethodOption(String method, IconData icon) {
    final isSelected = _selectedPaymentMethod == method;
    return GestureDetector(
      onTap: () => setState(() => _selectedPaymentMethod = method),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                color: isSelected ? Colors.white : Colors.grey, size: 20),
            const SizedBox(width: 8),
            Text(
              method == 'Crypto' ? 'Crypto (USDT)' : method,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildUpiSection(double coinsPerINR, double usdToInrRate) {
    return [
      _buildUpiAmountSection(coinsPerINR, usdToInrRate),
      if (_paymentLink != null) ...[
        const SizedBox(height: 24),
        _buildDynamicQrSection(),
        const SizedBox(height: 24),
        _buildUpiSubmissionSection(),
      ],
      const SizedBox(height: 24),
      _buildUpiInstructions(),
    ];
  }

  List<Widget> _buildCryptoSection(num coinPricePerDollar) {
    return [
      _buildCryptoNetworkSelector(),
      const SizedBox(height: 24),
      _buildCryptoAmountSection(coinPricePerDollar),
      const SizedBox(height: 24),
      _buildCryptoSubmissionSection(),
      const SizedBox(height: 24),
      _buildCryptoInstructions(),
    ];
  }

  Widget _buildUpiAmountSection(double coinsPerINR, double usdToInrRate) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: AppColors.cardDark, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('1. Enter Amount',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          const Text('Amount (INR)',
              style: TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 8),
          TextField(
            controller: _upiAmountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.white, fontSize: 18),
            decoration: InputDecoration(
              hintText: 'Enter amount (e.g., 100)',
              hintStyle: const TextStyle(color: Colors.grey),
              prefixIcon:
                  const Icon(Icons.currency_rupee, color: AppColors.primary),
              filled: true,
              fillColor: AppColors.cardLight,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              suffixText: 'INR',
              suffixStyle: const TextStyle(color: AppColors.primary),
            ),
            onChanged: (value) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Builder(builder: (context) {
            final amountInr = double.tryParse(_upiAmountController.text) ?? 0;
            final coins = (amountInr * coinsPerINR).toInt();
            final amountUsd = amountInr / usdToInrRate;
            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10)),
                  child:
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.token, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Text('You will receive: $coins OLR',
                        style: const TextStyle(
                            color: AppColors.primary, fontWeight: FontWeight.bold)),
                  ]),
                ),
                if (amountInr > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('Equivalent USD: \$${amountUsd.toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ),
              ],
            );
          }),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isGeneratingLink ? null : _generateUpiLink,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _isGeneratingLink
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Generate Payment Link',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCryptoNetworkSelector() {
    if (_cryptoNetworks.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.grey),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'No crypto networks available',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      );
    }

    final selectedNetwork = _cryptoNetworks.firstWhere(
      (n) => n['_id'] == _selectedNetworkId,
      orElse: () => _cryptoNetworks[0],
    );

    final walletAddress = selectedNetwork['walletAddress'] ?? 'N/A';
    final qrCodeUrl = selectedNetwork['qrCode'] ?? selectedNetwork['qrCodeUrl'] ?? '';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Network Selection',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _selectedNetworkId,
            dropdownColor: AppColors.cardDark,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.cardLight,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              prefixIcon:
                  const Icon(Icons.account_balance, color: AppColors.primary),
            ),
            items: _cryptoNetworks.map((network) {
              return DropdownMenuItem<String>(
                value: network['_id'],
                child: Text(network['name'] ?? 'Unknown Network'),
              );
            }).toList(),
            onChanged: (value) {
              setState(() => _selectedNetworkId = value);
            },
          ),
          const SizedBox(height: 24),
          const Text('Wallet Address',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    walletAddress,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy,
                      color: AppColors.primary, size: 20),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: walletAddress));
                    _showSnackBar('Address copied!', isSuccess: true);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Center(
            child: Text('QR Code',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 12),
          Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Image.network(
                qrCodeUrl,
                width: 180,
                height: 180,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const SizedBox(
                    width: 180,
                    height: 180,
                    child: Center(
                      child:
                          CircularProgressIndicator(color: AppColors.primary),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return const SizedBox(
                    width: 180,
                    height: 180,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline,
                              color: Colors.grey, size: 48),
                          SizedBox(height: 8),
                          Text('QR Code not available',
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCryptoAmountSection(num coinPricePerDollar) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: AppColors.cardDark, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Enter Amount',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          const Text('Amount (USDT)',
              style: TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 8),
          TextField(
            controller: _cryptoAmountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.white, fontSize: 18),
            decoration: InputDecoration(
              hintText: 'Enter amount (e.g., 10)',
              hintStyle: const TextStyle(color: Colors.grey),
              prefixIcon:
                  const Icon(Icons.attach_money, color: AppColors.primary),
              filled: true,
              fillColor: AppColors.cardLight,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              suffixText: 'USDT',
              suffixStyle: const TextStyle(color: AppColors.primary),
            ),
            onChanged: (value) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Builder(builder: (context) {
            final amount = double.tryParse(_cryptoAmountController.text) ?? 0;
            final coins = (amount * coinPricePerDollar).toInt();
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10)),
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.token, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text('You will receive: $coins OLR',
                    style: const TextStyle(
                        color: AppColors.primary, fontWeight: FontWeight.bold)),
              ]),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCryptoSubmissionSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: AppColors.cardDark, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Submit Transaction',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          const Text('Transaction Hash (TxID)',
              style: TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 8),
          TextField(
            controller: _cryptoTxHashController,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              hintText: 'Enter TX hash after payment',
              hintStyle: const TextStyle(color: Colors.grey),
              prefixIcon: const Icon(Icons.tag, color: AppColors.success),
              filled: true,
              fillColor: AppColors.cardLight,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Upload Screenshot (Optional but recommended)',
              style: TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 8),
          InkWell(
            onTap: _pickScreenshot,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: _screenshot != null
                        ? AppColors.success
                        : Colors.grey.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                      _screenshot != null
                          ? Icons.check_circle
                          : Icons.upload_file,
                      color: _screenshot != null
                          ? AppColors.success
                          : Colors.grey),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _screenshot != null
                          ? 'Screenshot selected'
                          : 'Tap to upload screenshot',
                      style: TextStyle(
                          color: _screenshot != null
                              ? AppColors.success
                              : Colors.grey),
                    ),
                  ),
                  if (_screenshot != null)
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => setState(() => _screenshot = null),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmittingCrypto ? null : _submitCryptoDeposit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSubmittingCrypto
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Submit Deposit',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicQrSection() {
    final adminQrUrl = _getAdminQrUrl(_paymentInfo?['qrCodeUrl']?.toString() ?? '');
    final fallbackDynamicQrUrl =
        'https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=${Uri.encodeComponent(_paymentLink!)}';
    
    // Prefer Admin QR image set in Admin Settings, fallback to dynamic QR code
    final qrUrl = adminQrUrl.isNotEmpty ? adminQrUrl : fallbackDynamicQrUrl;
    final upiId = _paymentInfo?['upiId']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Text('2. Scan QR to Pay',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (_amountINR != null)
            Text('Paying ₹${_amountINR!.toStringAsFixed(2)}',
                style: const TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Image.network(
              qrUrl,
              width: 200,
              height: 200,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const SizedBox(
                  width: 200,
                  height: 200,
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 200,
                  height: 200,
                  color: Colors.grey[200],
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.qr_code_2, size: 60, color: Colors.grey),
                      SizedBox(height: 8),
                      Text('QR Image Error', style: TextStyle(color: Colors.black54, fontSize: 12)),
                    ],
                  ),
                );
              },
            ),
          ),
          if (upiId.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.cardLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet, color: AppColors.primary, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('UPI ID', style: TextStyle(color: Colors.grey, fontSize: 11)),
                        Text(upiId, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, color: AppColors.primary, size: 18),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: upiId));
                      _showSnackBar('UPI ID copied to clipboard!', isSuccess: true);
                    },
                    tooltip: 'Copy UPI ID',
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _paymentLink!));
                    _showSnackBar('Payment link copied!', isSuccess: true);
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copy Link'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    if (_paymentLink != null) {
                      final uri = Uri.parse(_paymentLink!);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri);
                      } else {
                        Clipboard.setData(ClipboardData(text: _paymentLink!));
                        _showSnackBar('Could not launch app. Link copied.',
                            isError: true);
                      }
                    }
                  },
                  icon: const Icon(Icons.payment, size: 18),
                  label: const Text('Pay Now'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUpiSubmissionSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: AppColors.cardDark, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('3. Confirm Transaction',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          const Text('Transaction ID',
              style: TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 8),
          TextField(
            controller: _upiTransactionIdController,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              hintText: 'Enter UTR / Reference No.',
              hintStyle: const TextStyle(color: Colors.grey),
              prefixIcon:
                  const Icon(Icons.receipt_long, color: AppColors.success),
              filled: true,
              fillColor: AppColors.cardLight,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmittingUpi ? null : _submitUpiTransaction,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSubmittingUpi
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Submit Transaction ID',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
            ),
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              'Your transaction is created and pending payment.\nOnce paid, enter the UTR to confirm.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpiInstructions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppColors.cardDark, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.info_outline, color: Colors.grey, size: 20),
            SizedBox(width: 8),
            Text('How it works (UPI)',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 16),
          _buildStep('1', 'Scan QR code or copy payment link'),
          _buildStep('2', 'Pay using any UPI app'),
          _buildStep('3', 'Copy Transaction ID from payment app'),
          _buildStep('4', 'Paste amount & Transaction ID above'),
          _buildStep('5', 'Coins credited after verification'),
        ],
      ),
    );
  }

  Widget _buildCryptoInstructions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppColors.cardDark, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.info_outline, color: Colors.grey, size: 20),
            SizedBox(width: 8),
            Text('How it works (Crypto)',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 16),
          _buildStep('1', 'Select crypto network (TRC20 / ERC20)'),
          _buildStep('2', 'Copy wallet address or scan QR code'),
          _buildStep('3', 'Send USDT from your wallet'),
          _buildStep('4', 'Enter amount and transaction hash'),
          _buildStep('5', 'Upload screenshot (recommended)'),
          _buildStep('6', 'Coins credited after admin verification'),
        ],
      ),
    );
  }

  Widget _buildStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8)),
          child: Center(
              child: Text(number,
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14))),
        ),
        const SizedBox(width: 12),
        Expanded(
            child: Text(text,
                style: const TextStyle(color: Colors.grey, fontSize: 13))),
      ]),
    );
  }

  String _getAdminQrUrl(String rawUrl) {
    if (rawUrl.trim().isEmpty) return '';
    final url = rawUrl.trim();
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    if (url.startsWith('/')) {
      return '${ApiConfig.rootUrl}$url';
    }
    return '${ApiConfig.rootUrl}/$url';
  }
}

// Purchase History Screen (unchanged)
class PurchaseHistoryScreen extends StatefulWidget {
  const PurchaseHistoryScreen({super.key});

  @override
  State<PurchaseHistoryScreen> createState() => _PurchaseHistoryScreenState();
}

class _PurchaseHistoryScreenState extends State<PurchaseHistoryScreen> {
  List<dynamic> _purchases = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPurchases();
  }

  Future<void> _loadPurchases() async {
    setState(() => _isLoading = true);
    try {
      final result = await ApiService.getPurchaseHistory();
      setState(() {
        _purchases = result['purchases'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.cardDark,
        title: const Text('Purchase History',
            style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _purchases.isEmpty
              ? const Center(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_cart_outlined,
                            color: Colors.grey, size: 64),
                        SizedBox(height: 16),
                        Text('No purchases yet',
                            style: TextStyle(color: Colors.grey, fontSize: 16)),
                      ]),
                )
              : RefreshIndicator(
                  onRefresh: _loadPurchases,
                  color: AppColors.primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _purchases.length,
                    itemBuilder: (context, index) =>
                        _buildPurchaseItem(_purchases[index]),
                  ),
                ),
    );
  }

  Widget _buildPurchaseItem(Map<String, dynamic> purchase) {
    final coins = (purchase['coins'] ?? 0).toDouble();
    final amount = (purchase['amount'] ?? 0).toDouble();
    final status = purchase['status'] ?? 'pending';
    final createdAt = purchase['createdAt'] ?? '';
    final transactionRef = purchase['metadata']?['upiTransactionId'] ??
        purchase['metadata']?['txHash'] ??
        '';

    Color statusColor;
    String statusText;
    switch (status) {
      case 'completed':
        statusColor = AppColors.success;
        statusText = 'COMPLETED';
        break;
      case 'pending':
        statusColor = AppColors.warning;
        statusText = 'PENDING';
        break;
      case 'processing':
        statusColor = const Color(0xFF3D5AFE);
        statusText = 'VERIFYING';
        break;
      default:
        statusColor = AppColors.error;
        statusText = 'REJECTED';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppColors.cardDark, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: const Color(0xFF3D5AFE).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.shopping_cart,
                  color: Color(0xFF3D5AFE), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${coins.toStringAsFixed(0)} OLR',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                    Text('\$${amount.toStringAsFixed(2)}',
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 13)),
                  ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8)),
              child: Text(statusText,
                  style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
            ),
          ]),
          if (transactionRef.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(children: [
              const Icon(Icons.receipt, color: Colors.grey, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                    'TXN: ${transactionRef.length > 20 ? '${transactionRef.substring(0, 20)}...' : transactionRef}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 11)),
              ),
            ]),
          ],
          const SizedBox(height: 8),
          Text(_formatDate(createdAt),
              style: TextStyle(color: Colors.grey[600], fontSize: 11)),
        ],
      ),
    );
  }

  String _formatDate(String dateString) {
    if (dateString.isEmpty) return '';
    try {
      final date = DateTime.parse(dateString).toLocal();
      return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }
}
