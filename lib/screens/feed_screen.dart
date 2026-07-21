import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';
import '../utils/constants.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/admob_service.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  static final GlobalKey<FeedScreenState> globalKey =
      GlobalKey<FeedScreenState>();

  @override
  State<FeedScreen> createState() => FeedScreenState();
}

class FeedScreenState extends State<FeedScreen> with TickerProviderStateMixin {
  List<dynamic> _feeds = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _currentPage = 1;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();

  // Track liked posts locally
  final Set<String> _likedPosts = {};
  Map<String, dynamic>? _currentUserProfile;
  bool _hasLoaded = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Don't load on init - will be loaded when tab is selected
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreFeeds();
    }
  }

  // Called externally when tab is selected
  void refreshFeeds() {
    _loadProfile();
    _loadFeeds();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await ApiService.getProfile();
      if (mounted) {
        setState(() {
          _currentUserProfile = profile['user'];
        });
      }
    } catch (e) {
      debugPrint('Error loading profile for comments: $e');
    }
  }

  Future<void> _loadFeeds() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.getPublicFeed(page: 1);
      if (mounted) {
        setState(() {
          _feeds = response['data'] ?? [];
          _currentPage = 1;
          _hasMore = false; // Backend returns all posts at once
          _isLoading = false;
          _hasLoaded = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasLoaded = true;
        });
        _showSnackBar('Error loading feed: $e', isError: true);
      }
    }
  }

  Future<void> _loadMoreFeeds() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);
    try {
      final response = await ApiService.getPublicFeed(page: _currentPage + 1);
      if (mounted) {
        setState(() {
          _feeds.addAll(response['data'] ?? []);
          _currentPage++;
          _hasMore = false; // Backend returns all posts at once
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  Future<void> _handleLike(String feedId, int index) async {
    HapticFeedback.mediumImpact();

    if (feedId.isEmpty) {
      _showSnackBar('Error: Post ID is missing', isError: true);
      return;
    }

    final isLiked = _likedPosts.contains(feedId);

    // Optimistic update
    setState(() {
      final currentLikes = _feeds[index]['likes'];
      int likesCount = 0;

      if (currentLikes is List) {
        likesCount = currentLikes.length;
      } else if (currentLikes is int) {
        likesCount = currentLikes;
      }

      if (isLiked) {
        _likedPosts.remove(feedId);
        _feeds[index]['likes'] = likesCount > 0 ? likesCount - 1 : 0;
      } else {
        _likedPosts.add(feedId);
        _feeds[index]['likes'] = likesCount + 1;
      }
    });

    try {
      final response = await ApiService.likeFeed(feedId);
      // Sync with server response
      if (mounted && response['likes'] != null) {
        setState(() {
          _feeds[index]['likes'] = response['likes'];
          // Ensure liked status matches server if returned (optional, depends on API)
          // For now, we trust our optimistic toggle unless error
        });
      }
    } catch (e) {
      // Revert on error
      if (mounted) {
        setState(() {
          final currentLikes = _feeds[index][
              'likes']; // Should be int now due to optimistic update, but safe check
          int likesCount = 0;

          if (currentLikes is List) {
            likesCount = currentLikes.length;
          } else if (currentLikes is int) {
            likesCount = currentLikes;
          }

          if (isLiked) {
            _likedPosts.add(feedId);
            _feeds[index]['likes'] = likesCount + 1;
          } else {
            _likedPosts.remove(feedId);
            _feeds[index]['likes'] = likesCount > 0 ? likesCount - 1 : 0;
          }
        });
        debugPrint('Like error: $e'); // Debug
        _showSnackBar('Failed to like post: $e', isError: true);
      }
    }
  }

  // Show comments bottom sheet
  void _showCommentsSheet(Map<String, dynamic> feed, int index) {
    HapticFeedback.lightImpact();

    final feedId = feed['_id'] ?? '';
    final commentsCount = (feed['comments'] is List)
        ? (feed['comments'] as List).length
        : (feed['comments'] ?? 0);
    final initialComments = (feed['comments'] is List)
        ? List<Map<String, dynamic>>.from(feed['comments'])
        : null;
    final title = feed['title'] ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CommentsSheet(
        feedId: feedId,
        feedTitle: title,
        commentsCount: commentsCount is int ? commentsCount : 0,
        initialComments: initialComments,
        onCommentAdded: () {
          setState(() {
            // Optimistic update of the main feed screen comment count
            if (_feeds[index]['comments'] is int) {
              _feeds[index]['comments'] = (_feeds[index]['comments'] ?? 0) + 1;
            } else if (_feeds[index]['comments'] is List) {
              _feeds[index]['comments']
                  .add(<String, dynamic>{'text': 'New comment', 'likes': 0});
            }
          });
        },
        currentUser: _currentUserProfile,
      ),
    );
  }

  // Show post options menu
  void _showPostOptions(Map<String, dynamic> feed, int index) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1D1F33),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            _buildOptionTile(
              icon: Icons.copy,
              label: 'Copy Text',
              onTap: () {
                Navigator.pop(context);
                final text =
                    '${feed['title'] ?? ''}\n${feed['description'] ?? ''}';
                Clipboard.setData(ClipboardData(text: text));
                _showSnackBar('Text copied!', isSuccess: true);
              },
            ),
            const SizedBox(height: 10),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? const Color(0xFFFF4757) : Colors.white,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: isDestructive ? const Color(0xFFFF4757) : Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  void _showSnackBar(String message,
      {bool isError = false, bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error
                  : isSuccess
                      ? Icons.check_circle
                      : Icons.info,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError
            ? const Color(0xFFFF4757)
            : isSuccess
                ? const Color(0xFF00D4AA)
                : const Color(0xFF3D5AFE),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inDays > 30) {
        return '${date.day} ${_getMonth(date.month)} ${date.year}';
      } else if (diff.inDays > 0) {
        return '${diff.inDays}d ago';
      } else if (diff.inHours > 0) {
        return '${diff.inHours}h ago';
      } else if (diff.inMinutes > 0) {
        return '${diff.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return '';
    }
  }

  String _getMonth(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month - 1];
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: !_hasLoaded
                  ? _buildInitialState()
                  : _isLoading
                      ? _buildLoadingState()
                      : _feeds.isEmpty
                          ? _buildEmptyState()
                          : _buildFeedList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInitialState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFF9333EA).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.article_rounded,
              color: Color(0xFF9333EA),
              size: 50,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Community Feed',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap to load latest posts',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadFeeds,
            icon: const Icon(Icons.refresh),
            label: const Text('Load Feed'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9333EA),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1D1F33), Color(0xFF0A0E21)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF9333EA), Color(0xFF7C3AED)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF9333EA).withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child:
                const Icon(Icons.dynamic_feed, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Community Feed',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Latest updates & news',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: _loadFeeds,
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF9333EA), Color(0xFF7C3AED)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF9333EA).withValues(alpha: 0.4),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Loading feed...',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFF9333EA).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.article_outlined,
              color: Color(0xFF9333EA),
              size: 50,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No posts yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Check back later for updates!',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadFeeds,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9333EA),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedList() {
    return RefreshIndicator(
      onRefresh: _loadFeeds,
      color: const Color(0xFF9333EA),
      backgroundColor: AppColors.cardDark,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _feeds.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _feeds.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(
                  color: Color(0xFF9333EA),
                ),
              ),
            );
          }
          final showAdAfter = (index + 1) % 3 == 0;
          return Column(
            children: [
              _buildFeedCard(_feeds[index], index),
              if (showAdAfter) const InlineFeedBannerAd(),
            ],
          );
        },
      ),
    );
  }

  String? _getImageUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http')) return path;
    return '${ApiConfig.rootUrl}${path.startsWith('/') ? '' : '/'}$path';
  }

  Widget _buildFeedCard(Map<String, dynamic> feed, int index) {
    final feedId = feed['_id'] ?? '';
    // Map backend fields to UI fields
    final isOfficial = feed['authorType'] == 'admin';
    final authorName =
        feed['authorName'] ?? (isOfficial ? 'Official Update' : 'User');
    final authorInitial =
        authorName.isNotEmpty ? authorName[0].toUpperCase() : '';
    final authorAvatar = _getImageUrl(feed[
        'authorAvatar']); // usage remains same, but might need mapping if backend adds it

    final hashtag =
        feed['tag'] ?? feed['hashtag'] ?? '#Community'; // mapped 'tag'
    final hashtagColor =
        _parseColor(feed['hashtagColor']) ?? const Color(0xFF9333EA);

    final title = feed['title'] ?? '';
    final description =
        feed['content'] ?? feed['description'] ?? ''; // mapped 'content'

    // Map 'imageUrl' from backend to 'image' for UI
    final imagePath = feed['imageUrl'] ?? feed['image'];
    final image = _getImageUrl(imagePath);

    final likesVal = feed['likes'];
    final likes =
        (likesVal is List) ? likesVal.length : (likesVal is int ? likesVal : 0);

    final commentsVal = feed['comments'];
    final comments = (commentsVal is List)
        ? commentsVal.length
        : (commentsVal is int ? commentsVal : 0);

    final postDate =
        feed['createdAt'] ?? feed['postDate']; // mapped 'createdAt'
    final isLiked = _likedPosts.contains(feedId);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1F33),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header - Author info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Author avatar - show image if available, else show initial
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: authorAvatar == null
                        ? LinearGradient(
                            colors: [
                              hashtagColor,
                              hashtagColor.withValues(alpha: 0.7)
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: hashtagColor.withValues(alpha: 0.3),
                      width: 2,
                    ),
                    image: authorAvatar != null
                        ? DecorationImage(
                            image: NetworkImage(authorAvatar),
                            fit: BoxFit.cover,
                            onError: (_, __) {},
                          )
                        : null,
                  ),
                  child: authorAvatar == null
                      ? Center(
                          child: Text(
                            authorInitial,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              '@$authorName',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.verified,
                            color: hashtagColor,
                            size: 16,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: hashtagColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              hashtag,
                              style: TextStyle(
                                color: hashtagColor,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '• ${_formatDate(postDate)}',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // More options
                IconButton(
                  onPressed: () => _showPostOptions(feed, index),
                  icon: const Icon(
                    Icons.more_vert,
                    color: Colors.grey,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),

          // Title
          if (title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ),

          // Description
          if (description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                description,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),

          const SizedBox(height: 12),

          // Post Image with double tap to like
          if (image != null && image.toString().isNotEmpty)
            GestureDetector(
              onDoubleTap: () {
                if (!isLiked) {
                  _handleLike(feedId, index);
                  _showLikeAnimation(context);
                }
              },
              child: ClipRRect(
                child: Image.network(
                  image,
                  width: double.infinity,
                  height: 250,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 250,
                    color: Colors.grey[900],
                    child: const Center(
                      child: Icon(Icons.image_not_supported,
                          color: Colors.grey, size: 50),
                    ),
                  ),
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 250,
                      color: Colors.grey[900],
                      child: Center(
                        child: CircularProgressIndicator(
                          color: hashtagColor,
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

          // Engagement Bar
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Action buttons row
                Row(
                  children: [
                    // Like Button
                    _buildEngagementButton(
                      icon: isLiked ? Icons.favorite : Icons.favorite_border,
                      label: _formatNumber(likes),
                      color: isLiked ? const Color(0xFFFF4757) : Colors.grey,
                      onTap: () => _handleLike(feedId, index),
                      isActive: isLiked,
                    ),
                    const SizedBox(width: 16),
                    // Comment Button
                    _buildEngagementButton(
                      icon: Icons.chat_bubble_outline,
                      label: _formatNumber(comments),
                      color: Colors.grey,
                      onTap: () => _showCommentsSheet(feed, index),
                    ),
                    const Spacer(),
                  ],
                ),

                // Likes count text
                if (likes > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      '$likes ${likes == 1 ? 'person likes' : 'people like'} this',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                // View comments link
                if (comments > 0)
                  GestureDetector(
                    onTap: () => _showCommentsSheet(feed, index),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'View all $comments comments',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEngagementButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: isActive ? color : Colors.grey,
              fontSize: 14,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  void _showLikeAnimation(BuildContext context) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 500),
          builder: (context, value, child) {
            return Opacity(
              opacity: value > 0.5 ? 2 - (value * 2) : value * 2,
              child: Transform.scale(
                scale: 0.5 + (value * 0.5),
                child: const Icon(
                  Icons.favorite,
                  color: Color(0xFFFF4757),
                  size: 100,
                ),
              ),
            );
          },
          onEnd: () {
            overlayEntry.remove();
          },
        ),
      ),
    );

    overlay.insert(overlayEntry);
  }

  Color? _parseColor(String? colorString) {
    if (colorString == null) return null;
    try {
      final hex = colorString.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (e) {
      return null;
    }
  }
}

// Comments Bottom Sheet Widget
class _CommentsSheet extends StatefulWidget {
  final String feedId;
  final String feedTitle;
  final int commentsCount;
  final VoidCallback onCommentAdded;
  final List<Map<String, dynamic>>? initialComments;
  final Map<String, dynamic>? currentUser;

  const _CommentsSheet({
    required this.feedId,
    required this.feedTitle,
    required this.commentsCount,
    required this.onCommentAdded,
    this.initialComments,
    this.currentUser,
  });

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final TextEditingController _commentController = TextEditingController();
  final List<Map<String, dynamic>> _comments = [];
  bool _isLoading = true;
  bool _isPosting = false;
  int _totalComments = 0;

  @override
  void initState() {
    super.initState();
    _totalComments = widget.commentsCount;
    if (widget.initialComments != null && widget.initialComments!.isNotEmpty) {
      _comments.addAll(widget.initialComments!);
      _isLoading = false;
    } else {
      _loadComments();
    }
  }

  Future<void> _loadComments() async {
    setState(() => _isLoading = true);

    // Try to fetch comments from API
    try {
      final response = await ApiService.getComments(widget.feedId);
      if (mounted) {
        setState(() {
          _comments.clear();
          _comments.addAll(
              List<Map<String, dynamic>>.from(response['comments'] ?? []));
          _isLoading = false;
        });
      }
    } catch (e) {
      // If API fails, show sample comments for demo
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        setState(() {
          if (_totalComments > 0) {
            _comments.addAll([
              {
                'user': 'CryptoFan',
                'initial': 'C',
                'comment': 'This is amazing! 🔥',
                'time': '2h ago',
                'likes': 12,
              },
              {
                'user': 'MiningPro',
                'initial': 'M',
                'comment': 'Great post, keep it up!',
                'time': '4h ago',
                'likes': 8,
              },
              {
                'user': 'BlockchainBob',
                'initial': 'B',
                'comment': 'Very informative content 👍',
                'time': '6h ago',
                'likes': 5,
              },
            ]);
          }
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _postComment() async {
    if (_commentController.text.trim().isEmpty) return;

    setState(() => _isPosting = true);
    HapticFeedback.lightImpact();

    final commentText = _commentController.text.trim();

    final userName = widget.currentUser?['name'] ?? 'You';
    final initial = userName.isNotEmpty ? userName[0].toUpperCase() : 'Y';

    // Add comment locally immediately
    setState(() {
      _comments.insert(0, {
        'user': userName,
        'initial': initial,
        'comment': commentText,
        'time': 'Just now',
        'likes': 0,
      });
      _commentController.clear();
      _isPosting = false;
      _totalComments++;
    });

    widget.onCommentAdded();

    // Try to post to API
    try {
      await ApiService.postComment(widget.feedId, commentText);
    } catch (e) {
      // Silently fail - comment is shown locally
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to post comment: $e'),
            backgroundColor: const Color(0xFFFF4757),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Color(0xFF1D1F33),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text(
                  'Comments',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9333EA).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$_totalComments',
                    style: const TextStyle(
                      color: Color(0xFF9333EA),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.grey),
                ),
              ],
            ),
          ),

          Divider(color: Colors.grey[800], height: 1),

          // Comments List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF9333EA),
                    ),
                  )
                : _comments.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(0xFF9333EA)
                                    .withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.chat_bubble_outline,
                                color: Colors.grey[600],
                                size: 50,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No comments yet',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Be the first to comment!',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _comments.length,
                        itemBuilder: (context, index) {
                          final comment = _comments[index];
                          return _buildCommentTile(comment, index);
                        },
                      ),
          ),

          // Comment Input
          Container(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF0A0E21),
              border: Border(
                top: BorderSide(color: Colors.grey[800]!),
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF9333EA), Color(0xFF7C3AED)],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text(
                        'Y',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Add a comment...',
                        hintStyle: TextStyle(color: Colors.grey[600]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: const Color(0xFF1D1F33),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      maxLines: 1,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _postComment(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _isPosting ? null : _postComment,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF9333EA), Color(0xFF7C3AED)],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: _isPosting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.send_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentTile(Map<String, dynamic> comment, int index) {
    // Safely extract fields, falling back to backend fields or defaults
    String userName = comment['user'] ?? comment['userName'] ?? '';
    if (userName.isEmpty &&
        comment['userId'] != null &&
        widget.currentUser != null &&
        comment['userId'] == widget.currentUser!['_id']) {
      userName = widget.currentUser!['name'] ?? 'You';
    }
    if (userName.isEmpty) userName = 'User';

    final initial = comment['initial'] ??
        (userName.isNotEmpty ? userName[0].toUpperCase() : 'U');
    final commentText = comment['text'] ?? comment['comment'] ?? '';
    final timeStr = comment['time'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.primaries[userName.hashCode % Colors.primaries.length],
                  Colors.primaries[
                      (userName.hashCode + 3) % Colors.primaries.length],
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      userName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeStr,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  commentText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          comment['likes'] = (comment['likes'] ?? 0) + 1;
                        });
                      },
                      child: Row(
                        children: [
                          const Icon(
                            Icons.favorite_border,
                            color: Colors.grey,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${comment['likes'] ?? 0}',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Reply feature coming soon!'),
                            backgroundColor: const Color(0xFF3D5AFE),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        );
                      },
                      child: const Text(
                        'Reply',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }
}

class InlineFeedBannerAd extends StatefulWidget {
  const InlineFeedBannerAd({super.key});

  @override
  State<InlineFeedBannerAd> createState() => _InlineFeedBannerAdState();
}

class _InlineFeedBannerAdState extends State<InlineFeedBannerAd> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _bannerAd = AdMobService.createBannerAd(
      onAdLoaded: () {
        if (mounted) setState(() => _isAdLoaded = true);
      },
      onAdFailedToLoad: (error) {
        if (mounted) setState(() => _isAdLoaded = false);
      },
    );
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdLoaded || _bannerAd == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          const Text('Sponsored', style: TextStyle(color: Colors.grey, fontSize: 10)),
          const SizedBox(height: 4),
          SizedBox(
            width: _bannerAd!.size.width.toDouble(),
            height: _bannerAd!.size.height.toDouble(),
            child: AdWidget(ad: _bannerAd!),
          ),
        ],
      ),
    );
  }
}
