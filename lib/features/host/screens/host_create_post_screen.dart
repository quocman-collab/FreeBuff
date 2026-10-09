import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/room_model.dart';
import '../../auth/providers/user_provider.dart';
import '../data/host_property.dart';
import '../providers/host_dashboard_provider.dart';
import '../providers/host_management_provider.dart';
import 'host_create_screen.dart';

/// Màn hình Tạo bài đăng role chủ trọ
/// Đáp ứng thiết kế PNG, schema SDS, validate giá chỉ nhận số,
/// tiện ích đọc từ Firestore, tiện ích tùy chọn local-only trước khi submit,
/// liên kết TienIch_Phong và rollback handling chống dữ liệu mồ côi.
class HostCreatePostScreen extends ConsumerStatefulWidget {
  const HostCreatePostScreen({super.key});

  @override
  ConsumerState<HostCreatePostScreen> createState() =>
      _HostCreatePostScreenState();
}

class _HostCreatePostScreenState extends ConsumerState<HostCreatePostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _price = TextEditingController();
  final _deposit = TextEditingController(text: '0');
  final _areaController = TextEditingController(text: '25');
  final _capacityController = TextEditingController(text: '2');
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _description = TextEditingController();
  final _customAmenity = TextEditingController();

  final _images = <HostUpload>[];
  final _selectedAmenities = <String>{};
  final _customAmenities = <String>[];

  HostProperty? _property;
  String _roomType = 'Phòng trọ';
  int _depositPercent = 20;
  bool _saving = false;
  bool _picking = false;
  bool _amenitiesExpanded = false;

  @override
  void dispose() {
    for (final field in [
      _title,
      _price,
      _deposit,
      _areaController,
      _capacityController,
      _address,
      _phone,
      _description,
      _customAmenity,
    ]) {
      field.dispose();
    }
    super.dispose();
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _title.clear();
    _price.clear();
    _deposit.text = '0';
    _areaController.text = '25';
    _capacityController.text = '2';
    _address.clear();
    _phone.clear();
    _description.clear();
    _customAmenity.clear();
    setState(() {
      _images.clear();
      _selectedAmenities.clear();
      _customAmenities.clear();
      _amenitiesExpanded = false;
      _roomType = 'Phòng trọ';
      _depositPercent = 20;
    });
  }

  Future<void> _pickImages() async {
    if (_images.length >= 10) {
      _message('Bài đăng chỉ được tối đa 10 ảnh.');
      return;
    }
    setState(() => _picking = true);
    try {
      final files = await ref
          .read(hostImagePickerProvider)
          .pickMultiImage(imageQuality: 88);
      final selected = <HostUpload>[];
      for (final file in files) {
        if (_images.length + selected.length >= 10) {
          break;
        }
        final size = await file.length();
        if (size > 5 * 1024 * 1024) {
          throw StateError('Mỗi ảnh không được vượt quá 5 MB.');
        }
        final bytes = await file.readAsBytes();
        final contentType = _imageContentType(bytes);
        if (contentType == null) {
          throw StateError('Chỉ hỗ trợ ảnh JPG hoặc PNG.');
        }
        selected.add(HostUpload(bytes, contentType));
      }
      if (mounted) setState(() => _images.addAll(selected));
    } catch (error) {
      if (mounted) _message(hostErrorMessage(error));
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  String? _imageContentType(Uint8List bytes) {
    final isPng =
        bytes.length >= 8 &&
        bytes[0] == 137 &&
        bytes[1] == 80 &&
        bytes[2] == 78 &&
        bytes[3] == 71 &&
        bytes[4] == 13 &&
        bytes[5] == 10 &&
        bytes[6] == 26 &&
        bytes[7] == 10;
    final isJpg =
        bytes.length >= 3 &&
        bytes[0] == 255 &&
        bytes[1] == 216 &&
        bytes[2] == 255;
    if (isPng) return 'image/png';
    if (isJpg) return 'image/jpeg';
    return null;
  }

  void _addCustomAmenity(List<Map<String, String>> catalogItems) {
    final raw = _customAmenity.text;
    final normalized = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) {
      _message('Vui lòng nhập tên tiện ích.');
      return;
    }

    // Chống trùng với danh mục tiện ích từ Firestore
    final catalogMatch = catalogItems
        .where(
          (item) =>
              item['name']!.trim().toLowerCase() == normalized.toLowerCase(),
        )
        .firstOrNull;

    if (catalogMatch != null) {
      setState(() {
        _selectedAmenities.add(catalogMatch['name']!);
        _customAmenity.clear();
        _amenitiesExpanded = true;
      });
      _message(
        'Tiện ích "${catalogMatch['name']}" đã có trong danh mục (đã tự động chọn).',
      );
      return;
    }

    // Chống trùng với tiện ích tùy chọn local
    final customMatch = _customAmenities
        .where((item) => item.trim().toLowerCase() == normalized.toLowerCase())
        .firstOrNull;

    if (customMatch != null) {
      setState(() {
        _selectedAmenities.add(customMatch);
        _customAmenity.clear();
        _amenitiesExpanded = true;
      });
      _message('Tiện ích tùy chọn "$customMatch" đã tồn tại.');
      return;
    }

    // Thêm vào list local dưới dạng checkbox đã chọn (chưa ghi Firestore ngay)
    setState(() {
      _customAmenities.add(normalized);
      _selectedAmenities.add(normalized);
      _customAmenity.clear();
      _amenitiesExpanded = true;
    });
  }

  void _toggleAmenity(String name) {
    setState(() {
      if (_selectedAmenities.contains(name)) {
        _selectedAmenities.remove(name);
      } else {
        _selectedAmenities.add(name);
      }
    });
  }

  void _removeCustomAmenity(String name) {
    setState(() {
      _customAmenities.remove(name);
      _selectedAmenities.remove(name);
    });
  }

  Future<void> _save(String uid, UserProfile? profile) async {
    if (!_formKey.currentState!.validate()) return;

    if (_images.isEmpty) {
      _message('Vui lòng chọn ít nhất 1 ảnh.');
      return;
    }

    final parsedPrice = double.tryParse(_price.text.trim()) ?? 0;
    if (parsedPrice <= 0) {
      _message('Giá thuê phải lớn hơn 0.');
      return;
    }

    final properties = ref.read(hostPropertiesProvider).value ?? [];
    if (_property == null) {
      if (properties.isNotEmpty) {
        _property = properties.first;
      } else {
        // Tự động tạo cơ sở mặc định nếu tài khoản chưa có cơ sở
        final autoPropId = ref.read(hostRepositoryProvider).newPropertyId();
        final autoProp = HostProperty(
          id: autoPropId,
          name: _title.text.trim().isNotEmpty ? _title.text.trim() : 'Nhà trọ',
          address: _address.text.trim(),
          city: 'TP. Hồ Chí Minh',
          ward: 'Thủ Đức',
          hostId: uid,
          plannedRooms: 10,
          floors: 1,
        );
        try {
          await ref.read(hostRepositoryProvider).createProperty(autoProp, [
            _images.first,
          ], null);
          _property = autoProp;
        } catch (_) {
          _property = autoProp;
        }
      }
    }

    setState(() => _saving = true);
    try {
      final parsedArea =
          double.tryParse(_areaController.text.trim().replaceAll(',', '.')) ??
          25.0;
      final parsedCapacity =
          int.tryParse(_capacityController.text.trim()) ?? 2;
      final calculatedDeposit =
          (parsedPrice * _depositPercent / 100).roundToDouble();

      final room = RoomModel(
        id: '',
        propertyId: _property!.id,
        roomCode: 'P${DateTime.now().millisecondsSinceEpoch % 10000}',
        title: _title.text.trim(),
        description: _description.text.trim(),
        price: parsedPrice,
        deposit: calculatedDeposit,
        address: _address.text.trim(),
        district: _property!.ward.isNotEmpty ? _property!.ward : 'TP. Thủ Đức',
        city: _property!.city.isNotEmpty ? _property!.city : 'TP. Hồ Chí Minh',
        area: parsedArea,
        roomType: _roomType,
        amenities: _selectedAmenities.toList(),
        images: const [],
        hostId: uid,
        hostName: profile?.displayName ?? 'Chủ nhà',
        hostPhone: _phone.text.trim(),
        hostAvatar: profile?.avatarUrl ?? '',
        rating: 0.0,
        reviewCount: 0,
        isAvailable: true,
        capacity: parsedCapacity,
        floor: 1,
        createdAt: DateTime.now(),
        status: 'available',
      );

      final catalogItems = ref.read(hostAmenitiesProvider).value ?? [];
      final catalogMap = {
        for (final item in catalogItems)
          item['name']!.trim().toLowerCase(): item['id']!,
      };

      final opId = 'post_${DateTime.now().millisecondsSinceEpoch}';

      // Lưu phòng, tiện ích tùy chọn, bảng liên kết TienIch_Phong và bài đăng SDS
      await ref
          .read(hostRepositoryProvider)
          .createPostWithAmenities(
            room: room,
            images: List.of(_images),
            operationId: opId,
            selectedAmenities: _selectedAmenities,
            customAmenities: _customAmenities,
            catalogAmenitiesMap: catalogMap,
            chuNhaId: uid,
            diaDiemId: _property!.ward.isNotEmpty
                ? _property!.ward
                : 'TP. Thủ Đức',
            loaiThueId: 'thang',
            trangThaiId: 'dangHienThi',
            tieuDe: _title.text.trim(),
            moTa: _description.text.trim(),
            giaThue: parsedPrice,
            soDienThoaiLienHe: _phone.text.trim(),
            authorName: profile?.displayName ?? 'Chủ nhà',
            authorAvatar: profile?.avatarUrl ?? '',
          );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) _message(hostErrorMessage(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatCurrency(String text) {
    if (text.isEmpty) return 'Chưa nhập';
    final numVal = int.tryParse(text);
    if (numVal == null) return text;
    return NumberFormat.decimalPattern('vi').format(numVal);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(hostSessionProvider).value;
    final profile = ref.watch(userProfileProvider).value;
    final amenities = ref.watch(hostAmenitiesProvider);
    final properties = ref.watch(hostPropertiesProvider).value ?? [];
    final uid = session;

    if (_property == null && properties.isNotEmpty) {
      _property = properties.first;
      if (_address.text.isEmpty && _property!.fullAddress.isNotEmpty) {
        _address.text = _property!.fullAddress;
      }
    }

    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: Padding(
            padding: const EdgeInsets.all(8.0),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: _saving ? null : () => Navigator.pop(context),
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new,
                  size: 16,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),
          ),
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Tạo bài đăng',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              Text(
                'Dành cho chủ nhà & đối tác uy tín',
                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
            ],
          ),
          actions: [
            TextButton(
              key: const ValueKey('reset_button'),
              onPressed: _saving ? null : _resetForm,
              child: const Text(
                'Đặt lại',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E60F2),
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Align(
            alignment: Alignment.bottomCenter,
            heightFactor: 1.0,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  key: const ValueKey('submit_post_button'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E60F2),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _saving || _picking || uid == null
                      ? null
                      : () => _save(uid, profile),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'ĐĂNG BÀI NGAY',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward_rounded, size: 20),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _photoSection(),
                    const SizedBox(height: 16),
                    _basicInfoTitle(),
                    const SizedBox(height: 10),
                    _roomTypeSelector(),
                    const SizedBox(height: 12),
                    _textField(
                      _title,
                      'Mô tả phòng *',
                      'Phòng trọ studio có gác đúc cao ráo, full nội thất, giờ tự do',
                      key: const ValueKey('title_input'),
                      maxLength: 240,
                    ),
                    _priceInput(),
                    _depositPercentSelector(),
                    Row(
                      children: [
                        Expanded(
                          child: _textField(
                            _areaController,
                            'Diện tích (m²)',
                            '25',
                            key: const ValueKey('area_input'),
                            keyboard: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            suffixText: 'm²',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _textField(
                            _capacityController,
                            'Sức chứa (người)',
                            '2',
                            key: const ValueKey('capacity_input'),
                            keyboard: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            suffixText: 'người',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    amenities.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (_, _) => const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text('Không tải được danh mục tiện ích.'),
                      ),
                      data: (items) => _amenitySection(items),
                    ),
                    const SizedBox(height: 16),
                    _contactTitle(),
                    const SizedBox(height: 10),
                    _contactField(
                      _address,
                      'Địa chỉ *',
                      Icons.location_on_outlined,
                      '18 Đường số 6, Tăng Nhơn Phú B, TP. Thủ Đức',
                      key: const ValueKey('address_input'),
                    ),
                    Row(
                      children: [
                        Expanded(child: _priceSummary()),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _contactField(
                            _phone,
                            'Số điện thoại *',
                            Icons.phone_outlined,
                            '0987 654 321',
                            key: const ValueKey('phone_input'),
                            keyboard: TextInputType.phone,
                          ),
                        ),
                      ],
                    ),
                    _textField(
                      _description,
                      'Mô tả chi tiết',
                      'Nội thất, giờ giấc, quy định, tiện ích xung quanh...',
                      key: const ValueKey('description_input'),
                      maxLines: 5,
                      maxLength: 2000,
                    ),
                    if (uid == null) _authWarning(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _basicInfoTitle() => const Row(
    children: [
      Icon(Icons.edit_note_rounded, color: Color(0xFF1E60F2), size: 22),
      SizedBox(width: 8),
      Text(
        'THÔNG TIN CƠ BẢN',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 14,
          color: Color(0xFF1E293B),
        ),
      ),
    ],
  );

  Widget _roomTypeSelector() => DropdownButtonFormField<String>(
    key: const ValueKey('room_type_select'),
    value: _roomType,
    isExpanded: true,
    decoration: InputDecoration(
      labelText: 'Loại phòng *',
      prefixIcon: const Icon(
        Icons.home_work_outlined,
        color: Color(0xFF1E60F2),
        size: 20,
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF1E60F2), width: 1.5),
      ),
    ),
    items: const [
      'Phòng trọ',
      'Căn hộ mini',
      'Chung cư mini',
      'Nhà nguyên căn',
      'Ký túc xá / Sleepbox',
    ].map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
    onChanged: (val) {
      if (val != null) setState(() => _roomType = val);
    },
  );

  Widget _depositPercentSelector() => ValueListenableBuilder<TextEditingValue>(
    valueListenable: _price,
    builder: (context, val, _) {
      final priceNum = double.tryParse(val.text.trim()) ?? 0;
      final depositAmount = (priceNum * _depositPercent / 100).round();
      final formattedDeposit = depositAmount > 0
          ? NumberFormat.decimalPattern('vi').format(depositAmount)
          : '0';

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.security_outlined,
                  color: Color(0xFF1E60F2),
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Tiền đặt cọc (theo % giá thuê)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      key: const ValueKey('deposit_percent_select'),
                      value: _depositPercent,
                      isDense: true,
                      icon: const Icon(
                        Icons.arrow_drop_down,
                        color: Color(0xFF1E60F2),
                      ),
                      items: [10, 20, 30, 40, 50]
                          .map(
                            (pct) => DropdownMenuItem(
                              value: pct,
                              child: Text(
                                '$pct%',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E60F2),
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (newPct) {
                        if (newPct != null) {
                          setState(() => _depositPercent = newPct);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Số tiền cọc tương ứng: $formattedDeposit đ',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      );
    },
  );

  Widget _priceInput() => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      key: const ValueKey('price_input'),
      controller: _price,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: Color(0xFF1E60F2),
      ),
      decoration: InputDecoration(
        labelText: 'Giá thuê / tháng *',
        suffixText: 'đ/tháng',
        suffixStyle: const TextStyle(
          color: Color(0xFF64748B),
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF93C5FD), width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF1E60F2), width: 2),
        ),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) return 'Nhập giá thuê';
        final parsed = double.tryParse(value.trim());
        if (parsed == null || parsed <= 0) return 'Giá thuê phải lớn hơn 0';
        return null;
      },
    ),
  );

  Widget _priceSummary() => ValueListenableBuilder<TextEditingValue>(
    valueListenable: _price,
    builder: (context, value, _) {
      final formatted = _formatCurrency(value.text.trim());
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          key: const ValueKey('price_readonly'),
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  formatted,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Text(
                'đ',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  Widget _contactTitle() => const Row(
    children: [
      Icon(Icons.location_on_outlined, color: Color(0xFF1E60F2), size: 22),
      SizedBox(width: 8),
      Expanded(
        child: Text(
          'VỊ TRÍ & LIÊN HỆ',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14,
            color: Color(0xFF1E293B),
          ),
        ),
      ),
      Icon(Icons.chevron_right_rounded, color: Color(0xFF1E60F2), size: 22),
    ],
  );

  Widget _contactField(
    TextEditingController controller,
    String label,
    IconData icon,
    String hint, {
    Key? key,
    TextInputType? keyboard,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      key: key,
      controller: controller,
      keyboardType: keyboard ?? TextInputType.streetAddress,
      inputFormatters: keyboard == TextInputType.phone
          ? [FilteringTextInputFormatter.digitsOnly]
          : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF1E60F2), size: 20),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF1E60F2), width: 1.5),
        ),
      ),
      validator: (value) =>
          label.contains('*') && (value == null || value.trim().isEmpty)
          ? 'Nhập $label'
          : null,
    ),
  );

  Widget _photoSection() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFD9E7FF), width: 1.2),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.image_outlined,
              color: Color(0xFF1E60F2),
              size: 20,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'HÌNH ẢNH & VIDEO PHÒNG',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),
            Text(
              _images.isEmpty ? '0/10 ảnh' : 'Đã chọn ${_images.length}/10',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 94,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _addImageButton(),
                ..._images.asMap().entries.map(
                  (entry) => _imageTile(entry.key, entry.value),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Row(
          children: [
            Icon(Icons.info_rounded, size: 16, color: Color(0xFF1E60F2)),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'Ảnh chụp thực tế góc rộng sẽ tăng 65% tỷ lệ liên hệ.',
                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _addImageButton() => InkWell(
    onTap: _picking ? null : _pickImages,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      width: 92,
      height: 92,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF8DB8FF), width: 1.5),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_photo_alternate_outlined,
            color: Color(0xFF1E60F2),
            size: 26,
          ),
          SizedBox(height: 4),
          Text(
            'Thêm ảnh',
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFF1E60F2),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _imageTile(int index, HostUpload upload) => Stack(
    children: [
      Container(
        width: 92,
        height: 92,
        margin: const EdgeInsets.only(right: 10),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Image.memory(upload.bytes, fit: BoxFit.cover),
      ),
      Positioned(
        top: 4,
        right: 14,
        child: InkWell(
          onTap: () => setState(() => _images.removeAt(index)),
          child: const CircleAvatar(
            radius: 11,
            backgroundColor: Color(0x99000000),
            child: Icon(Icons.close, size: 13, color: Colors.white),
          ),
        ),
      ),
      if (index == 0)
        Positioned(
          left: 5,
          bottom: 5,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF1E60F2),
              borderRadius: BorderRadius.circular(5),
            ),
            child: const Text(
              'Ảnh bìa',
              style: TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
    ],
  );

  Widget _textField(
    TextEditingController controller,
    String label,
    String hint, {
    Key? key,
    TextInputType? keyboard,
    List<TextInputFormatter>? inputFormatters,
    String? suffixText,
    int maxLines = 1,
    int? maxLength,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      key: key,
      controller: controller,
      keyboardType: keyboard,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      maxLength: maxLength,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixText: suffixText,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF1E60F2), width: 1.5),
        ),
      ),
      validator: (value) =>
          label.contains('*') && (value == null || value.trim().isEmpty)
          ? 'Nhập $label'
          : null,
    ),
  );

  Widget _amenitySection(List<Map<String, String>> catalogItems) {
    final catalogNames = catalogItems.map((item) => item['name']!).toList();
    final allItems = [
      ...catalogNames,
      ..._customAmenities.where((custom) => !catalogNames.contains(custom)),
    ];

    // Thu gọn chỉ giữ item đã chọn; Xem thêm hiện toàn bộ
    final visible = _amenitiesExpanded
        ? allItems
        : allItems.where((name) => _selectedAmenities.contains(name)).toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.format_list_bulleted_rounded,
                color: Color(0xFF0D5E42),
                size: 20,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Tiện ích & Yêu cầu',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
              Text(
                '${_selectedAmenities.length} đang chọn',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF0D5E42),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.add_circle_outline,
                  color: Color(0xFF94A3B8),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    key: const ValueKey('custom_amenity_input'),
                    controller: _customAmenity,
                    decoration: const InputDecoration(
                      hintText: 'Thêm tiện ích, yêu cầu riêng...',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF94A3B8),
                      ),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onSubmitted: (_) => _addCustomAmenity(catalogItems),
                  ),
                ),
                ElevatedButton(
                  key: const ValueKey('add_custom_amenity_button'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D5E42),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    elevation: 0,
                    minimumSize: const Size(60, 34),
                  ),
                  onPressed: () => _addCustomAmenity(catalogItems),
                  child: const Text(
                    'Thêm',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (visible.isEmpty && !_amenitiesExpanded)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: Text(
                  'Chưa chọn tiện ích nào. Nhấn "Xem thêm" để chọn.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ),
            ),
          ...visible.map((name) {
            final isCustom = _customAmenities.contains(name);
            final isSelected = _selectedAmenities.contains(name);
            return _amenityTile(name, isCustom, isSelected);
          }),
          const SizedBox(height: 6),
          InkWell(
            key: const ValueKey('amenities_toggle_button'),
            borderRadius: BorderRadius.circular(12),
            onTap: () =>
                setState(() => _amenitiesExpanded = !_amenitiesExpanded),
            child: Container(
              width: double.infinity,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                _amenitiesExpanded ? 'Thu gọn ^' : 'Xem thêm v',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF475569),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _amenityTile(String name, bool isCustom, bool isSelected) {
    final Color borderColor;
    final Color bgColor;
    final Color checkColor;

    if (isSelected) {
      if (isCustom) {
        borderColor = const Color(0xFF3B82F6);
        bgColor = const Color(0xFFEFF6FF);
        checkColor = const Color(0xFF2563EB);
      } else {
        borderColor = const Color(0xFF10B981);
        bgColor = const Color(0xFFECFDF5);
        checkColor = const Color(0xFF0D5E42);
      }
    } else {
      borderColor = const Color(0xFFE2E8F0);
      bgColor = const Color(0xFFF8FAFC);
      checkColor = const Color(0xFFCBD5E1);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: isSelected ? 1.4 : 1),
      ),
      child: InkWell(
        key: ValueKey('amenity_tile_$name'),
        borderRadius: BorderRadius.circular(14),
        onTap: () => _toggleAmenity(name),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: isSelected ? checkColor : Colors.white,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: isSelected ? checkColor : const Color(0xFFCBD5E1),
                    width: 1.5,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? (isCustom
                              ? const Color(0xFF1E3A8A)
                              : const Color(0xFF064E3B))
                        : const Color(0xFF1E293B),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              if (isCustom) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDBEAFE),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Tùy chọn',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1D4ED8),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  key: ValueKey('delete_custom_amenity_$name'),
                  icon: const Icon(
                    Icons.close,
                    size: 16,
                    color: Color(0xFF64748B),
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _removeCustomAmenity(name),
                ),
              ] else if (isSelected) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1FAE5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Đã chọn',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF047857),
                    ),
                  ),
                ),
              ] else ...[
                const Icon(Icons.add, size: 18, color: Color(0xFF94A3B8)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _authWarning() => const Padding(
    padding: EdgeInsets.only(bottom: 12),
    child: Text(
      'Cần đăng nhập tài khoản chủ nhà để đăng bài.',
      style: TextStyle(color: AppColors.danger),
    ),
  );
}
