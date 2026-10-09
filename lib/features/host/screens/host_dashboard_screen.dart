import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/roommate_post_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/user_provider.dart';
import '../../chat/screens/chat_detail_screen.dart';
import '../providers/host_dashboard_provider.dart';

class HostDashboardScreen extends ConsumerStatefulWidget {
  const HostDashboardScreen({super.key});

  @override
  ConsumerState<HostDashboardScreen> createState() =>
      _HostDashboardScreenState();
}

class _HostDashboardScreenState extends ConsumerState<HostDashboardScreen> {
  final _searchController = TextEditingController();
  final _moneyFormat = NumberFormat.decimalPattern('vi_VN');
  Set<String> _draftLocations = {};
  Set<String> _draftRequirements = {};
  final _customRequirementController = TextEditingController();
  RangeValues _draftPrice = const RangeValues(1000000, 10000000);
  HostDashboardFilter _filter = const HostDashboardFilter();
  bool _isLocationExpanded = true;
  bool _isAdvancedExpanded = false;

  @override
  void dispose() {
    _searchController.dispose();
    _customRequirementController.dispose();
    super.dispose();
  }

  void _toggleLocation(String location, bool selected) {
    setState(() {
      if (selected) {
        _draftLocations.add(location);
      } else {
        _draftLocations.remove(location);
      }
    });
  }

  void _applyLocations() {
    setState(() {
      _filter = _filter.copyWith(locations: _draftLocations.toList());
      _isLocationExpanded = false;
    });
  }

  void _clearLocations() => setState(() => _draftLocations.clear());

  void _applyAdvancedFilters() {
    final rangeIsDefault =
        _draftPrice.start <= 1000000 && _draftPrice.end >= 10000000;
    setState(() {
      _filter = HostDashboardFilter(
        locations: _draftLocations.toList(),
        requirements: _draftRequirements.toList(),
        minPrice: rangeIsDefault ? null : _draftPrice.start,
        maxPrice: rangeIsDefault ? null : _draftPrice.end,
        sort: _filter.sort,
        searchQuery: _filter.searchQuery,
      );
      _isAdvancedExpanded = false;
    });
  }

  void _resetFilters() {
    setState(() {
      _draftLocations = {};
      _draftRequirements = {};
      _draftPrice = const RangeValues(1000000, 10000000);
      _filter = HostDashboardFilter(searchQuery: _filter.searchQuery);
    });
  }

  Future<void> _refresh() async {
    ref.invalidate(hostDashboardPostsProvider(_filter));
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }

  void _openNotifications() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => const SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 4, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Thông báo',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 12),
              Text(
                'Bạn chưa có thông báo mới.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openChat(RoommatePostModel post) {
    final currentUser = ref.read(currentUserProvider);
    final profile = ref.read(userProfileProvider).value;
    if (currentUser == null || post.authorId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng đăng nhập để bắt đầu cuộc trò chuyện.'),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatDetailScreen(
          receiverId: post.authorId,
          receiverName: post.authorName,
          receiverAvatar: post.authorAvatar,
          receiverPhone: post.contactPhone,
          isLandlord: false,
          currentUserId: currentUser.uid,
          currentUserName: profile?.displayName ?? 'Chủ nhà',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider).value;
    final posts = ref.watch(hostDashboardPostsProvider(_filter));
    final filterOptions = ref.watch(hostDashboardFilterOptionsProvider);
    final selectedLocations = _filter.locations.isEmpty
        ? 'Tất cả khu vực'
        : '${_filter.locations.join(', ')} (${_filter.locations.length})';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            children: [
              _buildHeader(profile),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildSearchBar()),
                  const SizedBox(width: 8),
                  SizedBox(width: 112, child: _buildAdvancedToggle()),
                ],
              ),
              const SizedBox(height: 10),
              _buildLocationSelector(selectedLocations),
              if (_isLocationExpanded) _buildLocationPanel(filterOptions),
              if (_isAdvancedExpanded) _buildAdvancedPanel(filterOptions),
              const SizedBox(height: 14),
              _buildFeed(posts),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(UserProfile? profile) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(13),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33155EEF),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.home_rounded, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Flexible(
                    child: Text(
                      'HomeShare',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.successContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Chủ trọ VIP',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                profile?.displayName.isNotEmpty == true
                    ? 'Xin chào, ${profile!.displayName}'
                    : 'Mạng lưới Đối tác & Chủ trọ',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        if (profile != null && profile.avatarUrl.isNotEmpty)
          CircleAvatar(
            radius: 17,
            backgroundImage: NetworkImage(profile.avatarUrl),
          )
        else
          CircleAvatar(
            radius: 17,
            backgroundColor: AppColors.primaryContainer,
            child: Text(
              _initials(profile?.displayName ?? 'CT'),
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        IconButton(
          tooltip: 'Thông báo',
          onPressed: _openNotifications,
          icon: const Icon(Icons.notifications_none_rounded),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      onChanged: (value) =>
          setState(() => _filter = _filter.copyWith(searchQuery: value)),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Tìm bài đăng, chủ trọ, đối tác...',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: _searchController.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Xóa tìm kiếm',
                onPressed: () {
                  _searchController.clear();
                  setState(() => _filter = _filter.copyWith(searchQuery: ''));
                },
                icon: const Icon(Icons.close_rounded),
              ),
      ),
    );
  }

  Widget _buildLocationSelector(String selectedLocations) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => setState(() => _isLocationExpanded = !_isLocationExpanded),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
          child: Row(
            children: [
              const Text(
                'Khu vực:',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  selectedLocations,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(
                _isLocationExpanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationPanel(
    AsyncValue<HostDashboardFilterOptions> filterOptions,
  ) {
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: filterOptions.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(18),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => _buildFilterOptionsError('Không tải được khu vực.'),
        data: (options) {
          if (options.locations.isEmpty) {
            return _buildFilterOptionsEmpty(
              'Chưa có khu vực trong dữ liệu bài đăng.',
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Tìm nhanh tỉnh/thành phố...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),
              _locationOptionRow(
                'Tất cả khu vực (Toàn quốc)',
                _draftLocations.length == options.locations.length,
                () =>
                    setState(() => _draftLocations = options.locations.toSet()),
              ),
              for (final location in options.locations)
                _locationOptionRow(
                  location,
                  _draftLocations.contains(location),
                  () => _toggleLocation(
                    location,
                    !_draftLocations.contains(location),
                  ),
                ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: _clearLocations,
                      child: const Text('Bỏ chọn tất cả'),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: _applyLocations,
                      child: Text('Áp dụng (${_draftLocations.length})'),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _locationOptionRow(String label, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: Checkbox(
                value: selected,
                onChanged: (_) => onTap(),
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: selected ? AppColors.primary : AppColors.textDark,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedToggle() {
    return FilledButton.icon(
      onPressed: () =>
          setState(() => _isAdvancedExpanded = !_isAdvancedExpanded),
      icon: Icon(
        _isAdvancedExpanded ? Icons.tune_rounded : Icons.filter_alt_outlined,
        size: 18,
      ),
      label: Text(_isAdvancedExpanded ? 'Thu gọn' : 'Nâng cao'),
    );
  }

  Widget _buildAdvancedPanel(
    AsyncValue<HostDashboardFilterOptions> filterOptions,
  ) {
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Bộ lọc nâng cao',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
                TextButton(
                  onPressed: _resetFilters,
                  child: const Text('Đặt lại'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Giá thuê / tháng',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            Row(
              children: [
                Expanded(child: _priceBox('Tối thiểu', _draftPrice.start)),
                const SizedBox(width: 8),
                Expanded(child: _priceBox('Tối đa', _draftPrice.end)),
              ],
            ),
            RangeSlider(
              values: _draftPrice,
              min: 1000000,
              max: 10000000,
              divisions: 18,
              labels: RangeLabels(
                '${_draftPrice.start.round()}',
                '${_draftPrice.end.round()}',
              ),
              onChanged: (value) => setState(() => _draftPrice = value),
            ),
            const SizedBox(height: 4),
            const Text(
              'Tiện ích & Yêu cầu',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 7),
            filterOptions.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, _) =>
                  _buildFilterOptionsError('Không tải được yêu cầu.'),
              data: (options) => options.requirements.isEmpty
                  ? _buildFilterOptionsEmpty(
                      'Chưa có yêu cầu trong dữ liệu bài đăng.',
                    )
                  : Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _customRequirementController,
                                decoration: const InputDecoration(
                                  hintText: 'Thêm tiện ích, yêu cầu riêng...',
                                  isDense: true,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                final value = _customRequirementController.text
                                    .trim();
                                if (value.isNotEmpty) {
                                  setState(() {
                                    _draftRequirements.add(value);
                                    _customRequirementController.clear();
                                  });
                                }
                              },
                              child: const Text('Thêm'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: options.requirements.map((requirement) {
                            final selected = _draftRequirements.contains(
                              requirement,
                            );
                            return FilterChip(
                              label: Text(
                                requirement,
                                style: const TextStyle(fontSize: 11),
                              ),
                              selected: selected,
                              onSelected: (value) => setState(
                                () => value
                                    ? _draftRequirements.add(requirement)
                                    : _draftRequirements.remove(requirement),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Sắp xếp kết quả',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _sortChoice('Mới nhất', HostDashboardSort.newest),
                _sortChoice(
                  'Được quan tâm nhiều nhất',
                  HostDashboardSort.mostInterested,
                ),
                _sortChoice(
                  'Giá thấp đến cao',
                  HostDashboardSort.priceAscending,
                ),
                _sortChoice(
                  'Giá cao đến thấp',
                  HostDashboardSort.priceDescending,
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _applyAdvancedFilters,
                child: const Text('Áp dụng bộ lọc'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterOptionsEmpty(String message) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
    );
  }

  Widget _priceBox(String label, double value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    decoration: BoxDecoration(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 3),
        Text(
          '${_moneyFormat.format(value.round())}đ',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );

  Widget _sortChoice(String label, HostDashboardSort sort) {
    final selected = _filter.sort == sort;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      selected: selected,
      onSelected: (_) => setState(() => _filter = _filter.copyWith(sort: sort)),
    );
  }

  Widget _buildFilterOptionsError(String message) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 18,
            color: AppColors.danger,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12, color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeed(AsyncValue<List<RoommatePostModel>> posts) {
    return posts.when(
      loading: () => const Padding(
        padding: EdgeInsets.only(top: 32),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => _buildError(error),
      data: (items) {
        if (items.isEmpty) return _buildEmptyState();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${items.length} bài đăng phù hợp',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            for (var index = 0; index < items.length; index++) ...[
              _buildPostCard(items[index]),
              if (index < items.length - 1) const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }

  Widget _buildError(Object error) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.dangerContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            color: AppColors.danger,
            size: 32,
          ),
          const SizedBox(height: 8),
          const Text(
            'Không tải được bảng tin',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Kiểm tra kết nối hoặc quyền truy cập Firestore rồi thử lại.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () =>
                ref.invalidate(hostDashboardPostsProvider(_filter)),
            child: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 40),
      child: Column(
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 48,
            color: AppColors.textSecondary.withValues(alpha: 0.65),
          ),
          const SizedBox(height: 10),
          const Text(
            'Chưa có bài đăng phù hợp',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          const Text(
            'Thử bỏ bớt bộ lọc hoặc quay lại sau khi có bài đăng mới.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildPostCard(RoommatePostModel post) {
    final tags = post.purposeTags.isNotEmpty
        ? post.purposeTags
        : post.habits.take(3).toList();
    final price = post.pricePerPerson > 0
        ? post.pricePerPerson
        : post.budgetMax;
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 10, 0),
            child: Row(
              children: [
                _buildAvatar(post.authorName, post.authorAvatar, radius: 21),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              post.authorName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (post.isVerified) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.verified_rounded,
                              color: AppColors.primary,
                              size: 15,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${post.district} · ${_timeAgo(post.createdAt)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Tùy chọn bài đăng',
                  onPressed: () {},
                  icon: const Icon(Icons.more_horiz_rounded),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  post.description,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: tags.map((tag) => _tag(tag)).toList(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildPostMedia(post),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        post.address.isEmpty ? post.district : post.address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Text(
                      '${_moneyFormat.format(price.round())} đ',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _stat(
                      Icons.favorite_border_rounded,
                      '${post.interestedCount} quan tâm',
                    ),
                    const SizedBox(width: 14),
                    _stat(
                      Icons.mode_comment_outlined,
                      '${post.replyCount} phản hồi',
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => _openChat(post),
                      icon: const Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 17,
                      ),
                      label: const Text('Nhắn tin'),
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

  Widget _buildPostMedia(RoommatePostModel post) {
    if (post.images.isEmpty) {
      return Container(
        height: 112,
        margin: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F0FE),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Icon(
            Icons.handshake_outlined,
            size: 48,
            color: AppColors.primary,
          ),
        ),
      );
    }
    return SizedBox(
      height: 170,
      width: double.infinity,
      child: Image.network(
        post.images.first,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          color: const Color(0xFFE8F0FE),
          child: const Icon(
            Icons.image_not_supported_outlined,
            size: 42,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(String name, String avatar, {required double radius}) {
    if (avatar.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(avatar),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primaryContainer,
      child: Text(
        _initials(name),
        style: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _tag(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: AppColors.successContainer,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 10,
        color: AppColors.success,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  Widget _stat(IconData icon, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 15, color: AppColors.textSecondary),
      const SizedBox(width: 4),
      Text(
        text,
        style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
      ),
    ],
  );

  String _timeAgo(DateTime date) {
    final difference = DateTime.now().difference(date);
    if (difference.inMinutes < 1) return 'vừa xong';
    if (difference.inHours < 1) return '${difference.inMinutes} phút trước';
    if (difference.inDays < 1) return '${difference.inHours} giờ trước';
    if (difference.inDays < 7) return '${difference.inDays} ngày trước';
    return DateFormat('dd/MM/yyyy').format(date);
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'HS';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }
}
