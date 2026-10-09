import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../data/models/room_model.dart';

// Chủ trọ - Dữ liệu cơ sở - Luồng đi: Đọc properties theo tài khoản,
// quy mô dự kiến tách biệt với các phòng thực đã tạo trong rooms.
class HostProperty {
  const HostProperty({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.ward,
    required this.hostId,
    required this.plannedRooms,
    this.floors = 1,
    this.types = const [],
    this.minRent = 0,
    this.maxRent = 0,
    this.images = const [],
    this.createdAt,
  });
  final String id, name, address, city, ward, hostId;
  final int plannedRooms, floors;
  final double minRent, maxRent;
  final List<String> types, images;
  final DateTime? createdAt;
  String get fullAddress =>
      [address, ward, city].where((v) => v.isNotEmpty).join(', ');

  // Chủ trọ - Đọc cơ sở Firestore - Luồng đi: Chuyển tài liệu properties
  // thành dữ liệu giao diện; trường chưa có dùng giá trị mặc định.
  factory HostProperty.fromMap(String id, Map<String, dynamic> data) =>
      HostProperty(
        id: id,
        name: data['name'] as String? ?? '',
        address: data['address'] as String? ?? '',
        city: data['city'] as String? ?? '',
        ward: data['ward'] as String? ?? '',
        hostId: data['hostId'] as String? ?? '',
        plannedRooms: (data['plannedRooms'] as num?)?.toInt() ?? 0,
        floors: (data['floors'] as num?)?.toInt() ?? 1,
        minRent: (data['minRent'] as num?)?.toDouble() ?? 0,
        maxRent: (data['maxRent'] as num?)?.toDouble() ?? 0,
        types: List<String>.from(data['types'] as List? ?? []),
        images: List<String>.from(data['images'] as List? ?? []),
        createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      );

  // Chủ trọ - Ghi cơ sở - Luồng đi: Lưu thông tin nhà và thời gian máy
  // chủ; ảnh lưu URL Storage, không nhúng ảnh vào tài liệu Firestore.
  Map<String, dynamic> toMap() => {
    'name': name,
    'address': address,
    'city': city,
    'ward': ward,
    'hostId': hostId,
    'plannedRooms': plannedRooms,
    'floors': floors,
    'types': types,
    'minRent': minRent,
    'maxRent': maxRent,
    'images': images,
    'createdAt': FieldValue.serverTimestamp(),
  };
}

// Chủ trọ - Tổng hợp cơ sở - Luồng đi: Ghép properties với rooms theo
// propertyId; chỉ trạng thái occupied tính đang thuê, không tính đặt cọc.
class PropertySummary {
  PropertySummary(this.property, List<RoomModel> allRooms)
    : rooms = allRooms.where((room) => room.propertyId == property.id).toList();
  final HostProperty property;
  final List<RoomModel> rooms;
  int get rented => rooms.where((r) => r.status == 'occupied').length;
  int get vacant => rooms.where((r) => r.status == 'available').length;
  int get other => rooms.length - rented - vacant;
  double get expectedRevenue => rooms
      .where((r) => r.status == 'occupied')
      .fold(0, (total, r) => total + r.price);
  int get occupancy =>
      rooms.isEmpty ? 0 : (rented * 100 / rooms.length).round();
}
