import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/vietnam_locations.dart';
import '../../../data/models/room_model.dart';
import '../../auth/providers/user_provider.dart';
import '../data/host_property.dart';
import '../providers/host_management_provider.dart';
import '../widgets/host_room_widgets.dart';

// Chủ trọ - Bộ chọn ảnh - Luồng đi: Dùng picker có thể thay thế khi
// kiểm thử; thiết bị thực mở thư viện ảnh qua image_picker.
final hostImagePickerProvider = Provider<ImagePicker>((ref) => ImagePicker());

// Chủ trọ - Tạo nhà/phòng - Luồng đi: Dấu cộng ở khu Quản lý mở form
// hai tab; lưu nhà trước rồi chọn cơ sở để tạo phòng trên Firebase.
class HostCreateScreen extends ConsumerStatefulWidget {
  const HostCreateScreen({
    super.key,
    this.propertyId,
    this.startWithRoom = false,
  });
  final String? propertyId;
  final bool startWithRoom;
  @override
  ConsumerState<HostCreateScreen> createState() => _HostCreateScreenState();
}

class _HostCreateScreenState extends ConsumerState<HostCreateScreen> {
  final _houseForm = GlobalKey<FormState>();
  final _roomForm = GlobalKey<FormState>();
  final _fields = <String, TextEditingController>{
    for (final name in [
      'name',
      'address',
      'ward',
      'planned',
      'floors',
      'code',
      'price',
      'deposit',
      'floor',
      'notes',
    ])
      name: TextEditingController(),
  };
  final _houseImages = <HostUpload>[];
  final _roomImages = <HostUpload>[];
  final _types = <String>{'Dãy trọ sinh viên'};
  final _amenities = <String>{};
  final _customAmenity = TextEditingController();
  bool _amenitiesExpanded = true;
  String _city = VietnamLocations.provinces.first;
  String? _selectedPropertyId, _draftPropertyId;
  String? _draftOwner;
  HostProperty? _justCreated;
  HostUpload? _proof;
  bool _roomTab = false, _saving = false, _picking = false;
  RangeValues _rent = const RangeValues(2000000, 5000000);
  double _area = 25;
  int _capacity = 2;
  String _roomType = 'Phòng trọ';
  final String _operationId = List.generate(
    16,
    (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
  static const _typeOptions = [
    'Dãy trọ sinh viên',
    'Căn hộ mini / CHDV',
    'Chung cư mini',
    'Nhà nguyên căn',
  ];
  static const _amenityOptions = [
    'Máy lạnh',
    'Có gác lửng',
    'Wifi tốc độ cao',
    'Giờ giấc tự do',
    'Máy giặt',
    'Tủ lạnh',
    'Cho nuôi thú cưng',
    'Ban công / Cửa sổ lớn',
    'Không chung chủ',
    'Chỗ để xe miễn phí',
  ];
  String _money(num value) => NumberFormat.decimalPattern('vi').format(value);

  // Chủ trọ - Khởi tạo form - Luồng đi: Nhận cơ sở khi mở từ thẻ nhà;
  // các trường bắt đầu trống để tránh lưu nhầm dữ liệu mẫu trong HTML.
  @override
  void initState() {
    super.initState();
    _roomTab = widget.startWithRoom;
    _selectedPropertyId = widget.propertyId;
    _fields['floors']!.text = '1';
    _fields['floor']!.text = '1';
    _fields['deposit']!.text = '0';
  }

  // Chủ trọ - Giải phóng form - Luồng đi: Đóng màn tạo nhà/phòng thì
  // hủy các controller; dữ liệu chỉ lưu khi bấm nút Lưu thành công.
  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    _customAmenity.dispose();
    super.dispose();
  }

  // Chủ trọ - Chọn ảnh - Luồng đi: Dùng picker đa nền tảng, kiểm tra
  // chữ ký PNG/JPEG và dung lượng rồi giữ byte để xem trước/xóa khỏi form.
  Future<void> _pickImages({bool proof = false}) async {
    setState(() => _picking = true);
    final target = _roomTab ? _roomImages : _houseImages;
    try {
      final picker = ref.read(hostImagePickerProvider);
      final List<XFile> files;
      if (proof) {
        final file = await picker.pickImage(source: ImageSource.gallery);
        files = file == null ? [] : [file];
      } else {
        files = await picker.pickMultiImage();
      }
      final max = _roomTab ? 8 : 5;
      if (!proof && target.length + files.length > max) {
        throw StateError('Chỉ chọn tối đa $max ảnh.');
      }
      final selected = <HostUpload>[];
      for (final file in files) {
        final size = await file.length();
        if (size > (proof ? 15 : 5) * 1024 * 1024) {
          throw StateError('Tệp vượt quá ${proof ? 15 : 5} MB.');
        }
        final Uint8List bytes = await file.readAsBytes();
        final png =
            bytes.length >= 8 &&
            bytes[0] == 137 &&
            bytes[1] == 80 &&
            bytes[2] == 78 &&
            bytes[3] == 71 &&
            bytes[4] == 13 &&
            bytes[5] == 10 &&
            bytes[6] == 26 &&
            bytes[7] == 10;
        final jpg =
            bytes.length >= 3 &&
            bytes[0] == 255 &&
            bytes[1] == 216 &&
            bytes[2] == 255;
        if (!png && !jpg) throw StateError('Chỉ hỗ trợ ảnh JPG hoặc PNG.');
        selected.add(HostUpload(bytes, png ? 'image/png' : 'image/jpeg'));
      }
      if (!mounted) return;
      setState(() {
        if (proof && selected.isNotEmpty) {
          _proof = selected.first;
        } else {
          target.addAll(selected);
        }
      });
    } catch (error) {
      if (mounted) _message(hostErrorMessage(error));
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  // Chủ trọ - Lưu form - Luồng đi: Validate và upload ảnh; chỉ báo
  // thành công sau khi Firebase ghi xong, lỗi giữ nguyên dữ liệu để thử lại.
  Future<void> _save(List<HostProperty> properties) async {
    final uid = ref.read(hostSessionProvider).value;
    if (uid == null) {
      _message('Vui lòng đăng nhập bằng tài khoản Chủ trọ.');
      return;
    }
    if (!(_roomTab ? _roomForm : _houseForm).currentState!.validate()) return;
    final images = _roomTab ? _roomImages : _houseImages;
    if (images.isEmpty) {
      _message('Vui lòng chọn ít nhất 1 ảnh thực tế.');
      return;
    }
    if (!_roomTab && (_fields['ward']!.text.trim().isEmpty || _types.isEmpty)) {
      _message('Chọn phường/xã và ít nhất một loại hình.');
      return;
    }
    final property = properties
        .where((p) => p.id == _selectedPropertyId)
        .firstOrNull;
    if (_roomTab && property == null) {
      _message('Chọn cơ sở trước khi tạo phòng.');
      return;
    }
    if (_roomTab && int.parse(_fields['floor']!.text) > property!.floors) {
      _message('Tầng phòng vượt quá số tầng của cơ sở.');
      return;
    }
    setState(() => _saving = true);
    try {
      final repository = ref.read(hostRepositoryProvider);
      if (_roomTab) {
        final user = ref.read(userProfileProvider).value;
        final parent = property!;
        await repository.createRoom(
          RoomModel(
            id: '',
            propertyId: parent.id,
            roomCode: _fields['code']!.text.trim().toUpperCase(),
            title: 'Phòng ${_fields['code']!.text.trim()} • ${parent.name}',
            description: _fields['notes']!.text.trim(),
            price: double.parse(_fields['price']!.text),
            deposit: double.parse(_fields['deposit']!.text),
            address: parent.fullAddress,
            district: parent.ward,
            city: parent.city,
            area: _area,
            roomType: _roomType,
            amenities: _amenities.toList(),
            images: const [],
            hostId: uid,
            hostName: user?.displayName ?? 'Chủ trọ',
            hostPhone: user?.phoneNumber ?? '',
            hostAvatar: user?.avatarUrl ?? '',
            capacity: _capacity,
            floor: int.parse(_fields['floor']!.text),
            rating: 0,
            createdAt: DateTime.now(),
          ),
          List.of(images),
          _operationId,
        );
        if (!mounted) return;
        Navigator.of(context).pop(true);
        return;
      }
      if (_draftOwner != uid) {
        _draftPropertyId = null;
        _draftOwner = uid;
      }
      _draftPropertyId ??= repository.newPropertyId();
      final house = HostProperty(
        id: _draftPropertyId!,
        hostId: uid,
        name: _fields['name']!.text.trim(),
        address: _fields['address']!.text.trim(),
        city: _city,
        ward: _fields['ward']!.text.trim(),
        plannedRooms: int.parse(_fields['planned']!.text),
        floors: int.parse(_fields['floors']!.text),
        types: _types.toList(),
        minRent: _rent.start,
        maxRent: _rent.end,
      );
      await repository.createProperty(house, List.of(images), _proof);
      if (!mounted) return;
      setState(() {
        _justCreated = house;
        _selectedPropertyId = house.id;
        _roomTab = true;
        _draftPropertyId = null;
        _houseImages.clear();
        _proof = null;
        for (final field in ['name', 'address', 'ward', 'planned']) {
          _fields[field]!.clear();
        }
      });
      _message('Đã lưu cơ sở. Bạn có thể tạo phòng cho cơ sở này.');
    } catch (error) {
      if (mounted) _message(hostErrorMessage(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // Chủ trọ - Phản hồi thao tác - Luồng đi: Thông báo ngay tại form,
  // thay thông báo trước đó để không xếp hàng nhiều lỗi liên tiếp.
  void _message(String text) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  // Chủ trọ - Hiển thị form tạo - Luồng đi: Chuyển tab giữ dữ liệu
  // chưa lưu; trong lúc lưu khóa nút và quay lại để tránh gửi hai lần.
  @override
  Widget build(BuildContext context) {
    final session = ref.watch(hostSessionProvider);
    final asyncProperties = ref.watch(hostPropertiesProvider);
    final properties = (asyncProperties.value ?? <HostProperty>[])
        .where((property) => property.hostId == session.value)
        .toList();
    if (_justCreated != null &&
        _justCreated!.hostId == session.value &&
        !properties.any((p) => p.id == _justCreated!.id)) {
      properties.add(_justCreated!);
    }
    final locked = _saving || _picking;
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(_roomTab ? 'Tạo phòng' : 'Tạo cơ sở (Nhà)'),
          leading: IconButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8EEFA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    for (final room in [false, true])
                      Expanded(
                        child: TextButton(
                          style: TextButton.styleFrom(
                            backgroundColor: _roomTab == room
                                ? Colors.white
                                : Colors.transparent,
                            foregroundColor: _roomTab == room
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                          onPressed: locked
                              ? null
                              : () => setState(() => _roomTab = room),
                          child: Text(room ? 'Tạo phòng' : 'Tạo cơ sở (Nhà)'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: AbsorbPointer(
                absorbing: locked,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    if (session.isLoading) const LinearProgressIndicator(),
                    if (session.hasError)
                      _notice(hostErrorMessage(session.error!)),
                    if (!session.isLoading && session.value == null)
                      _notice(
                        'Bạn đang xem giao diện. Đăng nhập tài khoản Chủ trọ để lưu nhà/phòng lên Firebase.',
                      ),
                    if (_roomTab && asyncProperties.isLoading)
                      const LinearProgressIndicator(),
                    if (_roomTab && asyncProperties.hasError)
                      _notice(hostErrorMessage(asyncProperties.error!)),
                    if (_roomTab)
                      _buildRoomForm(properties)
                    else
                      _buildHouseForm(),
                  ],
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                TextButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Hủy'),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton.icon(
                    onPressed:
                        locked ||
                            session.value == null ||
                            (_roomTab &&
                                (properties.isEmpty ||
                                    asyncProperties.hasError))
                        ? null
                        : () => _save(properties),
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: Text(
                      _saving
                          ? 'Đang lưu...'
                          : _roomTab
                          ? 'Lưu phòng'
                          : 'Lưu & tạo phòng',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Chủ trọ - Form cơ sở - Luồng đi: Chọn ảnh, địa chỉ, loại hình,
  // quy mô và khoảng giá; giấy tờ tùy chọn lưu riêng cho chủ tài khoản.
  Widget _buildHouseForm() => Form(
    key: _houseForm,
    child: Column(
      children: [
        _photoCard(_houseImages, 5, 'Hình ảnh cơ sở / Mặt tiền'),
        _section('Định danh tòa nhà', Icons.apartment, [
          _field(
            'name',
            'Tên cơ sở / Tòa nhà *',
            hint: 'Ví dụ: Nhà trọ Đặng Văn Bi',
            maxLength: 100,
          ),
          _field(
            'address',
            'Số nhà, đường *',
            hint: 'Nhập địa chỉ cụ thể',
            maxLength: 200,
          ),
          DropdownButtonFormField<String>(
            initialValue: _city,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Tỉnh / Thành phố *'),
            items: VietnamLocations.provinces
                .map((city) => DropdownMenuItem(value: city, child: Text(city)))
                .toList(),
            onChanged: (value) => setState(() {
              _city = value!;
              _fields['ward']!.clear();
            }),
          ),
          const SizedBox(height: 14),
          _field(
            'ward',
            'Phường / Xã *',
            hint: 'Nhập phường/xã theo địa chỉ cơ sở',
            maxLength: 100,
          ),
        ]),
        _section('Loại hình & Quy mô', Icons.tune, [
          for (final type in _typeOptions)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(type, style: const TextStyle(fontSize: 13)),
              value: _types.contains(type),
              onChanged: (value) => setState(() {
                value! ? _types.add(type) : _types.remove(type);
              }),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _field(
                  'planned',
                  'Số phòng dự kiến *',
                  number: true,
                  max: 1000,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _field('floors', 'Số tầng *', number: true, max: 100),
              ),
            ],
          ),
          const Text(
            'Số phòng thực tế sẽ tăng khi bạn tạo từng phòng.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          const Text(
            'Khung giá thuê / tháng',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            '${_money(_rent.start)} đ – ${_money(_rent.end)} đ',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          RangeSlider(
            values: _rent,
            min: 0,
            max: 20000000,
            divisions: 200,
            labels: RangeLabels(_money(_rent.start), _money(_rent.end)),
            onChanged: (value) => setState(() => _rent = value),
          ),
        ]),
        _section('Giấy tờ pháp lý (tùy chọn)', Icons.security, [
          const Text(
            'Ảnh sổ hồng hoặc giấy phép kinh doanh. JPG/PNG, tối đa 15 MB.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          if (_proof != null) ...[
            const SizedBox(height: 12),
            Image.memory(_proof!.bytes, height: 100),
            TextButton(
              onPressed: () => setState(() => _proof = null),
              child: const Text('Xóa giấy tờ'),
            ),
          ],
          OutlinedButton.icon(
            onPressed: () => _pickImages(proof: true),
            icon: const Icon(Icons.upload_file),
            label: Text(
              _proof == null ? 'Chọn ảnh giấy tờ' : 'Đổi ảnh giấy tờ',
            ),
          ),
          const Text(
            'Chỉ chủ tài khoản được truy cập. Tải lên không đồng nghĩa đã được xác minh.',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ]),
      ],
    ),
  );

  // Chủ trọ - Form phòng - Luồng đi: Chọn nhà đã lưu, nhập mã phòng,
  // giá và diện tích, chọn tiện ích rồi lưu phòng trống thuộc cơ sở đó.
  Widget _buildRoomForm(List<HostProperty> properties) {
    final selected = properties
        .where((p) => p.id == _selectedPropertyId)
        .firstOrNull;
    return Form(
      key: _roomForm,
      child: Column(
        children: [
          _section('Thuộc cơ sở / Tòa nhà', Icons.home_work_outlined, [
            if (properties.isEmpty) ...[
              const Text('Chưa có cơ sở. Hãy tạo nhà trước khi tạo phòng.'),
              TextButton(
                onPressed: () => setState(() => _roomTab = false),
                child: const Text('Tạo cơ sở trước'),
              ),
            ] else ...[
              DropdownButtonFormField<String>(
                key: ValueKey('property_${selected?.id}_${properties.length}'),
                initialValue: selected?.id,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Chọn cơ sở *'),
                items: properties
                    .map(
                      (p) => DropdownMenuItem(
                        value: p.id,
                        child: Text(p.name, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => _selectedPropertyId = value),
                validator: (value) =>
                    value == null ? 'Vui lòng chọn cơ sở' : null,
              ),
              if (selected != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    selected.fullAddress,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
            ],
          ]),
          _photoCard(_roomImages, 8, 'Hình ảnh thực tế'),
          _section('Thông tin phòng mới', Icons.meeting_room_outlined, [
            _field(
              'code',
              'Số / Mã phòng *',
              hint: 'Ví dụ: A101',
              maxLength: 30,
            ),
            DropdownButtonFormField<String>(
              initialValue: _roomType,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Loại phòng'),
              items:
                  [
                        'Phòng trọ',
                        'Căn hộ mini',
                        'Chung cư mini',
                        'Nhà nguyên căn',
                      ]
                      .map(
                        (type) =>
                            DropdownMenuItem(value: type, child: Text(type)),
                      )
                      .toList(),
              onChanged: (value) => setState(() => _roomType = value!),
            ),
            const SizedBox(height: 14),
            Text(
              'Diện tích: ${_area.round()} m²',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Slider(
              value: _area,
              min: 10,
              max: 100,
              divisions: 90,
              label: '${_area.round()} m²',
              onChanged: (value) => setState(() => _area = value),
            ),
            _field(
              'price',
              'Giá thuê hàng tháng (đ) *',
              number: true,
              max: 1000000000,
              hint: 'Ví dụ: 2500000',
            ),
            _field(
              'deposit',
              'Tiền cọc (đ) *',
              number: true,
              allowZero: true,
              max: 1000000000,
            ),
            _field('floor', 'Tầng *', number: true, max: 100),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Số người ở tối đa',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
                IconButton(
                  onPressed: _capacity > 1
                      ? () => setState(() => _capacity--)
                      : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text(
                  '$_capacity',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: _capacity < 20
                      ? () => setState(() => _capacity++)
                      : null,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
          ]),
          _amenitySection(),
          _section('Ghi chú & Quy định riêng', Icons.notes, [
            TextFormField(
              controller: _fields['notes'],
              maxLines: 4,
              maxLength: 2000,
              decoration: const InputDecoration(
                hintText: 'Giờ giấc, nội quy, thông tin thêm...',
              ),
            ),
          ]),
        ],
      ),
    );
  }

  // Chủ trọ - Chọn tiện ích phòng - Luồng đi: Tích chọn từng dòng,
  // thêm tiện ích riêng và thu gọn; các lựa chọn được lưu cùng phòng.
  Widget _amenitySection() => HostRoomSection(
    title: 'Tiện ích & Trang bị',
    icon: Icons.tune,
    trailing: Text(
      '${_amenities.length} chọn',
      style: const TextStyle(fontSize: 11, color: Color(0xFF00865B)),
    ),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _customAmenity,
                maxLength: 60,
                decoration: const InputDecoration(
                  hintText: 'Thêm tiện ích...',
                  isDense: true,
                  counterText: '',
                ),
              ),
            ),
            const SizedBox(width: 6),
            TextButton(
              onPressed: () {
                final value = _customAmenity.text.trim();
                if (value.isNotEmpty && value.length <= 60) {
                  setState(() => _amenities.add(value));
                  _customAmenity.clear();
                }
              },
              child: const Text('Thêm'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final value in {
          ..._amenities,
          if (_amenitiesExpanded) ..._amenityOptions,
        })
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: _amenities.contains(value)
                  ? const Color(0xFFE8FCF4)
                  : Colors.white,
              border: Border.all(
                color: _amenities.contains(value)
                    ? const Color(0xFF8BD4B8)
                    : const Color(0xFFE3E6EF),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Material(
              color: Colors.transparent,
              child: CheckboxListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(value, style: const TextStyle(fontSize: 12)),
                value: _amenities.contains(value),
                onChanged: (checked) => setState(() {
                  if (checked == true) {
                    _amenities.add(value);
                  } else {
                    _amenities.remove(value);
                  }
                }),
              ),
            ),
          ),
        TextButton(
          onPressed: () =>
              setState(() => _amenitiesExpanded = !_amenitiesExpanded),
          child: Text(_amenitiesExpanded ? 'Thu gọn ↑' : 'Xem thêm ↓'),
        ),
      ],
    ),
  );
  // Chủ trọ - Bộ ảnh của form - Luồng đi: Thêm/xóa ảnh trước khi lưu;
  // ảnh đầu tiên là ảnh bìa và bộ ảnh nhà tách biệt với bộ ảnh phòng.
  Widget _photoCard(List<HostUpload> images, int max, String title) => _section(
    title,
    Icons.photo_library_outlined,
    [
      Text(
        '${images.length}/$max ảnh • JPG/PNG, tối đa 5 MB mỗi ảnh',
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var i = 0; i < images.length; i++)
            SizedBox(
              width: 94,
              height: 100,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(images[i].bytes, fit: BoxFit.cover),
                  ),
                  if (i == 0)
                    const Positioned(
                      bottom: 3,
                      left: 3,
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: Colors.black54),
                        child: Padding(
                          padding: EdgeInsets.all(3),
                          child: Text(
                            'Ảnh bìa',
                            style: TextStyle(fontSize: 10, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: IconButton(
                      tooltip: 'Xóa ảnh ${i + 1}',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black54,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(28, 28),
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: () => setState(() => images.removeAt(i)),
                      icon: const Icon(Icons.close, size: 16),
                    ),
                  ),
                ],
              ),
            ),
          if (images.length < max)
            SizedBox(
              width: 94,
              height: 100,
              child: OutlinedButton(
                onPressed: () => _pickImages(),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo_outlined),
                    SizedBox(height: 8),
                    Text(
                      'Thêm ảnh',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ],
  );

  // Chủ trọ - Nhóm thông tin và trường nhập - Luồng đi: Dùng chung
  // hai form, kiểm tra bắt buộc và số nguyên dương trước khi gửi Firebase.
  Widget _section(String title, IconData icon, List<Widget> children) =>
      Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Material(
          color: Colors.transparent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(icon, color: AppColors.primary, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...children,
            ],
          ),
        ),
      );
  Widget _notice(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      text,
      style: const TextStyle(fontSize: 12, color: AppColors.warning),
    ),
  );
  Widget _field(
    String name,
    String label, {
    String? hint,
    bool number = false,
    bool allowZero = false,
    int max = 1000000000,
    int maxLength = 100,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      key: ValueKey('host_field_$name'),
      controller: _fields[name],
      keyboardType: number ? TextInputType.number : TextInputType.text,
      inputFormatters: number ? [FilteringTextInputFormatter.digitsOnly] : null,
      maxLength: number ? null : maxLength,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        counterText: '',
      ),
      validator: (text) {
        if (text == null || text.trim().isEmpty) {
          return 'Vui lòng nhập thông tin';
        }
        if (number) {
          final value = int.tryParse(text);
          if (value == null || value < (allowZero ? 0 : 1) || value > max) {
            return 'Nhập từ ${allowZero ? 0 : 1} đến $max';
          }
        }
        return null;
      },
    ),
  );
}
