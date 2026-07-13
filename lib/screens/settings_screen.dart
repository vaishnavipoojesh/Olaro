import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<String, dynamic>? _settings;
  Map<String, dynamic>? _socialLinks;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        ApiService.getSettings(),
        ApiService.getSocialLinks(),
      ]);
      setState(() {
        _settings = results[0];
        _socialLinks = results[1];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showSnackBar('Could not open link', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.cardDark,
        title: const Text('Settings', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _loadSettings,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // App Info
                    _buildSection('App Information', [
                      _buildInfoItem(
                          'App Name', _settings?['appName'] ?? 'Olaro App'),
                      _buildInfoItem(
                          'Version', _settings?['appVersion'] ?? '1.0.0'),
                      _buildInfoItem('Mining Rate',
                          '${_settings?['miningRate'] ?? 0.25} OLR/hr'),
                      _buildInfoItem('Referral Bonus',
                          '${_settings?['referralBonus'] ?? 10}%'),
                    ]),

                    const SizedBox(height: 20),

                    // Social Links
                    _buildSection('Connect With Us', [
                      if (_socialLinks?['telegram'] != null)
                        _buildSocialItem('Telegram', Icons.telegram,
                            _socialLinks!['telegram']),
                      if (_socialLinks?['twitter'] != null)
                        _buildSocialItem('Twitter', Icons.flutter_dash,
                            _socialLinks!['twitter']),
                      if (_socialLinks?['discord'] != null)
                        _buildSocialItem(
                            'Discord', Icons.discord, _socialLinks!['discord']),
                      if (_socialLinks?['website'] != null)
                        _buildSocialItem('Website', Icons.language,
                            _socialLinks!['website']),
                      if (_socialLinks?['youtube'] != null)
                        _buildSocialItem('YouTube', Icons.play_circle,
                            _socialLinks!['youtube']),
                      if (_socialLinks?['instagram'] != null)
                        _buildSocialItem('Instagram', Icons.camera_alt,
                            _socialLinks!['instagram']),
                    ]),

                    const SizedBox(height: 20),

                    // Support
                    _buildSection('Support', [
                      _buildMenuItem('Help & FAQ', Icons.help_outline, () {}),
                      _buildMenuItem('Contact Support', Icons.support_agent,
                          () {
                        if (_settings?['supportEmail'] != null) {
                          _launchUrl('mailto:${_settings!['supportEmail']}');
                        }
                      }),
                      _buildMenuItem(
                          'Privacy Policy', Icons.privacy_tip_outlined, () {
                        _launchUrl(
                            'https://innovativebusinessolution.github.io/Privacy-policy-olaro/');
                      }),
                      _buildMenuItem(
                          'Refund Policy', Icons.assignment_return_outlined,
                          () {
                        _launchUrl(
                            'https://innovativebusinessolution.github.io/Refund-policy-olaro/');
                      }),
                      _buildMenuItem(
                          'Terms and Conditions', Icons.description_outlined,
                          () {
                        _launchUrl(
                            'https://innovativebusinessolution.github.io/Terms-condition-olaro/');
                      }),
                    ]),

                    const SizedBox(height: 20),

                    // App Version
                    Center(
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.asset(
                              'assets/images/olaro_transparent.png',
                              width: 60,
                              height: 60,
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _settings?['appName'] ?? 'Olaro App',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Version ${_settings?['appVersion'] ?? '1.0.0'}',
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 14),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(
            value,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialItem(String label, IconData icon, String url) {
    return InkWell(
      onTap: () => _launchUrl(url),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
                child:
                    Text(label, style: const TextStyle(color: Colors.white))),
            const Icon(Icons.open_in_new, color: Colors.grey, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.grey, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
                child:
                    Text(label, style: const TextStyle(color: Colors.white))),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
