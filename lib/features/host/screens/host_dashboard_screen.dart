import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

// Chủ trọ - Dashboard mẫu - Luồng đi: Mở từ tab Trang chủ của HostMainScreen.
// Dữ liệu bên dưới chỉ minh họa giao diện, chưa đọc hoặc ghi Firebase.
class HostDashboardScreen extends StatefulWidget {
  const HostDashboardScreen({super.key});

  @override
  State<HostDashboardScreen> createState() => _HostDashboardScreenState();
}

class _HostDashboardScreenState extends State<HostDashboardScreen> {
  bool _isLocationExpanded = true;
  final Set<String> _selectedLocations = {'TP. Hồ Chí Minh', 'Bình Dương'};
  String _appliedLocations = 'TP. Hồ Chí Minh, Bình Dương (2)';
  static const _locations = [
    'TP. Hồ Chí Minh',
    'Bình Dương',
    'Đồng Nai',
    'Long An',
    'Bà Rịa - Vũng Tàu',
  ];

  // Chủ trọ - Đóng mở khu vực - Luồng đi: Chạm thanh Khu vực trên Dashboard
  // để hiện hoặc ẩn danh sách lựa chọn, không chuyển màn hình.
  void _toggleLocationPanel() =>
      setState(() => _isLocationExpanded = !_isLocationExpanded);

  // Chủ trọ - Chọn khu vực mẫu - Luồng đi: Tích hoặc bỏ tích tỉnh/thành
  // trong panel; lựa chọn chỉ lưu tại màn hình, chưa lọc dữ liệu Firebase.
  void _selectLocation(String location, bool selected) {
    setState(() {
      if (selected) {
        _selectedLocations.add(location);
      } else {
        _selectedLocations.remove(location);
      }
    });
  }

  // Chủ trọ - Bỏ chọn khu vực - Luồng đi: Xóa các lựa chọn trong panel;
  // chờ người dùng bấm Áp dụng để cập nhật nhãn Khu vực.
  void _clearLocations() => setState(_selectedLocations.clear);

  // Chủ trọ - Áp dụng khu vực mẫu - Luồng đi: Cập nhật nhãn khu vực và
  // đóng panel; các thẻ đối tác vẫn là dữ liệu minh họa cố định.
  void _applyLocations() {
    setState(() {
      _appliedLocations = _selectedLocations.isEmpty
          ? 'Tất cả khu vực'
          : '${_selectedLocations.join(', ')} (${_selectedLocations.length})';
      _isLocationExpanded = false;
    });
  }

  // Chủ trọ - Thông báo chức năng mẫu - Luồng đi: Các nút chưa có màn hình
  // đích chỉ hiện thông báo tại Dashboard, không tạo giao dịch hoặc cuộc chat.
  void _showPlaceholder(String feature) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$feature sẽ được bổ sung sau.')));
  }

  // Chủ trọ - Hiển thị Dashboard - Luồng đi: Hiển thị header, khu vực và
  // bảng tin mẫu theo ảnh tham khảo; bottom nav do HostMainScreen quản lý.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.home, color: Colors.white),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'HomeShare',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF126FC4),
                            ),
                          ),
                          Chip(
                            label: Text(
                              'Chủ trọ VIP',
                              style: TextStyle(fontSize: 10),
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      Text(
                        'Mạng lưới Đối tác & Chủ trọ',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF65758F),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Thông báo',
                  onPressed: () => _showPlaceholder('Thông báo'),
                  icon: const Icon(Icons.notifications_none),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    readOnly: true,
                    onTap: () => _showPlaceholder('Tìm kiếm đối tác'),
                    decoration: const InputDecoration(
                      hintText: 'Tìm bài đăng, chủ trọ, đối tác...',
                      hintStyle: TextStyle(fontSize: 12),
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  // Chủ trọ - Giới hạn nút lọc - Luồng đi: Nút nằm cạnh ô
                  // tìm kiếm nên dùng chiều rộng nội dung thay vì toàn màn hình.
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                  onPressed: () => _showPlaceholder('Bộ lọc nâng cao'),
                  icon: const Icon(Icons.filter_alt_outlined, size: 18),
                  label: const Text('Nâng cao'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                onTap: _toggleLocationPanel,
                title: Text(
                  'Khu vực: $_appliedLocations',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: Icon(
                  _isLocationExpanded ? Icons.expand_less : Icons.expand_more,
                ),
              ),
            ),
            if (_isLocationExpanded) _buildLocationPanel(),
            const SizedBox(height: 18),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Color(0xFFD1FAE5),
                      child: Text('HS'),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Chào anh/chị, bạn muốn kết nối chia sẻ khách thuê?',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 10),
              child: Text(
                'Dashboard mẫu • Dữ liệu minh họa',
                style: TextStyle(fontSize: 11, color: Color(0xFF65758F)),
              ),
            ),
            _buildPartnerCard(
              name: 'Chú Ba - Hệ thống Nhà trọ',
              initials: 'CB',
              location: 'TP. Hồ Chí Minh',
              description:
                  'Kết nối các chủ trọ để chia sẻ nguồn khách thuê và hợp tác quản lý phòng trọ.',
              banner: 'Cụm Trọ Chú Ba • TP. Hồ Chí Minh',
              icon: Icons.apartment,
            ),
            const SizedBox(height: 12),
            _buildPartnerCard(
              name: 'Cô Mai - Hệ Thống KTX Bình Dương',
              initials: 'CM',
              location: 'Bình Dương',
              description:
                  'Kết nối đối tác phòng trọ, KTX mini và chia sẻ nguồn khách cần tìm chỗ ở.',
              banner: 'KTX Mini • Bình Dương',
              icon: Icons.bed_outlined,
            ),
          ],
        ),
      ),
    );
  }

  // Chủ trọ - Hiển thị panel khu vực - Luồng đi: Mở từ thanh Khu vực;
  // chọn tỉnh/thành rồi bấm Áp dụng để cập nhật nhãn và quay về bảng tin mẫu.
  Widget _buildLocationPanel() => Card(
    child: Column(
      children: [
        for (final location in _locations)
          CheckboxListTile(
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(location, style: const TextStyle(fontSize: 13)),
            value: _selectedLocations.contains(location),
            onChanged: (value) => _selectLocation(location, value ?? false),
          ),
        Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              TextButton(
                onPressed: _clearLocations,
                child: const Text('Bỏ chọn tất cả'),
              ),
              const Spacer(),
              Flexible(
                child: FilledButton(
                  onPressed: _applyLocations,
                  child: Text('Áp dụng (${_selectedLocations.length})'),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  // Chủ trọ - Hiển thị thẻ đối tác mẫu - Luồng đi: Đọc dữ liệu minh họa
  // truyền từ Dashboard; nút Nhắn tin chỉ báo chức năng sẽ bổ sung sau.
  Widget _buildPartnerCard({
    required String name,
    required String initials,
    required String location,
    required String description,
    required String banner,
    required IconData icon,
  }) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xFFE3EAF3),
                      child: Text(initials),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            location,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Tùy chọn đối tác',
                      onPressed: () => _showPlaceholder('Tùy chọn đối tác'),
                      icon: const Icon(Icons.more_vert),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  description,
                  style: const TextStyle(fontSize: 13, height: 1.6),
                ),
                const SizedBox(height: 10),
                const Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    Chip(
                      label: Text(
                        'Chia sẻ khách thuê',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                    Chip(
                      label: Text(
                        'Hỗ trợ đối tác',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            height: 160,
            color: const Color(0xFFE4F3EC),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 64, color: AppColors.primary),
                const SizedBox(height: 12),
                Text(
                  banner,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const Text(
                  'Ảnh cơ sở minh họa',
                  style: TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _showPlaceholder('Nhắn tin trao đổi'),
                icon: const Icon(Icons.chat_bubble_outline, size: 18),
                label: const Text('Nhắn tin trao đổi'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
