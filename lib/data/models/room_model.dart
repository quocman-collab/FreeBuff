import 'package:cloud_firestore/cloud_firestore.dart';

/// Model Phòng trọ & Bài đăng chuẩn hóa theo Database homeShare
/// Bảng: Nhà trọ, Phòng, ẢnhPhong, Tiện ích, Bài đăng
class RoomModel {
  // Chủ trọ - Liên kết phòng với nhà - Luồng đi: Phòng tạo từ khu quản
  // lý lưu propertyId và roomCode; dữ liệu cũ vẫn đọc được khi thiếu trường.
  final String propertyId;
  final String roomCode;
  final String status;
  // Chủ trọ - Chi tiết quản lý phòng - Luồng đi: Đọc phí dịch vụ và
  // khách thuê/hợp đồng nếu có; thiếu dữ liệu không tạo thông tin minh họa.
  final double? electricityRate, waterRate, serviceFee;
  final String tenantName, tenantPhone, tenantAvatar, contractId;
  final DateTime? contractStart, contractEnd, updatedAt;
  final bool hasRentDebt;
  final String id; // phongId / baiDangId
  final String title; // tieuDe / tieuDePhong
  final String description; // moTa / noiDung
  final double price; // giaThueThang / giaThue / gia (VNĐ / tháng)
  final double deposit; // tienCoc
  final String address; // diaChi
  final String district; // quanHuyen / khuVuc (diaDiemId)
  final String city; // thanhPho
  final double area; // dienTichM2 / dienTich
  final double? minArea, maxArea;
  String get areaLabel =>
      minArea != null && maxArea != null && minArea != maxArea
      ? '$minArea–$maxArea m²'
      : '${minArea ?? area} m²';
  final String
  roomType; // loaiPhong (studio, gác lửng, phòng đơn, chung cư mini)
  final List<String>
  amenities; // tienIch (wifi, máy lạnh, tủ lạnh, máy giặt, gác lửng, ban công, bảo vệ)
  final List<String> images; // anhPhong / duongDan
  final String hostId; // chuNhaId / nguoiDangId
  final String hostName; // tenChuNha
  final String hostPhone; // soDienThoai / soDienThoaiLienHe
  final String hostAvatar; // anhDaiDien
  final double rating; // soSao / soSaoTrungBinh
  final int reviewCount; // soLuotDanhGia
  final bool isAvailable; // trangThai (conPhong, dangMo)
  final int capacity; // sucChua
  final int floor; // tang
  final DateTime createdAt; // ngayTao / ngayDang

  // Vietnamese DrawIO Alias Getters
  String get phongId => id;
  String get tieuDe => title;
  String get moTa => description;
  double get giaThueThang => price;
  double get gia => price;
  double get tienCoc => deposit;
  String get diaChi => address;
  String get quanHuyen => district;
  String get thanhPho => city;
  double get dienTichM2 => area;
  String get loaiPhong => roomType;
  List<String> get tienIch => amenities;
  List<String> get anhPhong => images;
  String get chuNhaId => hostId;
  String get tenChuNha => hostName;
  String get soDienThoai => hostPhone;
  String get anhDaiDien => hostAvatar;
  double get soSaoTrungBinh => rating;
  int get sucChua => capacity;
  int get tang => floor;
  DateTime get ngayTao => createdAt;

  RoomModel({
    required this.id,
    this.propertyId = '',
    this.roomCode = '',
    String? status,
    this.electricityRate,
    this.waterRate,
    this.serviceFee,
    this.tenantName = '',
    this.tenantPhone = '',
    this.tenantAvatar = '',
    this.contractId = '',
    this.contractStart,
    this.contractEnd,
    this.updatedAt,
    this.hasRentDebt = false,
    required this.title,
    required this.description,
    required this.price,
    required this.deposit,
    required this.address,
    required this.district,
    this.city = 'TP. Hồ Chí Minh',
    required this.area,
    this.minArea,
    this.maxArea,
    required this.roomType,
    required this.amenities,
    required this.images,
    required this.hostId,
    required this.hostName,
    required this.hostPhone,
    this.hostAvatar = '',
    this.rating = 5.0,
    this.reviewCount = 0,
    this.isAvailable = true,
    this.capacity = 2,
    this.floor = 1,
    required this.createdAt,
  }) : status = status ?? (isAvailable ? 'available' : 'unavailable');

  factory RoomModel.fromFirestore(DocumentSnapshot doc) {
    return RoomModel.fromMap(doc.data() as Map<String, dynamic>? ?? {}, doc.id);
  }

  factory RoomModel.fromMap(Map<String, dynamic> data, String id) {
    return RoomModel(
      id: id,
      minArea: (data['minArea'] as num?)?.toDouble(),
      maxArea: (data['maxArea'] as num?)?.toDouble(),
      electricityRate: (data['electricityRate'] as num?)?.toDouble(),
      waterRate: (data['waterRate'] as num?)?.toDouble(),
      serviceFee: (data['serviceFee'] as num?)?.toDouble(),
      tenantName: data['tenantName'] ?? '',
      tenantPhone: data['tenantPhone'] ?? '',
      tenantAvatar: data['tenantAvatar'] ?? '',
      contractId: data['contractId'] ?? '',
      contractStart: (data['contractStart'] as Timestamp?)?.toDate(),
      contractEnd: (data['contractEnd'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      hasRentDebt: data['hasRentDebt'] == true,
      propertyId: data['propertyId'] ?? '',
      roomCode: data['roomCode'] ?? '',
      status:
          data['status'] ??
          ((data['isAvailable'] ??
                  (data['trangThai'] == 'conPhong' ||
                      data['trangThai'] == 'dangMo' ||
                      data['trangThai'] == null))
              ? 'available'
              : 'unavailable'),
      title: data['title'] ?? data['tieuDe'] ?? '',
      description: data['description'] ?? data['noiDung'] ?? data['moTa'] ?? '',
      price:
          ((data['price'] ??
                      data['gia'] ??
                      data['giaThue'] ??
                      data['giaThueThang'])
                  as num?)
              ?.toDouble() ??
          0.0,
      deposit:
          ((data['deposit'] ?? data['tienCoc']) as num?)?.toDouble() ?? 0.0,
      address: data['address'] ?? data['diaChi'] ?? '',
      district: data['district'] ?? data['quanHuyen'] ?? data['khuVuc'] ?? '',
      city: data['city'] ?? data['thanhPho'] ?? 'TP. Hồ Chí Minh',
      area:
          ((data['area'] ?? data['dienTich'] ?? data['dienTichM2']) as num?)
              ?.toDouble() ??
          20.0,
      roomType: data['roomType'] ?? data['loaiPhong'] ?? 'Phòng trọ',
      amenities:
          ((data['amenities'] ?? data['tienIch']) as List<dynamic>?)
              ?.map((e) => e?.toString() ?? '')
              .where((e) => e.isNotEmpty)
              .toList() ??
          [],
      images:
          ((data['images'] ?? data['anhPhong']) as List<dynamic>?)
              ?.map((e) => e?.toString() ?? '')
              .where((e) => e.isNotEmpty)
              .toList() ??
          [],
      hostId: data['hostId'] ?? data['chuNhaId'] ?? data['nguoiDangId'] ?? '',
      hostName: data['hostName'] ?? data['tenChuNha'] ?? 'Chủ nhà',
      hostPhone:
          data['hostPhone'] ??
          data['soDienThoai'] ??
          data['soDienThoaiLienHe'] ??
          '',
      hostAvatar: data['hostAvatar'] ?? data['anhDaiDien'] ?? '',
      rating:
          ((data['rating'] ?? data['soSao'] ?? data['soSaoTrungBinh']) as num?)
              ?.toDouble() ??
          5.0,
      reviewCount:
          ((data['reviewCount'] ?? data['soLuotDanhGia']) as num?)?.toInt() ??
          0,
      isAvailable:
          data['isAvailable'] ??
          (data['trangThai'] == 'conPhong' ||
              data['trangThai'] == 'dangMo' ||
              data['trangThai'] == null),
      capacity: ((data['capacity'] ?? data['sucChua']) as num?)?.toInt() ?? 2,
      floor: ((data['floor'] ?? data['tang']) as num?)?.toInt() ?? 1,
      createdAt: (data['createdAt'] is Timestamp)
          ? (data['createdAt'] as Timestamp).toDate()
          : (data['ngayTao'] is Timestamp)
          ? (data['ngayTao'] as Timestamp).toDate()
          : (data['ngayDang'] is Timestamp)
          ? (data['ngayDang'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'propertyId': propertyId,
      'roomCode': roomCode,
      'status': status,
      if (electricityRate != null) 'electricityRate': electricityRate,
      if (waterRate != null) 'waterRate': waterRate,
      if (serviceFee != null) 'serviceFee': serviceFee,
      'tenantName': tenantName,
      'tenantPhone': tenantPhone,
      'tenantAvatar': tenantAvatar,
      'contractId': contractId,
      if (contractStart != null)
        'contractStart': Timestamp.fromDate(contractStart!),
      if (contractEnd != null) 'contractEnd': Timestamp.fromDate(contractEnd!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      'hasRentDebt': hasRentDebt,
      'title': title,
      'tieuDe': title,
      'description': description,
      'moTa': description,
      'noiDung': description,
      'price': price,
      'gia': price,
      'giaThue': price,
      'giaThueThang': price,
      'deposit': deposit,
      'tienCoc': deposit,
      'address': address,
      'diaChi': address,
      'district': district,
      'quanHuyen': district,
      'khuVuc': district,
      'city': city,
      'thanhPho': city,
      'area': area,
      if (minArea != null) 'minArea': minArea,
      if (maxArea != null) 'maxArea': maxArea,
      'dienTich': area,
      'dienTichM2': area,
      'roomType': roomType,
      'loaiPhong': roomType,
      'amenities': amenities,
      'tienIch': amenities,
      'images': images,
      'anhPhong': images,
      'hostId': hostId,
      'chuNhaId': hostId,
      'hostName': hostName,
      'tenChuNha': hostName,
      'hostPhone': hostPhone,
      'soDienThoai': hostPhone,
      'hostAvatar': hostAvatar,
      'anhDaiDien': hostAvatar,
      'rating': rating,
      'soSaoTrungBinh': rating,
      'reviewCount': reviewCount,
      'isAvailable': isAvailable,
      'capacity': capacity,
      'sucChua': capacity,
      'floor': floor,
      'tang': floor,
      'createdAt': Timestamp.fromDate(createdAt),
      'ngayTao': Timestamp.fromDate(createdAt),
    };
  }
}
